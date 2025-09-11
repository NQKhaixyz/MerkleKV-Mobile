# Running MerkleKV Mobile

This guide provides detailed instructions for running MerkleKV Mobile on different platforms and environments.

## 📱 Quick Start (5 Minutes)

### For Android Emulator

```bash
# 1. Clone and setup
git clone https://github.com/mico220706/MerkleKV-Mobile.git
cd MerkleKV-Mobile
dart pub global activate melos
melos bootstrap

# 2. Create and start emulator
echo no | avdmanager create avd -n merkle_device -k "system-images;android-34;google_apis;x86_64"
emulator -avd merkle_device -no-window -no-audio &

# 3. Build and deploy
cd apps/flutter_demo
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.example.flutter_demo_new/.MainActivity

# 4. Run comprehensive tests
cd ../..
./final_validation_test.sh
```

**✅ Expected Result**: MerkleKV Mobile running with full MQTT connectivity and CRUD operations.

## 🔧 Environment Requirements

### System Requirements

- **Operating System**: Linux, macOS, or Windows
- **RAM**: Minimum 8GB (16GB recommended for emulator)
- **Storage**: At least 10GB free space
- **Network**: Internet connection for MQTT brokers

### Software Dependencies

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | 3.10.0+ | Mobile app development |
| Dart SDK | 3.0.0+ | Core language runtime |
| Android Studio | Latest | Android development tools |
| JDK | 11 or 17 | Java runtime for Android |
| Git | Latest | Version control |
| Docker | Latest | Optional: Local MQTT broker |

## 🐧 Linux Setup

### Ubuntu/Debian

```bash
# Install Flutter
sudo snap install flutter --classic

# Install Android Studio
sudo snap install android-studio --classic

# Install JDK
sudo apt update
sudo apt install openjdk-17-jdk

# Set environment variables
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
echo 'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"' >> ~/.bashrc
source ~/.bashrc
```

### CentOS/RHEL/Fedora

```bash
# Install Flutter
sudo dnf install snapd
sudo snap install flutter --classic

# Install JDK
sudo dnf install java-17-openjdk-devel

# Set environment variables
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> ~/.bashrc
source ~/.bashrc
```

## 🍎 macOS Setup

```bash
# Install Flutter via Homebrew
brew install flutter

# Install JDK
brew install openjdk@17

# Set environment variables
echo 'export JAVA_HOME=/usr/local/opt/openjdk@17' >> ~/.zshrc
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"' >> ~/.zshrc
source ~/.zshrc
```

## 🪟 Windows Setup

### Using Chocolatey

```powershell
# Install Flutter
choco install flutter

# Install JDK
choco install openjdk17

# Install Android Studio
choco install androidstudio
```

### Manual Installation

