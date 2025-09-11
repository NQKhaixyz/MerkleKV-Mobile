# MerkleKV Mobile - Quick Start Tutorial

This tutorial will guide you through setting up and running MerkleKV Mobile on Android devices, from development environment setup to end-to-end testing.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Project Setup](#project-setup)
4. [Running the Demo App](#running-the-demo-app)
5. [Testing Guide](#testing-guide)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before starting, ensure you have the following installed:

- **Flutter SDK** 3.10.0+ 
- **Dart SDK** 3.0.0+
- **Android Studio** with Android SDK
- **Java Development Kit (JDK)** 11 or 17
- **Git** for version control
- **Docker** (optional, for local MQTT broker)

## Environment Setup

### 1. Install Flutter

```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses
```

### 2. Configure Android Environment

```bash
# Set environment variables (add to ~/.bashrc or ~/.zshrc)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64  # Adjust path as needed
export ANDROID_HOME=/opt/android-sdk                 # Adjust path as needed
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

# Reload environment
source ~/.bashrc  # or ~/.zshrc
```

### 3. Create Android Virtual Device (AVD)

```bash
# List available system images
sdkmanager --list | grep system-images

# Create AVD (Android API 34)
echo no | avdmanager create avd -n merkle_test_device -k "system-images;android-34;google_apis;x86_64"

# List created AVDs
emulator -list-avds
```

### 4. Start Android Emulator

```bash
# Start emulator in headless mode
emulator -avd merkle_test_device -no-window -no-audio &

# Verify emulator is running
adb devices
```

Expected output:
```
List of devices attached
emulator-5554	device
```

## Project Setup

### 1. Clone and Setup Project

```bash
# Clone the repository
git clone https://github.com/mico220706/MerkleKV-Mobile.git
cd MerkleKV-Mobile

# Install Melos for monorepo management
dart pub global activate melos

# Bootstrap all packages
melos bootstrap
```

### 2. Verify Project Structure

```
MerkleKV-Mobile/
├── apps/
│   └── flutter_demo/              # Main Flutter demo application
├── packages/
│   └── merkle_kv_core/            # Core MerkleKV library
├── broker/
│   └── mosquitto/                 # MQTT broker configuration
├── scripts/
│   ├── dev/                       # Development scripts
│   └── test/                      # Testing scripts
└── docs/                          # Documentation
```

### 3. Run Static Analysis

```bash
# Format code
dart format .

# Analyze code
dart analyze

# Run tests
melos run test
```

## Running the Demo App

### 1. Navigate to Flutter Demo

```bash
cd apps/flutter_demo
```

### 2. Get Dependencies

```bash
flutter pub get
```

### 3. Build and Install

```bash
# Clean previous builds
flutter clean

# Build debug APK
flutter build apk --debug

# Install on emulator
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### 4. Launch Application

```bash
# Start the app
adb shell am start -n com.example.flutter_demo_new/.MainActivity

# Verify app is running
adb shell pm list packages | grep flutter_demo_new
```

Expected output:
```
package:com.example.flutter_demo_new
```

## Testing Guide

### 1. Manual Testing Through UI

The MerkleKV Mobile Demo app provides a complete interface for testing all functionality:

#### Connection Management
1. **Configure MQTT Broker**: Default is `test.mosquitto.org:1883`
2. **Connect**: Tap "Connect" button to establish MQTT connection
3. **Monitor Status**: Watch connection status indicator

#### Key-Value Operations
1. **SET Operation**: 
   - Enter key (e.g., `user:123`)
   - Enter value (e.g., `John Doe`)
   - Tap "SET" button

2. **GET Operation**:
   - Enter key to retrieve
   - Tap "GET" button
   - Check result in "Last Operation" section

3. **DELETE Operation**:
   - Enter key to delete
   - Tap "DELETE" button

4. **KEYS Operation**:
   - Tap "KEYS" button to list all stored keys

### 2. Automated Testing

#### Run Comprehensive Test Suite

```bash
# Make test script executable
chmod +x ../../final_validation_test.sh

# Run comprehensive validation
../../final_validation_test.sh
```

This script performs:
- ✅ Infrastructure validation
- ✅ App functionality testing
- ✅ Network configuration testing
- ✅ CRUD operations validation
- ✅ Performance and stability testing

#### Expected Output
```
🎉 COMPREHENSIVE VALIDATION COMPLETE!
=====================================

🎯 TEST RESULTS SUMMARY:
✅ Infrastructure: Android emulator operational
✅ Application: MerkleKV Mobile Demo installed and running
✅ Network: MQTT broker configurations tested
✅ CRUD Operations: SET, GET, DELETE, KEYS all functional
✅ Data Persistence: Key-value storage working
✅ Performance: App stable under load
✅ Memory: No memory leaks detected
✅ UI: Responsive user interface confirmed

🎯 MERKLE-KV MOBILE: FULLY OPERATIONAL ON ANDROID ✅
```

### 3. Integration Testing

```bash
# Run Flutter integration tests
flutter test integration_test/

# Run with specific device
flutter test integration_test/ --device-id=emulator-5554
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Emulator Not Starting

**Issue**: `emulator: ERROR: Running multiple emulators...`

**Solution**:
```bash
# Kill existing emulator processes
pkill -f emulator

# Restart emulator
emulator -avd merkle_test_device -no-window -no-audio &
```

#### 2. App Installation Failed

**Issue**: `INSTALL_FAILED_UPDATE_INCOMPATIBLE`

**Solution**:
```bash
# Uninstall existing app
adb uninstall com.example.flutter_demo_new

# Reinstall
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

#### 3. MQTT Connection Issues

**Issue**: Connection timeout or failed to connect

**Solutions**:
- Check internet connectivity
- Try alternative brokers:
  - `broker.hivemq.com:1883`
  - `broker.emqx.io:1883`
- Verify firewall settings

#### 4. Flutter Build Errors

**Issue**: Gradle build failed

**Solution**:
```bash
# Clean Flutter cache
flutter clean
flutter pub get

# Update dependencies
melos bootstrap

# Rebuild
flutter build apk --debug
```

#### 5. Permission Errors

**Issue**: `Permission denied` when running scripts

**Solution**:
```bash
# Make scripts executable
chmod +x scripts/dev/*.sh
chmod +x *.sh
```

### Debug Commands

```bash
# Check emulator status
adb devices

# View app logs
adb logcat | grep flutter

# Take screenshot
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png .

# Monitor app memory
adb shell dumpsys meminfo com.example.flutter_demo_new

# List installed packages
adb shell pm list packages | grep demo
```

## Advanced Usage

### 1. Local MQTT Broker Setup

```bash
# Start local mosquitto broker
cd broker/mosquitto
docker-compose up -d

# Verify broker is running
docker-compose ps

# Configure app to use local broker
# In app: Change broker to "localhost" or your machine's IP
```

### 2. Custom Configuration

```dart
// Example custom configuration
final config = MerkleKVConfig(
  mqttHost: 'your-broker.com',
  mqttPort: 1883,
  clientId: 'your-device-id',
  nodeId: 'unique-node-id',
  username: 'your-username',    // Optional
  password: 'your-password',    // Optional
  mqttUseTls: true,            // For secure connections
  persistenceEnabled: true,     // Enable data persistence
);
```

### 3. Performance Monitoring

```bash
# Monitor real-time performance
adb shell top | grep flutter_demo_new

# Monitor network usage
adb shell cat /proc/net/dev

# Monitor battery usage
adb shell dumpsys battery
```

## Next Steps

After successfully running the demo:

1. **Explore the Code**: Study `apps/flutter_demo/lib/main.dart` for implementation details
2. **Read Documentation**: Check `docs/` folder for architecture details
3. **Contribute**: See `CONTRIBUTING.md` for contribution guidelines
4. **Deploy**: Use release builds for production deployment

## Support

- 📖 **Documentation**: [docs/](../docs/)
- 🐛 **Issues**: [GitHub Issues](https://github.com/mico220706/MerkleKV-Mobile/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/mico220706/MerkleKV-Mobile/discussions)

---

**🎉 Congratulations!** You now have MerkleKV Mobile running on Android with full end-to-end testing capabilities.
