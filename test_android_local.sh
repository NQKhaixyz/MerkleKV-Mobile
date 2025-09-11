#!/bin/bash

# =============================================================================
# Local Android Testing Script
# =============================================================================
# This script allows developers to run Android testing locally before pushing
# to CI, following the same procedures used in the GitHub Actions workflow.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

function log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

function success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function error() {
    echo -e "${RED}❌ $1${NC}"
}

function highlight() {
    echo -e "${PURPLE}🎯 $1${NC}"
}

echo "🚀 MerkleKV Mobile - Local Android Testing"
echo "=========================================="

# Check prerequisites
log "Checking prerequisites..."

# Check Flutter
if ! command -v flutter &> /dev/null; then
    error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check Java
if ! command -v java &> /dev/null; then
    error "Java is not installed or not in PATH"
    exit 1
fi

# Check Android SDK
if [ -z "$ANDROID_HOME" ]; then
    error "ANDROID_HOME environment variable is not set"
    exit 1
fi

success "Prerequisites check passed"

# Verify Flutter doctor
log "Running Flutter doctor..."
flutter doctor

# Bootstrap project
log "Bootstrapping project dependencies..."
if command -v melos &> /dev/null; then
    melos bootstrap
else
    warning "Melos not found, installing..."
    dart pub global activate melos
    melos bootstrap
fi

success "Project dependencies installed"

# Build Flutter demo
log "Building Flutter demo application..."
cd apps/flutter_demo

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Analyze code
log "Running static analysis..."
flutter analyze

# Build debug APK
log "Building Android APK..."
flutter build apk --debug

# Verify build
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    success "Android APK built successfully"
    ls -la build/app/outputs/flutter-apk/
else
    error "Android APK build failed"
    exit 1
fi

cd ../..

# Check for emulator
log "Checking for running Android emulator..."
if adb devices | grep -q "emulator"; then
    success "Android emulator detected"
    
    # Ask user if they want to run E2E tests
    read -p "Do you want to run end-to-end tests on the emulator? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing APK on emulator..."
        adb install -r apps/flutter_demo/build/app/outputs/flutter-apk/app-debug.apk
        
        if adb shell pm list packages | grep -q "com.example.flutter_demo_new"; then
            success "APK installed successfully"
            
            log "Running comprehensive E2E tests..."
            chmod +x final_validation_test.sh
            
            if ./final_validation_test.sh; then
                success "All E2E tests passed!"
            else
                error "E2E tests failed"
                exit 1
            fi
        else
            error "APK installation failed"
            exit 1
        fi
    fi
else
    warning "No Android emulator detected"
    warning "To run full E2E tests, start an Android emulator first"
    warning "Run: emulator -avd YOUR_AVD_NAME"
fi

highlight "Local Android testing completed successfully!"
echo ""
echo "Summary:"
echo "✅ Flutter environment validated"
echo "✅ Project dependencies installed" 
echo "✅ Static analysis passed"
echo "✅ Android APK built successfully"

if adb devices | grep -q "emulator"; then
    echo "✅ E2E tests completed"
else
    echo "⚠️  E2E tests skipped (no emulator)"
fi

echo ""
echo "🎉 Ready for CI/CD pipeline!"
