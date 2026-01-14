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
    echo "Usage: $0 [-L "URL"] [-R "URL"] [-C "URL"]"
    exit 1
fi
BASE_DIR="$HOME/applications"
LOG_FILE="$HOME/update_wp.log"

> "$LOG_FILE"
echo "------ Update started at $(date) ------" >> "$LOG_FILE"
ALL_SITES=$(find -L "$BASE_DIR" -name "wp-config.php" ! -path "*/.*")
if [ -z "$ALL_SITES" ]; then
    echo "Error: No WordPress installations found." | tee -a "$LOG_FILE"
    exit 1
fi
echo "$ALL_SITES" | while read -r config_path; do
    [ -z "$config_path" ] && continue
    SITE_PATH=$(dirname "$config_path")
    DISPLAY_NAME=$(echo "$SITE_PATH" | sed "s|$BASE_DIR/||")
    (
        cd "$SITE_PATH" || exit
        DOMAIN=$(wp option get home --allow-root 2>/dev/null || echo "Unknown Domain")
        echo "------------------------------------------------" | tee -a "$LOG_FILE"
        echo "Processing Site: $DOMAIN ($DISPLAY_NAME)" | tee -a "$LOG_FILE"
        update_page_link() {
            local slug=$1
            local new_url=$2
            local label=$3
            
            local page_id=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep -E ",($slug|-2|,($slug))" | cut -d',' -f1 | head -n 1)
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
                echo "    [NOT FOUND] Page matching '$slug' not found" | tee -a "$LOG_FILE"
            fi
        }
      
        [ -n "$LOGIN_REDIRECT_URL" ] && update_page_link "login" "$LOGIN_REDIRECT_URL" "Login"
        [ -n "$REGISTER_REDIRECT_URL" ] && update_page_link "register" "$REGISTER_REDIRECT_URL" "Register"
        [ -n "$NEW_CONTACT_URL" ] && update_page_link "contact-us" "$NEW_CONTACT_URL" "Contact"
    )
done
echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "Update Complete. Check Log at: $LOG_FILE" | tee -a "$LOG_FILE"
