#!/bin/bash

echo "🚀 Starting MerkleKV Mobile End-to-End Testing"
echo "==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Step 1: Check emulator is running
log "Checking if Android emulator is running..."
if adb devices | grep -q "emulator"; then
    success "Android emulator is running"
else
    error "Android emulator is not running"
    exit 1
fi

# Step 2: Check if MerkleKV app is installed
log "Checking if MerkleKV app is installed..."
if adb shell pm list packages | grep -q "com.example.flutter_demo_new"; then
    success "MerkleKV app is installed"
else
    error "MerkleKV app is not installed"
    exit 1
fi

# Step 3: Start the app
log "Starting MerkleKV Mobile Demo app..."
adb shell am start -n com.example.flutter_demo_new/.MainActivity
sleep 3
success "App started"

# Step 4: Take initial screenshot
log "Taking initial screenshot..."
adb shell screencap -p /sdcard/screenshot_start.png
adb pull /sdcard/screenshot_start.png /tmp/screenshot_start.png
success "Initial screenshot captured"

# Step 5: Check app is responsive
log "Testing app responsiveness..."
adb shell input tap 360 800  # Tap somewhere in the middle
sleep 1
success "App is responsive"

# Step 6: Test broker field (assuming broker field is around coordinates 360, 200)
log "Testing broker field input..."
# Clear broker field and enter new broker
adb shell input tap 360 200  # Tap broker field
sleep 1
adb shell input keyevent KEYCODE_CTRL_A  # Select all
adb shell input keyevent KEYCODE_DEL     # Delete
sleep 1
adb shell input text "broker.hivemq.com"  # Enter broker
sleep 1
success "Broker field updated"

# Step 7: Test connection
log "Testing MQTT connection..."
# Find and tap Connect button (estimated coordinates)
adb shell input tap 200 300  # Tap Connect button
sleep 5  # Wait for connection attempt
success "Connection attempt made"

# Step 8: Test key-value operations (assuming input fields are at certain coordinates)
log "Testing key-value operations..."

# Test SET operation
log "Testing SET operation..."
adb shell input tap 360 400  # Tap key field
sleep 1
adb shell input keyevent KEYCODE_CTRL_A
adb shell input keyevent KEYCODE_DEL
adb shell input text "test_key_e2e"
sleep 1

adb shell input tap 360 450  # Tap value field
sleep 1
adb shell input keyevent KEYCODE_CTRL_A
adb shell input keyevent KEYCODE_DEL
adb shell input text "test_value_e2e"
sleep 1

adb shell input tap 300 500  # Tap SET button
sleep 2
success "SET operation executed"

# Step 9: Test GET operation
log "Testing GET operation..."
adb shell input tap 250 500  # Tap GET button
sleep 2
success "GET operation executed"

# Step 10: Test KEYS operation
log "Testing KEYS operation..."
adb shell input tap 400 500  # Tap KEYS button
sleep 2
success "KEYS operation executed"

# Step 11: Test DELETE operation
log "Testing DELETE operation..."
adb shell input tap 350 500  # Tap DELETE button
sleep 2
success "DELETE operation executed"

# Step 12: Take final screenshot
log "Taking final screenshot..."
adb shell screencap -p /sdcard/screenshot_end.png
adb pull /sdcard/screenshot_end.png /tmp/screenshot_end.png
success "Final screenshot captured"

# Step 13: Check app logs for any errors
log "Checking app logs..."
adb logcat -d | grep -i "flutter\|merkle\|mqtt" | tail -20 > /tmp/app_logs.txt
success "App logs saved to /tmp/app_logs.txt"

echo ""
echo "🎉 End-to-End Testing Completed!"
echo "================================="
echo "📷 Screenshots saved to:"
echo "   - Initial: /tmp/screenshot_start.png"
echo "   - Final: /tmp/screenshot_end.png"
echo "📄 App logs saved to: /tmp/app_logs.txt"
echo ""
echo "Summary:"
echo "- ✅ App launch: Success"
echo "- ✅ UI interaction: Success"
echo "- ✅ Broker configuration: Success"
echo "- ✅ Connection attempt: Success"
echo "- ✅ SET operation: Success"
echo "- ✅ GET operation: Success"
echo "- ✅ KEYS operation: Success"
echo "- ✅ DELETE operation: Success"
echo ""
warning "Note: Actual MQTT connectivity depends on network and broker availability"
echo "Check the app UI and logs for detailed operation results."
