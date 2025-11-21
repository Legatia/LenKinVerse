# 🏃 Health API Setup Guide - LenKinVerse

**Last Updated:** November 2025
**iOS Support:** iOS 15+ (tested on iOS 18)
**Android Support:** Android 14+ (Health Connect API)

---

## 📱 Overview

LenKinVerse tracks your real-world movement (steps and distance) to reward you with in-game materials. This guide shows how to set up the native health plugins for iOS and Android.

### Modern APIs Used:
- **iOS:** HealthKit Framework (native to iOS)
- **Android:** Health Connect API (replaces deprecated Google Fit)

---

## 🍎 iOS Setup (HealthKit)

### Step 1: Add Plugin to Xcode Project

1. **Open your exported iOS project** in Xcode
2. **Add the plugin files:**
   - Navigate to `plugins/ios/healthkit/`
   - Drag `HealthKitPlugin.swift` into your Xcode project
   - Ensure "Copy items if needed" is checked

### Step 2: Enable HealthKit Capability

1. **In Xcode, select your project** (top of navigator)
2. **Select your target** → "Signing & Capabilities" tab
3. **Click "+ Capability"**
4. **Add "HealthKit"**
5. **Check "Background Delivery"** (optional, for background updates)

### Step 3: Add Privacy Descriptions

Add these keys to your `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>LenKinVerse tracks your steps and walking distance to reward you with in-game materials while you move. Your health data stays private and is never shared with third parties.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>LenKinVerse needs to read your step count and distance to calculate offline rewards.</string>
```

**How to add:**
1. Right-click `Info.plist` → Open As → Source Code
2. Add the above keys before the final `</dict>`

### Step 4: Link HealthKit Framework

1. **Select your target** → "Build Phases" tab
2. **Expand "Link Binary With Libraries"**
3. **Click "+"** and add `HealthKit.framework`

### Step 5: Register Plugin in Godot

The plugin auto-registers when the app starts. No manual code needed!

### iOS 18+ Privacy Note:

Apple requires apps to explain **why** they need health data. The description above follows Apple's 2025 privacy guidelines:
- ✅ Clear purpose statement
- ✅ What data is collected
- ✅ How it's used
- ✅ Privacy assurance

---

## 🤖 Android Setup (Health Connect)

### Step 1: Install Health Connect

**On test devices:**
1. Open Google Play Store
2. Search for "Health Connect"
3. Install (required for API to work)

**For users:** The app will prompt them to install Health Connect if not present.

### Step 2: Add Plugin to Godot

1. **Copy plugin files:**
   ```bash
   cp -r plugins/android/healthconnect godot-mobile/android/plugins/
   ```

2. **Enable plugin in Godot:**
   - Open Godot project
   - Project → Export → Android
   - Under "Plugins", check ✅ **HealthConnect**

### Step 3: Build Plugin AAR

```bash
cd plugins/android/healthconnect

# Create build.gradle if not exists
cat > build.gradle << 'EOF'
plugins {
    id 'com.android.library'
    id 'kotlin-android'
}

android {
    compileSdk 34

    defaultConfig {
        minSdk 26
        targetSdk 34
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    implementation 'androidx.health.connect:connect-client:1.1.0-alpha09'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
    compileOnly fileTree(dir: 'libs', include: ['godot-lib.*.aar'])
}
EOF

# Build AAR
./gradlew assembleRelease

# Copy to plugin folder
cp build/outputs/aar/healthconnect-release.aar ../../../godot-mobile/android/plugins/HealthConnectPlugin.aar
```

### Step 4: Configure Permissions

Add to `android/build/AndroidManifest.xml` (in `<manifest>` tag):

```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>

<queries>
    <package android:name="com.google.android.apps.healthdata" />
</queries>
```

### Android 14+ Privacy Note:

Google requires Health Connect permissions to be declared at runtime:
- User sees permission dialog when first requesting access
- Permissions are granular (can grant steps but deny distance)
- Users can revoke anytime in Health Connect settings

---

## 🎮 Using in Godot

The `HealthManager` autoload already has the integration code. Just ensure permissions are requested:

### Request Permissions (on first launch):

```gdscript
# In login_screen.gd or main menu
var granted = await HealthManager.request_permissions()

if granted:
    print("✅ Health tracking enabled!")
else:
    print("❌ User denied health permissions")
```

### Get Steps & Distance:

```gdscript
# Get today's stats
var stats = await HealthManager.get_today_stats()
print("Steps: ", stats.steps)
print("Distance: ", stats.distance_km, " km")

# Get stats since specific time
var last_week = Time.get_unix_time_from_system() - (7 * 86400)
var distance = await HealthManager.get_distance_since(last_week)
var steps = await HealthManager.get_steps_since(last_week)
```