1. Download Flutter SDK from [flutter.dev](https://flutter.dev)
2. Download Android Studio from [developer.android.com](https://developer.android.com)
3. Download JDK 17 from [adoptium.net](https://adoptium.net)
4. Set environment variables in System Properties

## 📱 Device Setup

### Android Emulator

#### Create AVD

```bash
# List available system images
sdkmanager --list | grep system-images

# Create AVD with Google APIs
echo no | avdmanager create avd -n merkle_test -k "system-images;android-34;google_apis;x86_64"

# Start emulator
emulator -avd merkle_test -no-window -no-audio &

# Verify emulator is running
adb devices
```

#### Emulator Configuration

For optimal performance:

```bash
# Start with specific configuration
emulator -avd merkle_test \
  -no-window \
  -no-audio \
  -memory 4096 \
  -cores 4 \
  -gpu swiftshader_indirect &
```

### Physical Android Device

#### Enable Developer Options

1. Go to **Settings** → **About phone**
2. Tap **Build number** 7 times
3. Go back to **Settings** → **Developer options**
4. Enable **USB debugging**
5. Connect device via USB

#### Verify Connection

```bash
# List connected devices
adb devices

# Install APK on device
adb -s YOUR_DEVICE_ID install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 🏗️ Build Instructions

### Debug Build

```bash
cd apps/flutter_demo

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Install on device/emulator
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Release Build

```bash
# Build release APK
flutter build apk --release

# Install release APK
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Profile Build (Performance Testing)

```bash
# Build profile APK
flutter build apk --profile

# Install and run with performance monitoring
adb install -r build/app/outputs/flutter-apk/app-profile.apk
flutter run --profile --device-id=YOUR_DEVICE_ID
```

## 🧪 Testing Modes

### 1. Manual Testing

Launch the app and test through UI:

```bash
# Start application
adb shell am start -n com.example.flutter_demo_new/.MainActivity

# Take screenshots for documentation
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png .
```

### 2. Automated Testing

```bash
# Run comprehensive test suite
./final_validation_test.sh

# Run Flutter integration tests
cd apps/flutter_demo
flutter test integration_test/
```

### 3. Performance Testing

```bash
# Monitor app performance
adb shell top | grep flutter_demo_new

# Monitor memory usage
adb shell dumpsys meminfo com.example.flutter_demo_new

# Monitor network activity
adb shell netstat | grep flutter_demo_new
```

## 🌐 MQTT Broker Configuration

### Public Brokers (Default)

The app is pre-configured to use public MQTT brokers:

- **Primary**: `test.mosquitto.org:1883`
- **Alternative**: `broker.hivemq.com:1883`
- **Backup**: `broker.emqx.io:1883`

### Local Broker Setup

```bash
# Start local Mosquitto broker
cd broker/mosquitto
docker-compose up -d

# Configure app to use local broker
# In app UI: Change broker to "localhost" or your machine's IP
```

### Custom Broker

To use your own MQTT broker:

1. Open the Flutter demo app
2. In the "Connection" section, change:
   - **Broker**: Your broker hostname/IP
   - **Port**: Your broker port (default: 1883)
   - **Credentials**: Username/password if required

## 🔍 Debugging

### Common Issues

#### 1. Emulator Won't Start

```bash
# Check if emulator is already running
ps aux | grep emulator

# Kill existing processes
pkill -f emulator

# Check available space
df -h

# Restart with verbose output
emulator -avd merkle_test -verbose
```

#### 2. App Installation Failed

```bash
# Check device connection
adb devices

# Uninstall existing app
adb uninstall com.example.flutter_demo_new

# Clear adb cache
adb kill-server
adb start-server

# Reinstall
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

#### 3. MQTT Connection Issues

```bash
# Test broker connectivity
ping test.mosquitto.org

# Try alternative broker in app UI
# Use: broker.hivemq.com or broker.emqx.io

# Check firewall settings
sudo ufw status
```

### Debug Commands

```bash
# View real-time logs
adb logcat | grep flutter

# Filter MerkleKV logs
adb logcat | grep -i "merkle\|mqtt"

# Monitor app lifecycle
adb logcat | grep ActivityManager

# Check app memory
adb shell dumpsys meminfo com.example.flutter_demo_new

# List app processes
adb shell ps | grep flutter_demo_new
```

## 📊 Performance Monitoring

### Real-time Monitoring

```bash
# CPU usage
adb shell top | grep flutter_demo_new

# Memory usage
watch -n 1 'adb shell dumpsys meminfo com.example.flutter_demo_new | grep TOTAL'

# Network activity
adb shell cat /proc/net/dev | grep -v "lo:"

# Battery usage
adb shell dumpsys battery
```

### Benchmark Testing

```bash
# Run performance benchmarks
flutter drive --target=test_driver/perf_test.dart --profile

# Memory leak detection
flutter run --profile --trace-systrace
```

## 🚀 Production Deployment

### Release Preparation

```bash
# Build release APK
flutter build apk --release --obfuscate --split-debug-info=debug-info/

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Verify release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Distribution

1. **Direct APK**: Share `app-release.apk` file
2. **Google Play Store**: Upload `app-release.aab` file
3. **Enterprise**: Use your organization's app distribution platform

## 🛠️ Advanced Configuration

### Custom Build Configuration

Create `apps/flutter_demo/android/app/build.gradle.local`:

```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

### Environment-specific Builds

```bash
# Development build
flutter build apk --debug --flavor dev

# Staging build
flutter build apk --release --flavor staging

# Production build
flutter build apk --release --flavor prod
```

## 📋 Troubleshooting Checklist

Before reporting issues, verify:

- [ ] Flutter SDK version ≥ 3.10.0
- [ ] Android SDK properly configured
- [ ] Emulator or device connected (`adb devices`)
- [ ] Internet connectivity available
- [ ] Sufficient disk space (>2GB free)
- [ ] Java/Kotlin versions compatible
- [ ] All dependencies installed (`melos bootstrap`)
- [ ] No conflicting processes running

## 📚 Additional Resources

- 📖 [Complete Tutorial](TUTORIAL.md)
- 🏗️ [Architecture Documentation](docs/architecture.md)
- 🔧 [Contributing Guide](CONTRIBUTING.md)
- 🐛 [Issue Tracker](https://github.com/mico220706/MerkleKV-Mobile/issues)
- 💬 [Discussions](https://github.com/mico220706/MerkleKV-Mobile/discussions)

---

**🎉 Success!** You should now have MerkleKV Mobile running successfully on your target platform.
