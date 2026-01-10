#!/bin/bash

BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/update_wp.log"

UPDATED_COUNT=0
FAILED_COUNT=0

echo "------ Update started at $(date) ------" >> "$LOG_FILE"
echo "Working Directory: $BASE_DIR" | tee -a "$LOG_FILE"

echo "Scanning for WordPress installations..."
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
    cd "$SITE_PATH" || continue

    if ! wp core is-installed --allow-root &>/dev/null; then
        echo "   [SKIP] Invalid WP installation." | tee -a "$LOG_FILE"
        continue
    fi

    # Update login-2
    LOGIN_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',login-2' | cut -d',' -f1 | head -n 1)
    if [ -n "$LOGIN_ID" ]; then
        wp post update "$LOGIN_ID" --post_content='<script>window.location.href = "https://member.ufasonic.vip/";</script>' --allow-root >> "$LOG_FILE" 2>&1
        echo "   [OK] Updated login-2 (ID: $LOGIN_ID)" | tee -a "$LOG_FILE"
        WAS_UPDATED=true
    else
        echo "   [--] login-2 not found" | tee -a "$LOG_FILE"
    fi

    # Update register-2
    REGISTER_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',register-2' | cut -d',' -f1 | head -n 1)
    if [ -n "$REGISTER_ID" ]; then
        wp post update "$REGISTER_ID" --post_content='<script>window.location.href = "https://member.ufasonic.vip/register";</script>' --allow-root >> "$LOG_FILE" 2>&1
        echo "   [OK] Updated register-2 (ID: $REGISTER_ID)" | tee -a "$LOG_FILE"
        WAS_UPDATED=true
    else
        echo "   [--] register-2 not found" | tee -a "$LOG_FILE"
    fi

    if [ "$WAS_UPDATED" = true ]; then
        ((UPDATED_COUNT++))
    fi

    echo $UPDATED_COUNT > /tmp/updated_count_tmp
done

UPDATED_COUNT=$(cat /tmp/updated_count_tmp 2>/dev/null || echo 0)
rm -f /tmp/updated_count_tmp

echo "--------------------------------------" | tee -a "$LOG_FILE"
echo "SUMMARY:" | tee -a "$LOG_FILE"
echo "Total WordPress found: $TOTAL_SITES" | tee -a "$LOG_FILE"
echo "Total sites updated  : $UPDATED_COUNT" | tee -a "$LOG_FILE"
echo "------ Update finished at $(date) ------" >> "$LOG_FILE"
