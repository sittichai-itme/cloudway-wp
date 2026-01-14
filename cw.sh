#!/bin/bash

LOGIN_REDIRECT_URL=""
REGISTER_REDIRECT_URL=""
NEW_CONTACT_URL=""

while getopts "L:R:C:" opt; do
  case $opt in
    L) LOGIN_REDIRECT_URL="$OPTARG" ;;
    R) REGISTER_REDIRECT_URL="$OPTARG" ;;
    C) NEW_CONTACT_URL="$OPTARG" ;;
    \?) exit 1 ;;
  esac
done

if [ -z "$LOGIN_REDIRECT_URL" ] && [ -z "$REGISTER_REDIRECT_URL" ] && [ -z "$NEW_CONTACT_URL" ]; then
    echo "Usage: $0 [-L login_url] [-R register_url] [-C contact_url]"
    exit 1
fi

BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/update_wp.log"
> "$LOG_FILE"

echo "------ Update started at $(date) ------" >> "$LOG_FILE"
ALL_SITES=$(find "$BASE_DIR" -maxdepth 3 -name "wp-config.php" ! -path '*/.*')

echo "$ALL_SITES" | while read -r config_path; do
    SITE_PATH=$(dirname "$config_path")
    DISPLAY_NAME=${SITE_PATH#$BASE_DIR/}
    
    (
        cd "$SITE_PATH" || exit
        
        # --- ส่วนที่เพิ่มเข้ามา: ดึงชื่อ Domain ---
        DOMAIN=$(wp option get home --allow-root 2>/dev/null || echo "Unknown Domain")
        echo "------------------------------------------------" | tee -a "$LOG_FILE"
        echo "Processing Site: $DOMAIN ($DISPLAY_NAME)" | tee -a "$LOG_FILE"
        # ----------------------------------------

        update_page_link() {
            local slug=$1
            local new_url=$2
            local label=$3

            local page_id=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ",$slug" | cut -d',' -f1 | head -n 1)
            
            if [ -n "$page_id" ]; then
                local old_content=$(wp post get "$page_id" --field=post_content --allow-root)
                
                if echo "$old_content" | grep -q "<a href="; then
                    local new_content=$(echo "$old_content" | sed -E "s|<a href=\"[^\"]*\"|<a href=\"$new_url\"|g")
                    
                    wp post update "$page_id" --post_content="$new_content" --allow-root >> "$LOG_FILE" 2>&1
                    echo "    [OK] Updated $label ($slug) -> $new_url" | tee -a "$LOG_FILE"
                    
                    wp cache flush --allow-root &>/dev/null
                else
                    echo "    [SKIP] No <a> tag found in $slug" | tee -a "$LOG_FILE"
                fi
            else
                echo "    [NOT FOUND] Page $slug not found" | tee -a "$LOG_FILE"
            fi
        }

        if [ -n "$LOGIN_REDIRECT_URL" ]; then update_page_link "login-2" "$LOGIN_REDIRECT_URL" "Login"; fi
        if [ -n "$REGISTER_REDIRECT_URL" ]; then update_page_link "register-2" "$REGISTER_REDIRECT_URL" "Register"; fi
        if [ -n "$NEW_CONTACT_URL" ]; then update_page_link "contact-us-2" "$NEW_CONTACT_URL" "Contact"; fi
    )
done

echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "Update Complete at $(date). Check $LOG_FILE" | tee -a "$LOG_FILE"
