#!/bin/zsh
#
# PlayCover Volume Manager - Module 04: App Management
# ════════════════════════════════════════════════════════════════════
#
# This module provides IPA installation and app management:
# - IPA file selection (single/batch)
# - App information extraction from Info.plist
# - PlayCover volume mounting
# - App volume creation and mounting
# - IPA installation to PlayCover with progress tracking
# - Installation status monitoring
# - Batch installation support
#
# Installation Detection Strategy (v5.0.2):
#   - Standard pattern: Wait for 2nd update + 4sec stability → Complete
#   - Tiny app fallback: 1 update only + 8sec wait + 4sec stability → Complete
#   - Both new and overwrite installs use same detection
#   - Robust crash detection and recovery
#
# Version: 5.0.2
# Part of: Modular Architecture Refactoring

#######################################################
# Global Variables for Installation
#######################################################

# Arrays for selected IPAs and results
declare -a SELECTED_IPAS=()
declare -a INSTALL_SUCCESS=()
declare -a INSTALL_FAILED=()

# Installation state
TOTAL_IPAS=0
CURRENT_IPA_INDEX=0
BATCH_MODE=false

# Current app information
APP_BUNDLE_ID=""
APP_NAME=""
APP_NAME_EN=""
APP_VERSION=""
APP_VOLUME_NAME=""

# PlayCover volume device
PLAYCOVER_VOLUME_DEVICE=""

# Selected disk for volume creation
SELECTED_DISK=""

#######################################################
# App Management Helper Functions
#######################################################

