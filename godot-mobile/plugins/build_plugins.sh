#!/bin/bash
# Build health plugins for iOS and Android
# Compatible with iOS 15+ and Android 14+

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🏗️  Building LenKinVerse Health Plugins"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Build Android Plugin
build_android() {
    echo ""
    echo "${YELLOW}📦 Building Android Health Connect Plugin...${NC}"

    cd android/healthconnect

    # Check if Godot library exists
    if [ ! -f "libs/godot-lib.*.aar" ]; then
        echo "${RED}❌ Godot library not found in libs/!${NC}"
        echo "Please copy godot-lib.*.aar from your Godot installation:"
        echo "  cp ~/.local/share/godot/templates/4.x.x/android_source/godot-lib.*.aar ./libs/"
        return 1
    fi

    # Build with Gradle
    if [ -x "./gradlew" ]; then
        ./gradlew clean assembleRelease
    else
        echo "${RED}❌ gradlew not found. Run: gradle wrapper${NC}"
        return 1
    fi

    # Copy to Godot plugins folder
    if [ -f "build/outputs/aar/healthconnect-release.aar" ]; then
        mkdir -p ../../android/plugins
        cp build/outputs/aar/healthconnect-release.aar ../../android/plugins/HealthConnectPlugin.aar
        echo "${GREEN}✅ Android plugin built: android/plugins/HealthConnectPlugin.aar${NC}"
    else
        echo "${RED}❌ Build failed - AAR not found${NC}"
        return 1
    fi

    cd "$SCRIPT_DIR"
}

# Build iOS Plugin (requires Xcode)
build_ios() {
    echo ""
    echo "${YELLOW}🍎 Building iOS HealthKit Plugin...${NC}"

    # Check if on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "${YELLOW}⚠️  iOS plugin requires macOS with Xcode - skipping${NC}"
        return 0
    fi

    cd ios/healthkit

    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        echo "${RED}❌ Xcode not found. Install from App Store.${NC}"
        return 1
    fi

    # For Swift plugins, we just need to verify the files exist
    if [ -f "HealthKitPlugin.swift" ] && [ -f "HealthKit.gdip" ]; then
        echo "${GREEN}✅ iOS plugin files ready${NC}"
        echo "   Add HealthKitPlugin.swift to your Xcode project when exporting"
        echo "   Enable HealthKit capability in Xcode project settings"
    else
        echo "${RED}❌ iOS plugin files missing${NC}"
        return 1
    fi

    cd "$SCRIPT_DIR"
}

# Main
main() {
    # Build Android
    if build_android; then
        ANDROID_SUCCESS=true
    else
        ANDROID_SUCCESS=false
    fi

    # Build iOS
    if build_ios; then
        IOS_SUCCESS=true
    else
        IOS_SUCCESS=false
    fi

    # Summary
    echo ""
    echo "========================================="
    echo "🎉 Build Summary:"

    if [ "$ANDROID_SUCCESS" = true ]; then
        echo "${GREEN}✅ Android Health Connect plugin ready${NC}"
    else
        echo "${RED}❌ Android build failed${NC}"
    fi

    if [ "$IOS_SUCCESS" = true ]; then
        echo "${GREEN}✅ iOS HealthKit plugin ready${NC}"
    else
        echo "${RED}❌ iOS setup incomplete${NC}"
    fi

    echo ""
    echo "📚 Next steps:"
    echo "   1. Enable plugins in Godot export presets"
    echo "   2. For iOS: Add HealthKitPlugin.swift to Xcode project"
    echo "   3. See HEALTH_API_SETUP.md for detailed instructions"
    echo "========================================="

    # Exit with error if any build failed
    if [ "$ANDROID_SUCCESS" = false ] || [ "$IOS_SUCCESS" = false ]; then
        exit 1
    fi
}

# Run
main
