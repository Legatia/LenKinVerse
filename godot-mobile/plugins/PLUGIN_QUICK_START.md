# 🚀 Health Plugin Quick Start

## For Developers: Get Health Tracking Working in 5 Minutes

---

## iOS (Xcode)

### 1. Add Plugin (1 min)
```bash
# Plugin files are ready in:
plugins/ios/healthkit/HealthKitPlugin.swift
plugins/ios/healthkit/HealthKit.gdip

# When exporting from Godot:
# Project → Export → iOS → Add "HealthKit" plugin
```

### 2. Xcode Setup (2 min)
1. Open exported project in Xcode
2. Target → "Signing & Capabilities" → Add "HealthKit"
3. Add to Info.plist:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Track your movement for in-game rewards</string>
```

### 3. Test (2 min)
- Build on physical iPhone (HealthKit doesn't work in Simulator)
- Grant permissions when prompted
- Walk around or add sample data in Health app

---

## Android (Godot + Gradle)

### 1. Build Plugin (2 min)
```bash
cd plugins/android/healthconnect

# Copy Godot AAR library
cp path/to/godot-lib.*.aar libs/

# Build
./gradlew assembleRelease

# Copy to Godot project
cp build/outputs/aar/healthconnect-release.aar \
   ../../../godot-mobile/android/plugins/
```

### 2. Enable in Godot (1 min)
1. Project → Export → Android
2. Plugins → Check ✅ "HealthConnect"
3. Export APK

### 3. Test (2 min)
- Install APK on Android 14+ device
- Install "Health Connect" from Play Store
- Grant permissions in app
- Add sample data in Google Fit or Samsung Health

---

## Verify It's Working

### In Godot Console:
```
✅ HealthKit plugin loaded (iOS 15+)
# or
✅ Health Connect plugin loaded (Android 14+)
```

### In Game:
```gdscript
# Test in any script
var stats = await HealthManager.get_today_stats()
print("Steps today: ", stats.steps)
print("Distance: ", stats.distance_km, " km")
```

---

## Already Working!

The `HealthManager` autoload already integrates with:
- ✅ Login screen (requests permissions)
- ✅ GameManager (offline rewards based on movement)
- ✅ Profile UI (could show step count - not implemented yet)

**No code changes needed** - just build with the plugins!

---

## Troubleshooting

**"Mock mode" message?**
→ Plugin not loaded. Check export settings.

**iOS: "HealthKit not available"?**
→ Use real iPhone, not Simulator.

**Android: "Health Connect not installed"?**
→ Install from Play Store.

**No data returned?**
→ Add sample data in Health app / Google Fit.

---

See **HEALTH_API_SETUP.md** for detailed instructions.
