#!/bin/bash
# Standalone Build Test Script
# Tests the standalone .app bundle structure and functionality

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_test() {
    echo -e "${BLUE}🧪 $1${NC}"
}

# ============================================================================
# テスト開始
# ============================================================================

print_header "Standalone Build Test - v5.2.0"

APP_BUNDLE="build-standalone/PlayCover Manager.app"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    print_test "Test ${TOTAL_TESTS}: ${test_name}"
    
    if eval "$test_command"; then
        print_success "PASS: ${test_name}"
        ((PASS_COUNT++))
        return 0
    else
        print_error "FAIL: ${test_name}"
        ((FAIL_COUNT++))
        return 1
    fi
}

# ============================================================================
# Test 1: Build directory exists
# ============================================================================

run_test "Build directory exists" "[[ -d '$APP_BUNDLE' ]]"

# ============================================================================
# Test 2: Info.plist exists and is valid
# ============================================================================

run_test "Info.plist exists" "[[ -f '$APP_BUNDLE/Contents/Info.plist' ]]"

if [[ -f "$APP_BUNDLE/Contents/Info.plist" ]]; then
    print_info "Checking Info.plist content..."
    
    # Check CFBundleExecutable
    if grep -q "PlayCoverManager" "$APP_BUNDLE/Contents/Info.plist"; then
        print_success "CFBundleExecutable is correct"
    else
        print_error "CFBundleExecutable is missing or incorrect"
    fi
    
    # Check CFBundleName
    if grep -q "PlayCover Manager" "$APP_BUNDLE/Contents/Info.plist"; then
        print_success "CFBundleName is correct"
    else
        print_error "CFBundleName is missing or incorrect"
    fi
    
    # Check version
    if grep -q "5.2.0" "$APP_BUNDLE/Contents/Info.plist"; then
        print_success "Version is correct (5.2.0)"
    else
        print_error "Version is missing or incorrect"
    fi
fi

# ============================================================================
# Test 3: PkgInfo exists
# ============================================================================

run_test "PkgInfo exists" "[[ -f '$APP_BUNDLE/Contents/PkgInfo' ]]"

# ============================================================================
# Test 4: Launcher script exists
# ============================================================================

run_test "Launcher script exists" "[[ -f '$APP_BUNDLE/Contents/MacOS/PlayCoverManager' ]]"

# ============================================================================
# Test 5: Launcher is executable
# ============================================================================

run_test "Launcher is executable" "[[ -x '$APP_BUNDLE/Contents/MacOS/PlayCoverManager' ]]"

if [[ -x "$APP_BUNDLE/Contents/MacOS/PlayCoverManager" ]]; then
    print_info "Launcher permissions: $(ls -la "$APP_BUNDLE/Contents/MacOS/PlayCoverManager" | awk '{print $1}')"
fi

# ============================================================================
# Test 6: main.sh exists in Resources
# ============================================================================

run_test "main.sh exists" "[[ -f '$APP_BUNDLE/Contents/Resources/main.sh' ]]"

# ============================================================================
# Test 7: lib directory exists
# ============================================================================

run_test "lib directory exists" "[[ -d '$APP_BUNDLE/Contents/Resources/lib' ]]"

if [[ -d "$APP_BUNDLE/Contents/Resources/lib" ]]; then
    print_info "lib files: $(ls -1 "$APP_BUNDLE/Contents/Resources/lib" | wc -l) files"
fi

# ============================================================================
# Test 8: All required lib files exist
# ============================================================================

REQUIRED_LIBS=(
    "00_compat.sh"
    "00_core.sh"
    "01_mapping.sh"
    "02_volume.sh"
    "03_storage.sh"
    "04_app.sh"
    "05_cleanup.sh"
    "06_setup.sh"
    "07_ui.sh"
)

print_test "Test: All required lib files exist"
ALL_LIBS_EXIST=true

for lib_file in "${REQUIRED_LIBS[@]}"; do
    if [[ -f "$APP_BUNDLE/Contents/Resources/lib/$lib_file" ]]; then
        print_success "  $lib_file exists"
    else
        print_error "  $lib_file is missing"
        ALL_LIBS_EXIST=false
    fi
