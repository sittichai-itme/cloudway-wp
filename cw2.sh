#!/bin/bash

LOGIN_REDIRECT_URL=""
REGISTER_REDIRECT_URL=""
NEW_CONTACT_URL=""
NEW_OPTION_URL=""  # สำหรับฟังก์ชัน -O

while getopts "L:R:C:O:" opt; do
  case $opt in
    L) LOGIN_REDIRECT_URL="$OPTARG" ;;
    R) REGISTER_REDIRECT_URL="$OPTARG" ;;
    C) NEW_CONTACT_URL="$OPTARG" ;;
    O) NEW_OPTION_URL="$OPTARG" ;;
    \?) exit 1 ;;
  esac
done

if [ -z "$LOGIN_REDIRECT_URL" ] && [ -z "$REGISTER_REDIRECT_URL" ] && [ -z "$NEW_CONTACT_URL" ] && [ -z "$NEW_OPTION_URL" ]; then
    echo "Usage: $0 [-L URL] [-R URL] [-C URL] [-O URL]"
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

        # --- ฟังก์ชันเดิม (แก้ใน Page Content) ---
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
            return 0 # ไม่นับเป็น Error ร้ายแรงถ้าหาไม่เจอ
        }

        # --- ฟังก์ชันใหม่ (แก้ใน wp_options) ---
        update_option_url() {
            local new_url=$2
            # ค้นหา Domain เก่าที่อยู่ในระบบก่อน (เฉพาะใน wp_options)
            local old_domain=$(wp option get home --allow-root 2>/dev/null | sed -E 's|https?://||;s|/.*||')
            
            if [ -n "$old_domain" ] && [ -n "$new_url" ]; then
                # ใช้ search-replace เพื่อแก้ Serialized Data ใน wp_options
                # โดยจะหา URL เดิมของเว็บนั้นๆ แล้วแทนที่ด้วย URL ใหม่ที่ระบุมา
                echo "    [DB] Searching for old links in wp_options..." | tee -a "$LOG_FILE"
                wp search-replace "$old_domain" "$(echo $new_url | sed -E 's|https?://||;s|/.*||')" wp_options --allow-root >> "$LOG_FILE" 2>&1
                echo "    [OK] Database wp_options updated to $new_url" | tee -a "$LOG_FILE"
            fi
        }

        IS_ERR=0
        [ -n "$LOGIN_REDIRECT_URL" ] && update_page_link "login" "$LOGIN_REDIRECT_URL" "Login"
        [ -n "$REGISTER_REDIRECT_URL" ] && update_page_link "register" "$REGISTER_REDIRECT_URL" "Register"
        [ -n "$NEW_CONTACT_URL" ] && update_page_link "contact-us" "$NEW_CONTACT_URL" "Contact"
        
        # รันฟังก์ชันแก้ Option ถ้ามีการใส่ -O
        [ -n "$NEW_OPTION_URL" ] && update_option_url "" "$NEW_OPTION_URL" ""
        
        wp cache flush --allow-root &>/dev/null
        exit $IS_ERR
    )

    if [ $? -eq 0 ]; then ((SUCCESS_COUNT++)); else ((FAILED_COUNT++)); fi

done <<< "$ALL_SITES_LIST"

echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "Summary: Success $SUCCESS_COUNT | Failed $FAILED_COUNT" | tee -a "$LOG_FILE"
echo "Log: $LOG_FILE"
