#!/bin/bash

LOGIN_REDIRECT_URL="https://member.ufasonic.vip/"
REGISTER_REDIRECT_URL="https://member.ufasonic.vip/register"
OLD_CONTACT_URL="https://member.ufasonics.com/contact-us"
NEW_CONTACT_URL="https://member.ufasonic.vip/contact-us"
UPDATE_LOGIN=false
UPDATE_REGISTER=false
UPDATE_CONTACT=false

for arg in "$@"; do
    if [ "$arg" == "login" ]; then UPDATE_LOGIN=true; fi
    if [ "$arg" == "register" ]; then UPDATE_REGISTER=true; fi
    if [ "$arg" == "contact" ]; then UPDATE_CONTACT=true; fi
done

if [ "$UPDATE_LOGIN" = false ] && [ "$UPDATE_REGISTER" = false ] && [ "$UPDATE_CONTACT" = false ]; then
    echo "Usage: $0 [login] [register] [contact]"
    echo "Example: $0 login register contact"
    exit 1
fi

BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/update_wp.log"
FAILED_SITES_LOG="/tmp/failed_sites.txt"

> "$FAILED_SITES_LOG"
UPDATED_COUNT=0

echo "------ Update started at $(date) ------" >> "$LOG_FILE"
ALL_SITES=$(find "$BASE_DIR" -maxdepth 3 -name "wp-config.php" ! -path '*/.*')
TOTAL_SITES=$(echo "$ALL_SITES" | grep -c "wp-config.php")

echo "Found $TOTAL_SITES sites to process." | tee -a "$LOG_FILE"
echo "--------------------------------------" | tee -a "$LOG_FILE"

CURRENT=0
echo "$ALL_SITES" | while read -r config_path; do
    ((CURRENT++))
    SITE_PATH=$(dirname "$config_path")
    DISPLAY_NAME=${SITE_PATH#$BASE_DIR/}
    WAS_UPDATED=false

    echo "[$CURRENT/$TOTAL_SITES] Processing: $DISPLAY_NAME" | tee -a "$LOG_FILE"
    cd "$SITE_PATH" || { echo "$DISPLAY_NAME (Cannot access folder)" >> "$FAILED_SITES_LOG"; continue; }

    if ! wp core is-installed --allow-root &>/dev/null; then
        echo "    [SKIP] Invalid WP installation." | tee -a "$LOG_FILE"
        echo "$DISPLAY_NAME (Invalid WP installation)" >> "$FAILED_SITES_LOG"
        continue
    fi

    # 1. Login Update (Overwrite)
    if [ "$UPDATE_LOGIN" = true ]; then
        LOGIN_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',login-2' | cut -d',' -f1 | head -n 1)
        if [ -n "$LOGIN_ID" ]; then
            #wp post update "$LOGIN_ID" --post_content="<script>window.location.href = '$LOGIN_REDIRECT_URL';</script>" --allow-root >> "$LOG_FILE" 2>&1
            wp post update "$LOGIN_ID" --post_content='<!-- wp:html -->
<script>window.location.href = '$LOGIN_REDIRECT_URL';</script>
<!-- /wp:html -->' --allow-root >> "$LOG_FILE" 2>&1
            echo "    [OK] Updated login-2" | tee -a "$LOG_FILE"
            WAS_UPDATED=true
        fi
    fi

    # 2. Register Update (Overwrite)
    if [ "$UPDATE_REGISTER" = true ]; then
        REGISTER_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',register-2' | cut -d',' -f1 | head -n 1)
        if [ -n "$REGISTER_ID" ]; then
            #wp post update "$REGISTER_ID" --post_content="<script>window.location.href = '$REGISTER_REDIRECT_URL';</script>" --allow-root >> "$LOG_FILE" 2>&1
            wp post update "$REGISTER_ID" --post_content='<!-- wp:html -->
<script>window.location.href = '$REGISTER_REDIRECT_URL';</script>
<!-- /wp:html -->' --allow-root >> "$LOG_FILE" 2>&1
            echo "    [OK] Updated register-2" | tee -a "$LOG_FILE"
            WAS_UPDATED=true
        fi
    fi

    # 3. Contact Update (Search & Replace)
    if [ "$UPDATE_CONTACT" = true ]; then
        CONTACT_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',contact-us-2' | cut -d',' -f1 | head -n 1)
        if [ -n "$CONTACT_ID" ]; then
            OLD_CONTENT=$(wp post get "$CONTACT_ID" --field=post_content --allow-root)
            if echo "$OLD_CONTENT" | grep -q "$OLD_CONTACT_URL"; then
                # ใช้เครื่องหมาย | เป็น delimiter เพื่อหลีกเลี่ยงปัญหากับ / ใน URL
                NEW_CONTENT=$(echo "$OLD_CONTENT" | sed "s|$OLD_CONTACT_URL|$NEW_CONTACT_URL|g")
                wp post update "$CONTACT_ID" --post_content="$NEW_CONTENT" --allow-root >> "$LOG_FILE" 2>&1
                echo "    [OK] Updated contact-us-2 (URL replaced)" | tee -a "$LOG_FILE"
                WAS_UPDATED=true
            else
                echo "    [--] contact-us-2: Target URL not found" | tee -a "$LOG_FILE"
            fi
        fi
    fi

    if [ "$WAS_UPDATED" = true ]; then
        ((UPDATED_COUNT++))
    fi
    echo $UPDATED_COUNT > /tmp/updated_count_tmp
done

UPDATED_COUNT=$(cat /tmp/updated_count_tmp 2>/dev/null || echo 0)
rm -f /tmp/updated_count_tmp

echo "--------------------------------------" | tee -a "$LOG_FILE"
echo "SUMMARY: Updated $UPDATED_COUNT sites." | tee -a "$LOG_FILE"
[ -f "$FAILED_SITES_LOG" ] && rm -f "$FAILED_SITES_LOG"
echo "------ Update finished at $(date) ------" >> "$LOG_FILE"
