#!/bin/bash

LOGIN_REDIRECT_URL=""
REGISTER_REDIRECT_URL=""
NEW_CONTACT_URL=""
OLD_URL_TARGET=""
NEW_URL_VALUE=""

# ปรับ getopts ให้รับ -O และ -N
while getopts "L:R:C:O:N:" opt; do
  case $opt in
    L) LOGIN_REDIRECT_URL="$OPTARG" ;; # รันค่า URL ของ Page login
    R) REGISTER_REDIRECT_URL="$OPTARG" ;; # รับค่า URL ของ Register
    C) NEW_CONTACT_URL="$OPTARG" ;; # รับค่า URL ของ Contact
    O) OLD_URL_TARGET="$OPTARG" ;; # รับค่า URL เดิม
    N) NEW_URL_VALUE="$OPTARG"  ;; # รับค่า URL ใหม่
    \?) exit 1 ;;
  esac
done

# เช็ค Argument
if [ -z "$LOGIN_REDIRECT_URL" ] && [ -z "$REGISTER_REDIRECT_URL" ] && [ -z "$NEW_CONTACT_URL" ] && [ -z "$OLD_URL_TARGET" ]; then
    echo "Usage: $0 [-L URL] [-R URL] [-C URL] [-O old_url -N new_url]"
    exit 1
fi

BASE_DIR="$HOME/applications"
LOG_FILE="$HOME/update_wp.log"

> "$LOG_FILE"
echo "------ Update started at $(date) ------" >> "$LOG_FILE"

ALL_SITES_LIST=$(find -L "$BASE_DIR" -name "wp-config.php" ! -path "*/.*")
TOTAL_SITES=$(echo "$ALL_SITES_LIST" | grep -c "wp-config.php")

if [ "$TOTAL_SITES" -eq 0 ]; then
    echo "Error: No WordPress installations found." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Found $TOTAL_SITES WordPress installations. Starting process..." | tee -a "$LOG_FILE"

SUCCESS_COUNT=0
FAILED_COUNT=0
CURRENT_INDEX=0

while read -r config_path; do
    [ -z "$config_path" ] && continue
    
    ((CURRENT_INDEX++))
    SITE_PATH=$(dirname "$config_path")
    DISPLAY_NAME=$(echo "$SITE_PATH" | sed "s|$BASE_DIR/||")
    
    (
        cd "$SITE_PATH" || { exit 1; }
        
        DOMAIN=$(wp option get home --allow-root 2>/dev/null || echo "Unknown Domain")
        echo "------------------------------------------------" | tee -a "$LOG_FILE"
        echo "[$CURRENT_INDEX/$TOTAL_SITES] Site: $DOMAIN ($DISPLAY_NAME)" | tee -a "$LOG_FILE"

        # --- ฟังก์ชัน (Page Content) ---
        update_page_link() {
            local slug=$1; local new_url=$2; local label=$3
            local page_id=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep -E ",($slug|-2|,($slug))" | cut -d',' -f1 | head -n 1)
            if [ -n "$page_id" ]; then
                local old_content=$(wp post get "$page_id" --field=post_content --allow-root)
                if echo "$old_content" | grep -q "<a href="; then
                    local new_content=$(echo "$old_content" | sed -E "s|<a href=\"[^\"]*\"|<a href=\"$new_url\"|g")
                    wp post update "$page_id" --post_content="$new_content" --allow-root >> "$LOG_FILE" 2>&1
                    echo "    [OK] Page: $label ($slug) updated" | tee -a "$LOG_FILE"
                    return 0
                fi
            fi
            return 0
        }

        # --- ฟังก์ชันที่ปรับปรุง (wp_options) ---
        update_option_url() {
            local old_url=$1
            local new_url=$2
            
            if [ -n "$old_url" ] && [ -n "$new_url" ]; then
                echo "    [DB] Searching for '$old_url' and replacing with '$new_url' in wp_options..." | tee -a "$LOG_FILE"
                wp search-replace "$old_url" "$new_url" wp_options --allow-root >> "$LOG_FILE" 2>&1
                echo "    [OK] Database wp_options updated" | tee -a "$LOG_FILE"
            fi
        }

        IS_ERR=0
        [ -n "$LOGIN_REDIRECT_URL" ] && update_page_link "login" "$LOGIN_REDIRECT_URL" "Login"
        [ -n "$REGISTER_REDIRECT_URL" ] && update_page_link "register" "$REGISTER_REDIRECT_URL" "Register"
        [ -n "$NEW_CONTACT_URL" ] && update_page_link "contact-us" "$NEW_CONTACT_URL" "Contact"
        [ -n "$OLD_URL_TARGET" ] && update_option_url "$OLD_URL_TARGET" "$NEW_URL_VALUE"
        
        wp cache flush --allow-root &>/dev/null
        exit $IS_ERR
    )

    if [ $? -eq 0 ]; then ((SUCCESS_COUNT++)); else ((FAILED_COUNT++)); fi

done <<< "$ALL_SITES_LIST"

echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "Summary: Success $SUCCESS_COUNT | Failed $FAILED_COUNT" | tee -a "$LOG_FILE"
echo "Log: $LOG_FILE"
