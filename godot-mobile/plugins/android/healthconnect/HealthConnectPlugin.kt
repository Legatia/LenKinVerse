package com.lenkinverse.healthconnect

import android.content.Context
import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.runBlocking
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Android Health Connect Plugin for Godot 4
 * Compatible with Android 14+ (Health Connect API)
 * Replaces deprecated Google Fit APIs
 */
class HealthConnectPlugin(godot: Godot) : GodotPlugin(godot) {

    private var healthConnectClient: HealthConnectClient? = null
    private var isAuthorized = false

    companion object {
        private const val TAG = "HealthConnectPlugin"

        // Permissions required for step count and distance
        val PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(DistanceRecord::class)
        )
    }

    override fun getPluginName(): String = "HealthConnect"

    override fun onMainCreate(activity: android.app.Activity): Boolean {
        super.onMainCreate(activity)

        // Check if Health Connect is available
        if (HealthConnectClient.sdkStatus(activity) == HealthConnectClient.SDK_AVAILABLE) {
            healthConnectClient = HealthConnectClient.getOrCreate(activity)
            return true
        } else {
            emitSignal("health_connect_unavailable", "Health Connect not installed")
            return false
        }
    }

    /**
     * Request permissions for Health Connect
     * Returns: Dictionary with "granted" bool
     */
    @UsedByGodot
    fun requestAuthorization(types: Array<String>): org.godotengine.godot.Dictionary {
        val result = org.godotengine.godot.Dictionary()

        if (healthConnectClient == null) {
            result["granted"] = false
            result["error"] = "Health Connect not available"
            return result
        }

        try {
            // Launch permission request activity
            val permissionRequest = HealthConnectClient.getOrCreate(activity!!).permissionController

            runBlocking {
                val granted = permissionRequest.getGrantedPermissions()
                isAuthorized = granted.containsAll(PERMISSIONS)

                if (!isAuthorized) {
                    // Need to request permissions via activity
                    // This requires user interaction - signal to Godot
                    result["granted"] = false
                    result["needs_activity"] = true
                    emitSignal("permission_request_needed")
                } else {
                    result["granted"] = true
                }
            }
        } catch (e: Exception) {
            result["granted"] = false
            result["error"] = e.message ?: "Unknown error"
        }

        return result
    }

    /**
     * Launch Health Connect permission screen
     */
    @UsedByGodot
    fun launchPermissionActivity() {
        if (healthConnectClient == null) return

        try {
            val intent = HealthConnectClient.getOrCreate(activity!!).permissionController
                .createRequestPermissionResultContract()
                .createIntent(activity!!, PERMISSIONS)

            activity!!.startActivity(intent)
        } catch (e: Exception) {
            emitSignal("permission_error", e.message ?: "Failed to launch permission screen")
        }
    }

    /**
     * Get step count between dates
     * @param params Dictionary with "start_date" and "end_date" (Godot datetime dicts)
     * @return Dictionary with "steps" int and "success" bool
     */
    @UsedByGodot
    fun getSteps(params: org.godotengine.godot.Dictionary): org.godotengine.godot.Dictionary {
        val result = org.godotengine.godot.Dictionary()
        result["success"] = false
        result["steps"] = 0

        if (!isAuthorized || healthConnectClient == null) {
            result["error"] = "Not authorized"
            return result
        }

        try {
            val startDate = parseGodotDate(params["start_date"])
            val endDate = parseGodotDate(params["end_date"])

            if (startDate == null || endDate == null) {
                result["error"] = "Invalid date format"
                return result
            }

            runBlocking {
                val request = ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startDate, endDate)
                )

                val response = healthConnectClient!!.readRecords(request)
                val totalSteps = response.records.sumOf { it.count }

                result["success"] = true
                result["steps"] = totalSteps
            }
        } catch (e: Exception) {
            result["error"] = e.message ?: "Failed to read steps"
        }

        return result
    }

    /**
     * Get distance walked/run between dates
     * @param params Dictionary with "start_date" and "end_date"
     * @return Dictionary with "distance" float (meters) and "success" bool
     */
    @UsedByGodot
    fun getDistance(params: org.godotengine.godot.Dictionary): org.godotengine.godot.Dictionary {
        val result = org.godotengine.godot.Dictionary()
        result["success"] = false
        result["distance"] = 0.0

        if (!isAuthorized || healthConnectClient == null) {
            result["error"] = "Not authorized"
            return result
        }

        try {
            val startDate = parseGodotDate(params["start_date"])
            val endDate = parseGodotDate(params["end_date"])

            if (startDate == null || endDate == null) {
                result["error"] = "Invalid date format"
                return result
            }

            runBlocking {
                val request = ReadRecordsRequest(
                    recordType = DistanceRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startDate, endDate)
                )

                val response = healthConnectClient!!.readRecords(request)
                val totalDistance = response.records.sumOf { it.distance.inMeters }

                result["success"] = true
                result["distance"] = totalDistance
            }
        } catch (e: Exception) {
            result["error"] = e.message ?: "Failed to read distance"
        }

        return result
    }

    // MARK: - Helper Methods

    /**
     * Parse Godot datetime dictionary to Instant
     */
    private fun parseGodotDate(dateObj: Any?): Instant? {
        if (dateObj !is org.godotengine.godot.Dictionary) return null

        val year = dateObj["year"] as? Int ?: return null
        val month = dateObj["month"] as? Int ?: return null
        val day = dateObj["day"] as? Int ?: return null
        val hour = dateObj["hour"] as? Int ?: 0
        val minute = dateObj["minute"] as? Int ?: 0
        val second = dateObj["second"] as? Int ?: 0

        val localDateTime = LocalDateTime.of(year, month, day, hour, minute, second)
        return localDateTime.atZone(ZoneId.systemDefault()).toInstant()
    }
}