done

if $ALL_LIBS_EXIST; then
    ((PASS_COUNT++))
else
    ((FAIL_COUNT++))
fi
((TOTAL_TESTS++))

# ============================================================================
# Test 9: Launcher contains exec -a
# ============================================================================

if [[ -f "$APP_BUNDLE/Contents/MacOS/PlayCoverManager" ]]; then
    print_test "Test: Launcher contains 'exec -a'"
    
    if grep -q "exec -a" "$APP_BUNDLE/Contents/MacOS/PlayCoverManager"; then
        print_success "exec -a found (process name will be set)"
        ((PASS_COUNT++))
    else
        print_error "exec -a not found (process name may not be correct)"
        ((FAIL_COUNT++))
    fi
    ((TOTAL_TESTS++))
fi

# ============================================================================
# Test 10: Launcher contains single instance check
# ============================================================================

if [[ -f "$APP_BUNDLE/Contents/MacOS/PlayCoverManager" ]]; then
    print_test "Test: Launcher contains single instance check"
    
    if grep -q "playcover-manager-running.lock" "$APP_BUNDLE/Contents/MacOS/PlayCoverManager"; then
        print_success "Single instance check implemented"
        ((PASS_COUNT++))
    else
        print_error "Single instance check not found"
        ((FAIL_COUNT++))
    fi
    ((TOTAL_TESTS++))
fi

# ============================================================================
# Test 11: No quarantine attributes
# ============================================================================

print_test "Test: No quarantine attributes"

if command -v xattr &> /dev/null; then
    QUARANTINE_ATTRS=$(xattr -l "$APP_BUNDLE" 2>/dev/null | grep -c "com.apple.quarantine" || true)
    
    if [[ $QUARANTINE_ATTRS -eq 0 ]]; then
        print_success "No quarantine attributes found"
        ((PASS_COUNT++))
    else
        print_error "Quarantine attributes found: $QUARANTINE_ATTRS"
        ((FAIL_COUNT++))
    fi
else
    print_info "xattr command not available, skipping test"
fi
((TOTAL_TESTS++))

# ============================================================================
# Test 12: Bundle size is reasonable
# ============================================================================

print_test "Test: Bundle size is reasonable"

if [[ -d "$APP_BUNDLE" ]]; then
    BUNDLE_SIZE=$(du -sh "$APP_BUNDLE" | awk '{print $1}')
    print_info "Bundle size: $BUNDLE_SIZE"
    
    # Size should be less than 1MB (mostly text files)
    SIZE_BYTES=$(du -sb "$APP_BUNDLE" | awk '{print $1}')
    if [[ $SIZE_BYTES -lt 1048576 ]]; then
        print_success "Bundle size is reasonable (< 1MB)"
        ((PASS_COUNT++))
    else
        print_error "Bundle size is too large (> 1MB)"
        ((FAIL_COUNT++))
    fi
fi
((TOTAL_TESTS++))

# ============================================================================
# Summary
# ============================================================================

print_header "Test Summary"

echo ""
echo -e "Total Tests: ${BLUE}${TOTAL_TESTS}${NC}"
echo -e "Passed:      ${GREEN}${PASS_COUNT}${NC}"
echo -e "Failed:      ${RED}${FAIL_COUNT}${NC}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    print_success "🎉 All tests passed!"
    echo ""
    print_info "Next steps:"
    echo "  1. Test launching: open '$APP_BUNDLE'"
    echo "  2. Check Activity Monitor: ps aux | grep 'PlayCover Manager'"
    echo "  3. Test single instance: Double-click app icon twice"
    echo "  4. Create distribution: cd build-standalone && zip -r 'PlayCover-Manager-5.2.0-Standalone.zip' 'PlayCover Manager.app'"
    echo ""
    exit 0
else
    print_error "Some tests failed. Please review the output above."
    echo ""
    print_info "Troubleshooting:"
    echo "  1. Rebuild the app: ./build-app-standalone.sh"
    echo "  2. Check logs: cat /tmp/playcover-manager-standalone.log"
    echo "  3. Review TROUBLESHOOTING.md and STANDALONE_BUILD.md"
    echo ""
    exit 1
fi