### Offline Rewards (automatic):

The `GameManager` already uses health data when the app reopens:

```gdscript
# Happens automatically in GameManager._ready()
var distance = await HealthManager.get_distance_since(last_close_time)
var chunks = floor(distance / 50.0)  # 50m per chunk
```

---

## 🧪 Testing

### Mock Mode (Development):

Without native plugins, the app uses mock data:
- ~1 km/hour simulated walking
- Realistic step counts (~1,300 steps/km)

**To test mock mode:**
- Run in Godot editor (desktop)
- Run on device without Health Connect/HealthKit permissions

### Real Device Testing:

**iOS:**
1. Export to Xcode
2. Build & run on physical iPhone
3. Grant HealthKit permissions when prompted
4. Walk around or use Health app to add sample data

**Android:**
1. Export APK with HealthConnect plugin enabled
2. Install on Android 14+ device
3. Install Health Connect from Play Store
4. Grant permissions when prompted
5. Use Google Fit or Samsung Health to add sample data

---

## 🔒 Privacy Compliance

### iOS (App Store Review):

✅ **Required for approval:**
- Privacy descriptions in Info.plist
- Only request health data when actually needed
- Don't access health data before user consent
- Explain usage in App Privacy section of App Store Connect

### Android (Google Play):

✅ **Required for approval:**
- Declare health permissions in Data Safety section
- Request runtime permissions (not install-time)
- Link to privacy policy
- Only access health data user explicitly granted

### GDPR Compliance:

Both plugins comply with GDPR:
- User must explicitly grant permission
- Data is read-only (not stored on servers)
- User can revoke access anytime
- No health data sent to third parties

---

## 🐛 Troubleshooting

### iOS: "HealthKit not available"

**Solution:**
- HealthKit doesn't work in Simulator - use real device
- Ensure capability is added in Xcode
- Check Info.plist has privacy descriptions

### Android: "Health Connect not installed"

**Solution:**
- Install from Play Store: https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata
- Requires Android 14+
- Some manufacturers pre-install it

### "Permissions denied"

**Solution:**
- User explicitly denied - they can re-grant in Settings
- iOS: Settings → Privacy & Security → Health
- Android: Health Connect app → App permissions

### No data returned

**Solution:**
- Check date range is valid (start < end)
- Ensure device has recorded health data
- Try adding sample data manually in Health app

---

## 📊 Data Format

### Input (Godot datetime dict):

```gdscript
{
    "year": 2025,
    "month": 11,
    "day": 19,
    "hour": 10,
    "minute": 30,
    "second": 0
}
```

### Output (Steps):

```gdscript
{
    "success": true,
    "steps": 8453,
    "error": ""  # Only if success = false
}
```

### Output (Distance):

```gdscript
{
    "success": true,
    "distance": 6234.5,  # meters
    "error": ""
}
```

---

## 🚀 Production Checklist

Before releasing:

### iOS:
- [ ] HealthKit capability enabled in Xcode
- [ ] Privacy descriptions in Info.plist
- [ ] Framework linked in Build Phases
- [ ] Tested on physical device (not simulator)
- [ ] App Privacy form filled in App Store Connect

### Android:
- [ ] Health Connect plugin enabled in export preset
- [ ] Permissions declared in AndroidManifest
- [ ] AAR built and included
- [ ] Tested on Android 14+ device
- [ ] Data Safety form filled in Play Console

### Both:
- [ ] Privacy policy updated to mention health data
- [ ] User onboarding explains why health access is needed
- [ ] Graceful fallback if permissions denied
- [ ] Mock mode works without plugins (for desktop testing)

---

## 📚 Resources

### iOS HealthKit:
- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [Privacy Best Practices](https://developer.apple.com/app-store/user-privacy-and-data-use/)

### Android Health Connect:
- [Health Connect Developer Guide](https://developer.android.com/health-and-fitness/guides/health-connect)
- [Permissions & Privacy](https://developer.android.com/health-and-fitness/guides/health-connect/permissions-and-privacy)

### Godot Plugins:
- [iOS Plugins Guide](https://docs.godotengine.org/en/stable/tutorials/platform/ios/plugins_for_ios.html)
- [Android Plugins Guide](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html)

---

## ✅ Summary

You now have:
- ✅ iOS HealthKit plugin (Swift-based, iOS 15+)
- ✅ Android Health Connect plugin (Kotlin, Android 14+)
- ✅ Privacy-compliant implementations
- ✅ Automatic integration with existing HealthManager
- ✅ Mock mode for testing without devices

**The health tracking is ready to use!** Just build for your target platform and test on a real device. 🎉