# Show installation/uninstallation summary
_show_install_summary() {
    local operation="$1"  # "インストール" or "アンインストール"
    
    echo ""
    print_success "全ての処理が完了しました"
    
    if [[ ${#INSTALL_SUCCESS} -gt 0 ]]; then
        echo ""
        print_success "${operation}成功: ${#INSTALL_SUCCESS} 個"
        for app in "${(@)INSTALL_SUCCESS}"; do
            echo "  ✅ $app"
        done
    fi
    
    if [[ ${#INSTALL_FAILED} -gt 0 ]]; then
        echo ""
        print_error "${operation}失敗: ${#INSTALL_FAILED} 個"
        for app in "${(@)INSTALL_FAILED}"; do
            echo "  ❌ $app"
        done
    fi
    
    echo ""
    echo -n "Enterキーでメニューに戻る..."
    read
}

# Check if app is running and show appropriate error
_check_app_not_running() {
    local bundle_id="$1"
    local app_name="$2"
    local operation="$3"  # e.g., "インストール", "アンインストール"
    
    if is_app_running "$bundle_id"; then
        echo ""
        print_error "アプリが実行中のため、${operation}できません"
        echo ""
        print_info "アプリを終了してから再度お試しください"
        return 1
    fi
    
    return 0
}

# Show uninstall warning and confirmation
_show_uninstall_warning() {
    local app_name="$1"
    local bundle_id="$2"
    local volume_name="$3"
    
    echo ""
    print_warning "以下のアプリをアンインストールします:"
    echo ""
    echo "  アプリ名: ${GREEN}${app_name}${NC}"
    echo "  Bundle ID: ${bundle_id}"
    echo "  ボリューム: ${volume_name}"
    echo ""
    print_warning "この操作は以下を実行します:"
    echo "  1. PlayCover からアプリを削除 (Applications/)"
    echo "  2. アプリ設定を削除 (App Settings/)"
    echo "  3. Entitlements を削除"
    echo "  4. Keymapping を削除"
    echo "  5. Containersフォルダを削除"
    echo "  6. APFSボリュームをアンマウント"
    echo "  7. APFSボリュームを削除"
    echo "  8. マッピング情報を削除"
    echo ""
    print_error "この操作は取り消せません！"
    echo ""
}

#######################################################
# PlayCover Volume Management
#######################################################

check_playcover_volume_mount_install() {
    if [[ ! -d "$PLAYCOVER_CONTAINER" ]]; then
        /usr/bin/sudo /bin/mkdir -p "$PLAYCOVER_CONTAINER"
    fi
    
    local is_mounted=$(/sbin/mount | /usr/bin/grep " on ${PLAYCOVER_CONTAINER} " | /usr/bin/grep -c "apfs")
    
    if [[ $is_mounted -gt 0 ]]; then
        PLAYCOVER_VOLUME_DEVICE=$(/sbin/mount | /usr/bin/grep " on ${PLAYCOVER_CONTAINER} " | /usr/bin/awk '{print $1}')
        return 0
    fi
    
    # Get device in one call (validates existence)
    local volume_device=$(validate_and_get_device "$PLAYCOVER_VOLUME_NAME")
    
    if [[ $? -ne 0 ]] || [[ -z "$volume_device" ]]; then
        print_error "PlayCover ボリュームが見つかりません"
        print_info "初期セットアップスクリプトを実行してください"
        exit_with_cleanup 1 "PlayCover ボリュームが見つかりません"
    fi
    
    PLAYCOVER_VOLUME_DEVICE="/dev/${volume_device}"
    
    local current_mount=$(get_volume_mount_point "$PLAYCOVER_VOLUME_DEVICE")
    
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "Not applicable (no file system)" ]]; then
        if ! unmount_volume "$PLAYCOVER_VOLUME_DEVICE" "silent" "force"; then
            print_error "ボリュームのアンマウントに失敗しました"
            exit_with_cleanup 1 "ボリュームアンマウントエラー"
        fi
    fi
    
    if /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$PLAYCOVER_VOLUME_DEVICE" "$PLAYCOVER_CONTAINER"; then
        /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
        
        # Create necessary directory structure if it doesn't exist
        local playcover_apps="${PLAYCOVER_CONTAINER}/Applications"
        local playcover_settings="${PLAYCOVER_CONTAINER}/App Settings"
        local playcover_entitlements="${PLAYCOVER_CONTAINER}/Entitlements"
        local playcover_keymapping="${PLAYCOVER_CONTAINER}/Keymapping"
        
        if [[ ! -d "$playcover_apps" ]]; then
            /bin/mkdir -p "$playcover_apps" 2>/dev/null || true
        fi
        if [[ ! -d "$playcover_settings" ]]; then
            /bin/mkdir -p "$playcover_settings" 2>/dev/null || true
        fi
        if [[ ! -d "$playcover_entitlements" ]]; then
            /bin/mkdir -p "$playcover_entitlements" 2>/dev/null || true
        fi
        if [[ ! -d "$playcover_keymapping" ]]; then
            /bin/mkdir -p "$playcover_keymapping" 2>/dev/null || true
        fi
    else
        print_error "$MSG_MOUNT_FAILED"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
}

#######################################################
# IPA File Selection
#######################################################

select_ipa_files() {
    print_header "インストールする IPA ファイルの選択"
    
    local selected=$(osascript <<'EOF' 2>/dev/null
try
    tell application "System Events"
        activate
        set theFiles to choose file with prompt "インストールする IPA ファイルを選択してください（複数選択可）:" of type {"ipa"} with multiple selections allowed
        
        set posixPaths to {}
        repeat with aFile in theFiles
            set end of posixPaths to POSIX path of aFile
        end repeat
        
        set AppleScript's text item delimiters to linefeed
        return posixPaths as text
    end tell
on error errorMessage
    -- User cancelled, return empty string
    return ""
end try
EOF
)
    
    if [[ -z "$selected" ]]; then
        print_info "キャンセルされました"
        echo ""
        echo -n "Enterキーでメニューに戻る..."
        read
        return 1
    fi
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ -f "$line" ]]; then
            if [[ ! "$line" =~ \.ipa$ ]]; then
                print_error "選択されたファイルは IPA ファイルではありません: ${line}"
                echo ""
                echo -n "Enterキーでメニューに戻る..."
                read
                return 1
            fi
            SELECTED_IPAS+=("$line")
        fi
    done <<< "$selected"
    
    TOTAL_IPAS=${#SELECTED_IPAS}
    
    if [[ $TOTAL_IPAS -eq 0 ]]; then
        print_error "有効な IPA ファイルが選択されませんでした"
        echo ""
        echo -n "Enterキーでメニューに戻る..."
        read
        return 1
    fi
    
    if [[ $TOTAL_IPAS -gt 1 ]]; then
        BATCH_MODE=true
        print_success "IPA ファイルを ${TOTAL_IPAS} 個選択しました"
    else
        # zsh 1-based indexing
        print_success "$(basename "${SELECTED_IPAS[1]}")"
    fi
    
    echo ""
}

#######################################################
# App Information Extraction
#######################################################

extract_ipa_info() {
    local ipa_file=$1
    
    local temp_dir=$(create_temp_dir) || return 1
    
    local plist_path=$(unzip -l "$ipa_file" 2>/dev/null | /usr/bin/grep -E "Payload/.*\.app/Info\.plist" | head -n 1 | /usr/bin/awk '{print $NF}')
    
    if [[ -z "$plist_path" ]]; then
        print_error "IPA 内に Info.plist が見つかりません"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    if ! /usr/bin/unzip -q "$ipa_file" "$plist_path" -d "$temp_dir" 2>/dev/null; then
        print_error "Info.plist の解凍に失敗しました"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    local info_plist="${temp_dir}/${plist_path}"
    
    if [[ -z "$info_plist" ]]; then
        print_error "Info.plist が見つかりません"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)
    
    if [[ -z "$APP_BUNDLE_ID" ]]; then
        print_error "Bundle Identifier の取得に失敗しました"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist" 2>/dev/null)
    if [[ -z "$APP_VERSION" ]]; then
        APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist" 2>/dev/null)
    fi
    
    local app_name_en=""
    app_name_en=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$info_plist" 2>/dev/null)
    
    if [[ -z "$app_name_en" ]]; then
        app_name_en=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info_plist" 2>/dev/null)
    fi
    
    if [[ -z "$app_name_en" ]]; then
        print_error "アプリ名の取得に失敗しました"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    local app_name_ja=""
    local strings_path=$(unzip -l "$ipa_file" 2>/dev/null | /usr/bin/grep -E "Payload/.*\.app/ja\.lproj/InfoPlist\.strings" | head -n 1 | /usr/bin/awk '{print $NF}')
    if [[ -n "$strings_path" ]]; then
        /usr/bin/unzip -q "$ipa_file" "$strings_path" -d "$temp_dir" 2>/dev/null || true
        local ja_strings="${temp_dir}/${strings_path}"
        if [[ -f "$ja_strings" ]]; then
            app_name_ja=$(plutil -convert xml1 -o - "$ja_strings" 2>/dev/null | /usr/bin/grep -A 1 "CFBundleDisplayName" | tail -n 1 | /usr/bin/sed 's/.*<string>\(.*\)<\/string>.*/\1/' || true)
        fi
    fi
    
    if [[ -n "$app_name_ja" ]]; then
        APP_NAME="$app_name_ja"
    else
        APP_NAME="$app_name_en"
    fi
    
    APP_NAME_EN="$app_name_en"
    APP_VOLUME_NAME=$(echo "$APP_NAME_EN" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | /usr/bin/sed 's/[^a-zA-Z0-9]//g' || echo "$APP_NAME_EN" | /usr/bin/sed 's/[^a-zA-Z0-9]//g')
    
    # Fallback: If volume name is empty (e.g., Japanese-only app name), use last segment of Bundle ID
    if [[ -z "$APP_VOLUME_NAME" ]]; then
        # Extract last segment after last dot (e.g., jp.co.cygames.umamusume -> umamusume)
        local bundle_last_segment=$(echo "$APP_BUNDLE_ID" | /usr/bin/awk -F. '{print $NF}')
        APP_VOLUME_NAME=$(echo "$bundle_last_segment" | /usr/bin/sed 's/[^a-zA-Z0-9]//g')
    fi
    
    /bin/rm -rf "$temp_dir"
    
    print_info "${APP_NAME} (${APP_VERSION})"
    echo ""
    return 0
}

#######################################################
# Volume Creation and Mounting
#######################################################

find_apfs_container() {
    local physical_disk=$1
    local container=""
    
    if [[ "$physical_disk" =~ disk[0-9]+ ]]; then
        local volume_info=$(/usr/sbin/diskutil info "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null)
        container=$(echo "$volume_info" | /usr/bin/grep "APFS Container:" | /usr/bin/awk '{print $NF}')
        
        if [[ -n "$container" ]]; then
            echo "$container"
            return 0
        fi
    fi
    
    local disk_num=$(echo "$physical_disk" | /usr/bin/sed -E 's|.*/disk([0-9]+).*|\1|')
    local disk_device="/dev/disk${disk_num}"
    
    local disk_info=$(/usr/sbin/diskutil info "$disk_device" 2>/dev/null)
    if echo "$disk_info" | /usr/bin/grep -q "APFS Container Scheme"; then
        container="disk${disk_num}"
        echo "$container"
        return 0
    fi
    
    echo "$container"
}

select_installation_disk() {
    local playcover_disk=""
    
    if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
        playcover_disk=$(echo "$PLAYCOVER_VOLUME_DEVICE" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
        local container=$(find_apfs_container "${playcover_disk}")
        
        if [[ -n "$container" ]]; then
            SELECTED_DISK="$container"
        else
            print_error "APFS コンテナの検出に失敗しました"
            return 1
        fi
    else
        print_error "PlayCover ボリュームのデバイス情報が見つかりません"
        return 1
    fi
    
    return 0
}

create_app_volume_install() {
    local existing_volume=""
    existing_volume=$(get_volume_device_node "${APP_VOLUME_NAME}")
    
    if [[ -z "$existing_volume" ]]; then
        existing_volume=$(get_volume_device "${APP_VOLUME_NAME}")
    fi
    
    if [[ -n "$existing_volume" ]]; then
        return 0
    fi
    
    print_info "💾 ボリュームを作成中: ${APP_VOLUME_NAME}"
    
    if /usr/bin/sudo /usr/sbin/diskutil apfs addVolume "$SELECTED_DISK" APFS "${APP_VOLUME_NAME}" -nomount > /tmp/apfs_create_app.log 2>&1; then
        print_success "ボリュームを作成しました"
        /bin/sleep 1
        return 0
    else
        print_error "ボリュームの作成に失敗しました"
        /bin/cat /tmp/apfs_create_app.log
        return 1
    fi
}

mount_app_volume_install() {
    local target_path="${HOME}/Library/Containers/${APP_BUNDLE_ID}"
    
    # Get device path for the volume
    local device=$(get_volume_device "$APP_VOLUME_NAME")
    if [[ -z "$device" ]]; then
        print_error "デバイスの取得に失敗しました"
        return 1
    fi
    
    # Check if already mounted at the correct location
    local current_mount=$(get_volume_mount_point "$device")
    if [[ "$current_mount" == "$target_path" ]]; then
        # Already mounted correctly, no action needed
        return 0
    fi
    
    # If mounted elsewhere, unmount first
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "Not applicable (no file system)" ]]; then
        unmount_with_fallback "$device" "silent"
    fi
    
    # Mount with nobrowse option
    print_info "📌 ボリュームをマウント中..."
    
    if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
        print_success "マウント完了: $target_path"
        echo ""
        return 0
    else
        print_error "$MSG_MOUNT_FAILED"
        return 1
    fi
}

#######################################################
# IPA Installation to PlayCover
#######################################################

# Main installation function with progress tracking
# This is a complex 300+ line function that handles:
# - Existing app detection and overwrite confirmation
# - PlayCover launching and IPA opening
# - Installation progress monitoring (settings file update count)
# - Crash detection and recovery
# - Batch mode support
install_ipa_to_playcover() {
    local ipa_file=$1
    
    # Check if app is already installed
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local existing_app_path=""
    local existing_version=""
    local overwrite_choice=""
    local existing_mtime=0
    
    if [[ -d "$playcover_apps" ]]; then
        # Search for app with matching Bundle ID
        while IFS= read -r app_path; do
            if [[ -f "${app_path}/Info.plist" ]]; then
                local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                    existing_app_path="$app_path"
                    existing_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
                    # Record CURRENT modification time BEFORE installation
                    existing_mtime=$(stat -f %m "$app_path" 2>/dev/null || echo 0)
                    break
                fi
            fi
        done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
        
        # Check if existing app was found and ask for confirmation OUTSIDE the loop
        if [[ -n "$existing_app_path" ]]; then
            # Check if app is currently running
            if ! _check_app_not_running "$APP_BUNDLE_ID" "$APP_NAME" "インストール"; then
                INSTALL_FAILED+=("$APP_NAME (実行中)")
                echo ""
                return 1
            fi
            
            # Show version comparison
            echo ""
            print_warning "既存のアプリが見つかりました"
            echo ""
            echo "  ${BOLD}アプリ名:${NC} ${APP_NAME}"
            echo "  ${BOLD}インストール済みバージョン:${NC} ${YELLOW}${existing_version}${NC}"
            echo "  ${BOLD}新しいバージョン:${NC} ${GREEN}${APP_VERSION}${NC}"
            echo ""
            
            # Version comparison hint
            if [[ "$APP_VERSION" == "$existing_version" ]]; then
                print_info "💡 同じバージョンです（再インストール）"
            elif [[ "$APP_VERSION" > "$existing_version" ]]; then
                print_info "💡 アップデート: ${existing_version} → ${APP_VERSION}"
            else
                print_warning "💡 ダウングレード: ${existing_version} → ${APP_VERSION}"
            fi
            
            echo ""
            if ! prompt_confirmation "上書きインストールしますか？" "Y/n"; then
                print_info "スキップしました"
                INSTALL_SUCCESS+=("$APP_NAME (スキップ)")
                
                # Still update mapping even if skipped
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                
                echo ""
                return 0
            fi
        fi
    fi
    
    echo ""
    print_info "PlayCover でインストール中（完了まで待機）..."
    echo ""
    
    # Open IPA with PlayCover
    if ! open -a PlayCover "$ipa_file"; then
        print_error "PlayCover の起動に失敗しました"
        INSTALL_FAILED+=("$APP_NAME")
        return 1
    fi
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=2  # 2 seconds (balance between speed and CPU)
    local initial_check_done=false
    
    # PlayCover app settings path
    local app_settings_dir="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings"
    local app_settings_plist="${app_settings_dir}/${APP_BUNDLE_ID}.plist"
    
    # Track settings file updates (v5.0.0: Update count based detection)
    local settings_update_count=0
    local last_settings_mtime=0
    local initial_settings_exists=false
    
    # Check if settings file exists before installation starts
    if [[ -f "$app_settings_plist" ]]; then
        initial_settings_exists=true
        last_settings_mtime=$(stat -f %m "$app_settings_plist" 2>/dev/null || echo 0)
    fi
    
    # Detection Method (v5.0.1 - File Stability Check):
    # Improved approach that balances speed and accuracy:
    # 
    # BOTH NEW and OVERWRITE INSTALL:
    #   1. Wait for settings file 2nd update (basic completion signal)
    #   2. Then verify file stability (no changes for N seconds)
    #   3. Optionally check if PlayCover is still accessing the file
    # 
    # Reasoning:
    #   - 2nd update indicates PlayCover finished main processing
    #   - Stability check prevents false positives with large IPAs
    #   - Small IPAs: Quick 2nd update + short stability check
    #   - Large IPAs: Wait for genuine completion + stability
    # 
    # Parameters:
    #   - check_interval: 2 seconds (balance between speed and CPU)
    #   - stability_threshold: 4 seconds of no changes = stable
    
    local stability_threshold=4  # File must be stable for 4 seconds
    local last_stable_mtime=0
    local stable_duration=0
    local first_update_time=0  # Track when first update occurred
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Check if PlayCover is still running BEFORE sleep (v4.8.1 - immediate crash detection)
        if ! pgrep -x "PlayCover" > /dev/null; then
            echo ""
            echo ""
            print_error "PlayCover が終了しました"
            print_warning "インストール中にクラッシュした可能性があります"
            echo ""
            
            # Check if installation actually succeeded despite crash (using robust verification)
            local installation_succeeded=false
            if [[ -d "$playcover_apps" ]]; then
                while IFS= read -r app_path; do
                    if [[ -f "${app_path}/Info.plist" ]]; then
                        local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                        if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                            local current_mtime=$(stat -f %m "$app_path" 2>/dev/null || echo 0)
                            if [[ $current_mtime -gt $existing_mtime ]]; then
                                # Verify structure integrity
                                if [[ -d "${app_path}/_CodeSignature" ]]; then
                                    local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                                    if [[ -n "$app_name" ]]; then
                                        # v4.9.0: Simple check - settings file exists and is stable
                                        if [[ -f "$app_settings_plist" ]]; then
                                            installation_succeeded=true
                                            break
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
            fi
            
            if [[ "$installation_succeeded" == true ]]; then
                print_info "ただし、アプリのインストールは完了していました"
                print_success "インストール成功"
                INSTALL_SUCCESS+=("$APP_NAME")
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                echo ""
                
                # Restart PlayCover for next installation if in batch mode
                if [[ $BATCH_MODE == true ]] && [[ $CURRENT_IPA_INDEX -lt $TOTAL_IPAS ]]; then
                    print_info "次のインストールのため PlayCover を準備中..."
                    /bin/sleep 2
                fi
                
                return 0
            else
                print_error "インストールは完了していませんでした"
                INSTALL_FAILED+=("$APP_NAME (PlayCoverクラッシュ)")
                echo ""
                
                # In batch mode, offer to continue automatically
                if [[ $BATCH_MODE == true ]] && [[ $CURRENT_IPA_INDEX -lt $TOTAL_IPAS ]]; then
                    print_warning "残り $((TOTAL_IPAS - CURRENT_IPA_INDEX)) 個のIPAがあります"
                    echo ""
                    echo -n "次のIPAに進みますか？ (Y/n): "
                    read continue_choice </dev/tty
                    
                    if [[ "$continue_choice" =~ ^[Nn]$ ]]; then
                        return 1
                    else
                        print_info "次のインストールのため PlayCover を準備中..."
                        /bin/sleep 2
                        return 0
                    fi
                else
                    return 1
                fi
            fi
        fi
        
        # Check if app was installed
        if [[ -d "$playcover_apps" ]]; then
            local found=false
            local current_app_mtime=0
            
            while IFS= read -r app_path; do
                if [[ -f "${app_path}/Info.plist" ]]; then
                    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                    
                    if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                        # Phase 1: Basic structure validation
                        local structure_valid=false
                        
                        # Check Info.plist validity
                        if [[ -f "${app_path}/Info.plist" ]]; then
                            local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                            local app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
                            
                            # Check _CodeSignature directory
                            if [[ -d "${app_path}/_CodeSignature" ]] && [[ -n "$app_name" ]] && [[ -n "$app_version" ]]; then
                                structure_valid=true
                            fi
                        fi
                        
                        if [[ "$structure_valid" == false ]]; then
                            continue
                        fi
                        
                        # Phase 2: Settings file update count check (v5.0.0)
                        if [[ -f "$app_settings_plist" ]]; then
                            local current_settings_mtime=$(stat -f %m "$app_settings_plist" 2>/dev/null || echo 0)
                            
                            if [[ $current_settings_mtime -gt 0 ]]; then
                                # Check if settings file was updated
                                if [[ $current_settings_mtime -ne $last_settings_mtime ]]; then
                                    # Settings file was updated!
                                    ((settings_update_count++))
                                    last_settings_mtime=$current_settings_mtime
                                    
                                    # v5.0.2: Track first update time for single-update detection
                                    if [[ $settings_update_count -eq 1 ]]; then
                                        first_update_time=$elapsed
                                    fi
                                fi
                                
                                # v5.0.2: Two-phase detection with stability check + single-update fallback
                                if [[ "$structure_valid" == true ]]; then
                                    # Phase 1: Wait for 2nd update (normal completion signal)
                                    if [[ $settings_update_count -ge 2 ]]; then
                                        # Phase 2: Verify file stability
                                        if [[ $current_settings_mtime -eq $last_stable_mtime ]]; then
                                            # mtime unchanged - accumulate stable duration
                                            stable_duration=$((stable_duration + check_interval))
                                            
                                            # If stable for threshold duration, check if PlayCover is done
                                            if [[ $stable_duration -ge $stability_threshold ]]; then
                                                # Optional: Verify PlayCover is not actively writing
                                                if lsof "$app_settings_plist" 2>/dev/null | grep -q "PlayCover"; then
                                                    # PlayCover still accessing file - reset and continue
                                                    stable_duration=0
                                                else
                                                    # File is stable AND PlayCover is not writing - complete!
                                                    found=true
                                                    break
                                                fi
                                            fi
                                        else
                                            # mtime changed - reset stability counter
                                            last_stable_mtime=$current_settings_mtime
                                            stable_duration=0
                                        fi
                                    # Phase 1b: Single-update fallback (for very small apps)
                                    elif [[ $settings_update_count -eq 1 ]] && [[ $first_update_time -gt 0 ]]; then
                                        local time_since_first_update=$((elapsed - first_update_time))
                                        # If 8 seconds passed since first update with no 2nd update
                                        if [[ $time_since_first_update -ge 8 ]]; then
                                            # Verify file stability for single-update pattern
                                            if [[ $current_settings_mtime -eq $last_stable_mtime ]]; then
                                                stable_duration=$((stable_duration + check_interval))
                                                
                                                if [[ $stable_duration -ge $stability_threshold ]]; then
                                                    # Single-update pattern confirmed - complete!
                                                    found=true
                                                    break
                                                fi
                                            else
                                                last_stable_mtime=$current_settings_mtime
                                                stable_duration=0
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
            
            if [[ "$found" == true ]]; then
                # v4.8.1: Final verification - ensure PlayCover is still running
                if ! pgrep -x "PlayCover" > /dev/null; then
                    echo ""
                    echo ""
                    print_warning "完了判定直後に PlayCover が終了しました"
                    print_info "最終確認を実施中..."
                    /bin/sleep 2
                    
                    # Re-verify the installation is truly complete
                    if [[ -f "${app_path}/Info.plist" ]] && [[ -f "$app_settings_plist" ]]; then
                        echo ""
                        print_success "インストールは正常に完了していました"
                    else
                        echo ""
                        print_error "インストールが不完全です"
                        INSTALL_FAILED+=("$APP_NAME (完了直後にPlayCoverクラッシュ)")
                        return 1
                    fi
                fi
                
                echo ""
                print_success "インストールが完了しました"
                INSTALL_SUCCESS+=("$APP_NAME")
                
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                
                echo ""
                return 0
            fi
        fi
        
        initial_check_done=true
        
        /bin/sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        # Show progress indicator with detailed status (v5.0.1 - Stability Check)
        if [[ $settings_update_count -ge 2 ]] && [[ $stable_duration -gt 0 ]]; then
            echo -n "⏳"  # 2nd update detected, verifying stability
        elif [[ $settings_update_count -ge 2 ]]; then
            echo -n "◇"  # 2nd update detected (starting stability check)
        elif [[ $settings_update_count -eq 1 ]]; then
            echo -n "◆"  # 1st update (waiting for 2nd)
        elif [[ $last_settings_mtime -gt 0 ]]; then
            echo -n "◇"  # Settings file exists but not updated yet
        else
            echo -n "."  # Waiting for 1st update
        fi
    done
    
    echo ""
    echo ""
    print_warning "インストール完了の自動検知がタイムアウトしました"
    echo ""
    echo -n "PlayCover でインストールが完了したら Enter キーを押してください: "
    read </dev/tty
    
    # Final verification
    if [[ -d "$playcover_apps" ]]; then
        while IFS= read -r app_path; do
            if [[ -f "${app_path}/Info.plist" ]]; then
                local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                    print_success "インストールが確認されました"
                    INSTALL_SUCCESS+=("$APP_NAME")
                    
                    update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                    
                    echo ""
                    return 0
                fi
            fi
        done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
    fi
    
    print_error "インストールが確認できませんでした"
    INSTALL_FAILED+=("$APP_NAME")
    echo ""
    return 1
}

#######################################################
# Install Workflow
#######################################################

# Complete IPA installation workflow
# Handles multiple IPAs, batch mode, volume creation, and installation
install_workflow() {
    clear
    
    # Reset global arrays at the start of workflow
    SELECTED_IPAS=()
    INSTALL_SUCCESS=()
    INSTALL_FAILED=()
    BATCH_MODE=false
    CURRENT_IPA_INDEX=0
    TOTAL_IPAS=0
    
    check_playcover_app
    ensure_mapping_file
    check_full_disk_access
    authenticate_sudo
    check_playcover_volume_mount_install
    
    select_ipa_files || return
    
    CURRENT_IPA_INDEX=0
    for ipa_file in "${(@)SELECTED_IPAS}"; do
        ((CURRENT_IPA_INDEX++))
        
        if [[ $BATCH_MODE == true ]]; then
            print_batch_progress "$CURRENT_IPA_INDEX" "$TOTAL_IPAS" "$(basename "$ipa_file")"
        fi
        
        extract_ipa_info "$ipa_file" || continue
        select_installation_disk || continue
        create_app_volume_install || continue
        mount_app_volume_install || continue
        install_ipa_to_playcover "$ipa_file" || continue
    done
    
    _show_install_summary "インストール"
}

#######################################################
# Uninstall Workflow
#######################################################

# Interactive app uninstallation workflow
# Allows individual or batch uninstallation
uninstall_workflow() {
    # Loop until user cancels or no more apps
    while true; do
        clear
        print_header "アプリのアンインストール"
        
        # Check mapping file
        if [[ ! -f "$MAPPING_FILE" ]]; then
            print_error "マッピングファイルが見つかりません"
            echo ""
            echo "まだアプリがインストールされていません。"
            wait_for_enter
            return
        fi
        
        local mappings_content=$(read_mappings)
        
        if [[ -z "$mappings_content" ]]; then
            print_success "すべてのアプリがアンインストールされました"
            echo ""
            echo "インストールされているアプリ: 0個"
            echo ""
            echo -n "Enterキーでメニューに戻る..."
            read
            return
        fi
    
    # Display installed apps using shared function
    echo ""
    show_installed_apps "false"
    local total_apps=$?
    
    if [[ $total_apps -eq 0 ]]; then
        print_warning "インストールされているアプリがありません"
        wait_for_enter
        return
    fi
    
    # Show uninstall options
    echo ""
    print_separator "$SEPARATOR_CHAR" "$CYAN"
    echo ""
    echo "${ORANGE}▼ アンインストール方法を選択${NC}"
    echo ""
    echo "  ${GREEN}個別削除${NC}: 1-${total_apps} の番号を入力"
    echo "  ${RED}一括削除${NC}: ${RED}ALL${NC} を入力（すべてのアプリを一度に削除）"
    echo "  ${CYAN}キャンセル${NC}: 0 を入力"
    echo ""
    echo "${DIM_GRAY}※ Enterキーのみ: 状態を再取得${NC}"
    echo ""
    echo -n "${ORANGE}選択:${NC} "
    read app_choice
    
    # Empty Enter - refresh cache and redisplay menu
    if [[ -z "$app_choice" ]]; then
        refresh_all_volume_caches
        continue
    fi
    
    # Check for batch uninstall
    if [[ "$app_choice" == "ALL" ]] || [[ "$app_choice" == "all" ]]; then
        # Call batch uninstall function
        uninstall_all_apps
        return
    fi
    
    # Validate input for individual uninstall
    if [[ ! "$app_choice" =~ ^[0-9]+$ ]] || [[ $app_choice -lt 0 ]] || [[ $app_choice -gt $total_apps ]]; then
        print_error "$MSG_INVALID_SELECTION"
        wait_for_enter
        continue
    fi
    
    if [[ $app_choice -eq 0 ]]; then
        return
    fi
    
    # Get selected app info (zsh arrays are 1-indexed)
    local selected_app="${apps_list[$app_choice]}"
    local selected_volume="${volumes_list[$app_choice]}"
    local selected_bundle="${bundles_list[$app_choice]}"
    
    # Check if trying to delete PlayCover volume with other apps remaining
    if [[ "$selected_volume" == "PlayCover" ]] && [[ $total_apps -gt 1 ]]; then
        echo ""
        print_error "PlayCoverボリュームは削除できません"
        echo ""
        echo "理由: 他のアプリがまだインストールされています"
        echo ""
        echo "PlayCoverボリュームを削除するには："
        echo "  1. 他のすべてのアプリを先にアンインストール"
        echo "  2. PlayCoverボリュームが最後に残った状態にする"
        echo "  3. その後、PlayCoverボリュームをアンインストール"
        echo ""
        echo "現在インストール済み: ${total_apps} 個のアプリ"
        wait_for_enter
        continue
    fi
    
    _show_uninstall_warning "$selected_app" "$selected_bundle" "$selected_volume"
    
    # Check if app is currently running before uninstall
    if ! _check_app_not_running "$selected_bundle" "$selected_app" "アンインストール"; then
        echo ""
        print_info "アプリを終了してから再度お試しください"
        wait_for_enter
        return
    fi
    
    if ! prompt_confirmation "本当にアンインストールしますか？" "yes/NO"; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    # Re-check if app was started during confirmation (race condition prevention)
    if is_app_running "$selected_bundle"; then
        echo ""
        print_error "確認中にアプリが起動されました"
        echo ""
        print_info "アプリを終了してから再度お試しください"
        wait_for_enter
        return
    fi
    
    # Authenticate sudo before volume operations
    authenticate_sudo
    
    # Start uninstallation
    echo ""
    print_info "${selected_app} を削除中..."
    echo ""
    
    # Step 1: Remove app from PlayCover Applications/
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local app_path="${playcover_apps}/${selected_bundle}.app"
    
    if [[ -d "$app_path" ]]; then
        if ! /bin/rm -rf "$app_path" 2>/dev/null; then
            handle_error_and_return "アプリの削除に失敗しました"
        fi
    fi
    
    # Step 2-5: Remove settings, entitlements, keymapping, containers (silent)
    local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${selected_bundle}.plist"
    /bin/rm -f "$app_settings" 2>/dev/null
    
    local entitlements_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements/${selected_bundle}.plist"
    /bin/rm -f "$entitlements_file" 2>/dev/null
    
    local keymapping_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping/${selected_bundle}.plist"
    /bin/rm -f "$keymapping_file" 2>/dev/null
    
    local containers_dir="${HOME}/Library/Containers/${selected_bundle}"
    # Remove internal storage flag if exists before deleting container
    if [[ -f "${containers_dir}/${INTERNAL_STORAGE_FLAG}" ]]; then
        /bin/rm -f "${containers_dir}/${INTERNAL_STORAGE_FLAG}" 2>/dev/null
    fi
    /bin/rm -rf "$containers_dir" 2>/dev/null
    
    # Step 7: Unmount volume if mounted (silent)
    local volume_mount_point="${PLAYCOVER_CONTAINER}/${selected_volume}"
    if /sbin/mount | grep -q "$volume_mount_point"; then
        unmount_volume "$volume_mount_point" "silent"
    fi
    
    # Step 8: Delete APFS volume
    local volume_device=$(get_volume_device "$selected_volume")
    
    if [[ -n "$volume_device" ]]; then
        if ! /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
            print_error "ボリュームの削除に失敗しました"
            echo ""
            echo "手動で削除してください: /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume $volume_device"
            wait_for_enter
            return
        fi
    fi
    
    # Step 9: Remove from mapping file (includes last_launched data)
    if ! remove_mapping "$selected_bundle"; then
        handle_error_and_return "マッピング情報の削除に失敗しました"
    fi
    
    # Step 10: If PlayCover volume, remove PlayCover.app and exit
    if [[ "$selected_volume" == "PlayCover" ]]; then
        echo ""
        local playcover_app="/Applications/PlayCover.app"
        if [[ -d "$playcover_app" ]]; then
            /bin/rm -rf "$playcover_app" 2>/dev/null
        fi
        
        print_success "PlayCover を完全にアンインストールしました"
        echo ""
        print_warning "PlayCoverが削除された為、このスクリプトは使用できません。"
        echo ""
        echo -n "Enterキーでターミナルを終了します..."
        read
        exit 0
    fi
    
    echo ""
    print_success "${selected_app} のアンインストールが完了しました"
    echo ""
    wait_for_enter
    done
}

# Batch uninstall all apps (called from uninstall_workflow)
uninstall_all_apps() {
    clear
    print_header "全アプリ一括アンインストール"
    
    # Check mapping file
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_error "マッピングファイルが見つかりません"
        echo ""
        echo "まだアプリがインストールされていません。"
        wait_for_enter
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "インストールされているアプリがありません"
        wait_for_enter
        return
    fi
    
    # Count total apps
    local total_apps=$(echo "$mappings_content" | wc -l | tr -d ' ')
    
    # Display all installed apps
    echo ""
    echo "以下のアプリをすべて削除します:"
    echo ""
    
    local -a apps_list=()
    local -a volumes_list=()
    local -a bundles_list=()
    local index=1
    
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        apps_list+=("$display_name")
        volumes_list+=("$volume_name")
        bundles_list+=("$bundle_id")
        echo "  ${CYAN}${index}.${NC} ${GREEN}${display_name}${NC}"
        echo "      Bundle ID: ${bundle_id}"
        echo "      ボリューム: ${volume_name}"
        echo ""
        ((index++))
    done <<< "$mappings_content"
    
    echo "${ORANGE}合計: ${total_apps} 個のアプリ${NC}"
    echo ""
    
    # Check if any apps are currently running
    echo "アプリの実行状態をチェック中..."
    echo ""
    local running_apps=()
    for ((i=1; i<=${#bundles_list}; i++)); do
        if is_app_running "${bundles_list[$i]}"; then
            running_apps+=("${apps_list[$i]}")
        fi
    done
    
    if [[ ${(@)#running_apps} -gt 0 ]]; then
        print_error "以下のアプリが実行中のため、アンインストールできません:"
        echo ""
        for app in "${(@)running_apps}"; do
            echo "  🏃 ${app}"
        done
        echo ""
        print_info "すべてのアプリを終了してから再度お試しください"
        wait_for_enter
        return
    fi
    
    print_warning "この操作は以下を実行します:"
    echo "  1. すべてのアプリを PlayCover から削除"
    echo "  2. すべての設定ファイルを削除"
    echo "  3. すべての Entitlements を削除"
    echo "  4. すべての Keymapping を削除"
    echo "  5. すべての Containersフォルダを削除"
    echo "  6. すべての APFSボリュームをアンマウント・削除"
    echo "  7. すべてのマッピング情報を削除"
    echo ""
    print_error "この操作は取り消せません！"
    print_error "PlayCoverを含むすべてのアプリが削除されます！"
    echo ""
    if ! prompt_confirmation "本当にすべてのアプリをアンインストールしますか？" "yes/NO"; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    # Re-check if any apps were started during confirmation (race condition prevention)
    for ((i=1; i<=${#bundles_list}; i++)); do
        if is_app_running "${bundles_list[$i]}"; then
            echo ""
            print_error "確認中に ${apps_list[$i]} が起動されました"
            echo ""
            print_info "すべてのアプリを終了してから再度お試しください"
            wait_for_enter
            return
        fi
    done
    
    # Start batch uninstallation
    echo ""
    
    local success_count=0
    local fail_count=0
    
    # Cache diskutil list for performance (single call for all apps)
    local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    
    # Loop through all apps (1-indexed zsh arrays)
    for ((i=1; i<=${#apps_list}; i++)); do
        local app_name="${apps_list[$i]}"
        local volume_name="${volumes_list[$i]}"
        local bundle_id="${bundles_list[$i]}"
        
        # Step 1: Remove app from PlayCover
        local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
        local app_path="${playcover_apps}/${bundle_id}.app"
        
        if [[ -d "$app_path" ]]; then
            /bin/rm -rf "$app_path" 2>/dev/null
        fi
        
        # Step 2-5: Remove settings, entitlements, keymapping, containers
        local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${bundle_id}.plist"
        [[ -f "$app_settings" ]] && /bin/rm -f "$app_settings" 2>/dev/null
        
        local entitlements_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements/${bundle_id}.plist"
        [[ -f "$entitlements_file" ]] && /bin/rm -f "$entitlements_file" 2>/dev/null
        
        local keymapping_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping/${bundle_id}.plist"
        [[ -f "$keymapping_file" ]] && /bin/rm -f "$keymapping_file" 2>/dev/null
        
        local containers_dir="${HOME}/Library/Containers/${bundle_id}"
        [[ -d "$containers_dir" ]] && /bin/rm -rf "$containers_dir" 2>/dev/null
        
        # Step 6: Unmount and delete APFS volume
        local volume_mount_point="${PLAYCOVER_CONTAINER}/${volume_name}"
        if /sbin/mount | grep -q "$volume_mount_point"; then
            unmount_volume "$volume_mount_point" "silent"
        fi
        
        # Find and delete volume (use cached diskutil output)
        local volume_device=$(get_volume_device "$volume_name" "$diskutil_cache")
        if [[ -n "$volume_device" ]]; then
            if /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
                print_success "${app_name}"
                ((success_count++))
            else
                print_error "${app_name} (ボリューム削除失敗)"
                ((fail_count++))
            fi
        else
            print_success "${app_name}"
            ((success_count++))
        fi
    done
    
    # Step 7: Clear entire mapping file (silent)
    echo ""
    if acquire_mapping_lock; then
        > "$MAPPING_FILE"
        release_mapping_lock
    fi
    
    # Step 8: Remove PlayCover.app (silent)
    local playcover_app="/Applications/PlayCover.app"
    /bin/rm -rf "$playcover_app" 2>/dev/null
    
    # Summary
    echo ""
    print_separator
    echo ""
    print_success "PlayCover と全アプリを完全削除しました (${success_count} 個)"
    if [[ $fail_count -gt 0 ]]; then
        echo "  ${RED}失敗: ${fail_count} 個${NC}"
    fi
    echo ""
    print_warning "PlayCoverが削除された為、このスクリプトは使用できません。"
    echo ""
    /bin/sleep 2
    /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
}

#######################################################
# Quick Launcher Functions
#######################################################

# Get bundle ID from .app bundle's Info.plist
# Args: app_path
# Output: bundle_id
# Returns: 0 if found, 1 if not found
get_bundle_id_from_app() {
    local app_path=$1
    local info_plist="${app_path}/Info.plist"
    
    if [[ ! -f "$info_plist" ]]; then
        return 1
    fi
    
    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)
    
    if [[ -n "$bundle_id" ]]; then
        echo "$bundle_id"
        return 0
    else
        return 1
    fi
}

# Get container path for bundle ID
# Args: bundle_id
# Output: container_path
get_container_path() {
    local bundle_id=$1
    echo "${HOME}/Library/Containers/${bundle_id}"
}

# Get volume name from bundle ID (from mapping file)
# Args: bundle_id
# Output: volume_name
# Returns: 0 if found, 1 if not found
get_volume_name_from_bundle_id() {
    local bundle_id=$1
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    local volume_name=""
    while IFS=$'\t' read -r vol_name stored_bundle_id display_name recent_flag; do
        if [[ "$stored_bundle_id" == "$bundle_id" ]]; then
            volume_name=$vol_name
            break
        fi
    done < "$MAPPING_FILE"
    
    if [[ -n "$volume_name" ]]; then
        echo "$volume_name"
        return 0
    else
        return 1
    fi
}

# Get list of launchable apps (apps with .app files in PlayCover)
# Output: app_name|bundle_id|app_path (one per line)
# Returns: 0 if apps found, 1 if no apps
get_launchable_apps() {
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    
    if [[ ! -d "$playcover_apps" ]]; then
        return 1
    fi
    
    local app_count=0
    
    while IFS= read -r app_path; do
        local app_name=$(basename "$app_path" .app)
        local bundle_id=$(get_bundle_id_from_app "$app_path")
        
        if [[ -z "$bundle_id" ]]; then
            continue
        fi
        
        # Only include apps that have mapping (external) or intentional internal mode
        local volume_name=$(get_volume_name_from_bundle_id "$bundle_id")
        local container_path=$(get_container_path "$bundle_id")
        
        # Check if app has external mapping
        if [[ -n "$volume_name" ]]; then
            # Check if volume physically exists (connected to Mac) - use cached version
            if ! volume_exists_cached "$volume_name"; then
                # Volume not connected - cannot launch
                continue
            fi
            
            # External storage - check if contaminated
            local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
            
            # Exclude contaminated apps (cannot launch without resolving)
            if [[ "$storage_mode" == "internal_contaminated" ]]; then
                continue
            fi
            
            # Include all other external storage states
            echo "${app_name}|${bundle_id}|${app_path}"
            ((app_count++))
            continue
        fi
        
        # No external mapping - check for internal intentional mode
        if [[ -f "${container_path}/.internal_storage" ]]; then
            # Internal intentional mode - include
            echo "${app_name}|${bundle_id}|${app_path}"
            ((app_count++))
            continue
        fi
        
        # No mapping and no internal flag - skip this app
    done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
    
    if [[ $app_count -eq 0 ]]; then
        return 1
    fi
    
    return 0
}

# Check if app is registered as external storage in mapping file
# Args: bundle_id
# Returns: 0 if registered as external, 1 if not
is_app_registered_as_external() {
    local bundle_id=$1
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    local volume_name=$(get_volume_name_from_bundle_id "$bundle_id")
    
    if [[ -n "$volume_name" ]]; then
        return 0  # External storage registered
    else
        return 1  # Not registered (internal)
    fi
}

# Check if sudo is required for app launch
# Args: bundle_id, storage_mode
# Returns: 0 if sudo needed, 1 if not needed
needs_sudo_for_launch() {
    local bundle_id=$1
    local storage_mode=$2
    
    # Internal mode never needs sudo
    if [[ "$storage_mode" == "internal_intentional"* ]]; then
        return 1  # No sudo needed
    fi
    
    # External mode with correct mount doesn't need sudo
    if [[ "$storage_mode" == "external" ]]; then
        local container_path=$(get_container_path "$bundle_id")
        if [[ -e "$container_path" ]]; then
            return 1  # No sudo needed
        fi
    fi
    
    # Otherwise (unmounted, wrong location), sudo is needed
    return 0  # Sudo needed
}

# Launch app with appropriate storage mounting
# Args: app_path, app_name, bundle_id, storage_mode
# Returns: 0 on success, 1 on failure
launch_app() {
    local app_path=$1
    local app_name=$2
    local bundle_id=$3
    local storage_mode=$4
    
    local container_path=$(get_container_path "$bundle_id")
    local volume_name=$(get_volume_name_from_bundle_id "$bundle_id")
    
    # Determine if sudo is needed
    local needs_sudo=false
    if needs_sudo_for_launch "$bundle_id" "$storage_mode"; then
        needs_sudo=true
    fi
    
    # Handle intentional internal storage mode FIRST
    # CRITICAL: Internal mode should NEVER mount external volume
    if [[ "$storage_mode" == "internal_intentional"* ]]; then
        if [[ ! -e "$container_path" ]]; then
            print_error "内蔵コンテナパスが見つかりません"
            return 1
        fi
        # Skip to launch (don't try to mount external volume)
    # Handle external storage mode
    elif [[ "$storage_mode" == "external"* ]] || is_app_registered_as_external "$bundle_id"; then
        # Get volume mount status in one call
        local current_mount=$(validate_and_get_mount_point "$volume_name")
        local vol_status=$?
        
        if [[ $vol_status -eq 1 ]]; then
            print_error "外部ボリュームが見つかりません"
            print_info "ボリューム名: $volume_name"
            print_warning "外部ストレージを接続してから再度実行してください"
            return 1
        fi
        
        # Handle wrong location (需要再挂载)
        if [[ "$storage_mode" == "external_wrong_location" ]]; then
            print_info "${app_name}のボリュームを再マウント中..."
            
            if [[ "$needs_sudo" == true ]]; then
                print_info "管理者権限が必要です"
                sudo -v || {
                    print_error "管理者権限の取得に失敗しました"
                    return 1
                }
            fi
            
            if ! unmount_with_fallback "$current_mount" "silent"; then
                print_error "既存マウントの解除に失敗しました"
                return 1
            fi
            sleep 1
            # Clear mount cache after unmount
            current_mount=""
            vol_status=2
        fi
        
        # Handle unmounted volume (status 2 = exists but not mounted)
        if [[ $vol_status -eq 2 ]] || [[ -z "$current_mount" ]]; then
            print_info "${app_name}のボリュームをマウント中..."
            
            if [[ "$needs_sudo" == true ]]; then
                print_info "管理者権限が必要です"
                sudo -v || {
                    print_error "管理者権限の取得に失敗しました"
                    return 1
                }
            fi
            
            if ! mount_app_volume "$volume_name" "$container_path" "$bundle_id"; then
                print_error "マウントに失敗しました"
                return 1
            fi
        fi
        
        # Verify mount success
        if [[ ! -e "$container_path" ]]; then
            print_error "コンテナパスが見つかりません"
            print_info "パス: $container_path"
            return 1
        fi
        
        # Warning if internal data also exists (not critical)
        local internal_path="/Users/$(whoami)/Library/Containers/${bundle_id}"
        if [[ -e "$internal_path" ]] && [[ "$container_path" != "$internal_path" ]]; then
            print_warning "⚠️ 内蔵側にもデータが存在します（現在使用: 外部ストレージ）"
        fi
    fi
    
    # Launch the app
    echo ""
    print_info "${app_name}を起動しています..."
    
    # Use open -a to launch the app properly
    open -a "$app_path"
    
    if [[ $? -eq 0 ]]; then
        print_success "起動しました"
        
        # Record as recently used
        record_recent_app "$bundle_id"
        
        return 0
    else
        print_error "起動に失敗しました"
        return 1
    fi
}

# Open PlayCover application for settings
# Returns: 0 on success, 1 on failure
open_playcover_settings() {
    print_info "PlayCoverを起動しています..."
    
    open -a PlayCover
    
    if [[ $? -eq 0 ]]; then
        echo ""
        print_success "PlayCoverを起動しました"
        print_info "アプリ設定を変更できます："
        echo "  • キーマッピング"
        echo "  • 解像度・画質設定"
        echo "  • その他PlayCover設定"
        echo ""
        print_warning "設定変更後、このツールから再度アプリを起動してください"
        return 0
    else
        print_error "PlayCoverの起動に失敗しました"
        return 1
    fi
}

