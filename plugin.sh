#!/bin/bash

USER_HOME="$HOME"
ZIP_FILE="$USER_HOME/seo-by-rank-math-pro.zip"
LOG_FILE="$USER_HOME/plugin_update_$(date +%Y%m%d_%H%M%S).txt"

if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ Error: ZIP file not found at $ZIP_FILE"
    exit 1
fi

echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "🔍 Scanning for WordPress installations..."
echo "------------------------------------------------"

# --- เทคนิค Pre-scan: หาโฟลเดอร์ที่มี wp-config.php ---
# คำสั่งนี้จะสร้างรายการ Path ของเว็บที่มี WP จริงๆ เท่านั้น
WP_PATHS=$(find "$USER_HOME" -maxdepth 2 -name "wp-config.php" -exec dirname {} \;)
WP_COUNT=$(echo "$WP_PATHS" | grep -c /)

if [ "$WP_COUNT" -eq 0 ]; then
    echo "❌ No WordPress sites found!"
    exit 1
fi

echo "✅ Found $WP_COUNT WordPress sites."
echo "------------------------------------------------" | tee -a "$LOG_FILE"
printf "%-30s | %-10s\n" "Site Path" "Status" | tee -a "$LOG_FILE"
echo "------------------------------------------------" | tee -a "$LOG_FILE"

SUCCESS_COUNT=0
FAIL_COUNT=0

# วนลูปเฉพาะ Path ที่เจอว่าเป็น WP แน่นอน
for SITE_PATH in $WP_PATHS; do
    SITE_NAME=$(basename "$SITE_PATH")
    
    cd "$SITE_PATH" || continue

    # รันการติดตั้ง Plugin
    if wp plugin install "$ZIP_FILE" --activate --force --allow-root >> "$LOG_FILE" 2>&1; then
        printf "%-30s | %-10s\n" "$SITE_NAME" "✅ OK" | tee -a "$LOG_FILE"
        ((SUCCESS_COUNT++))
    else
        printf "%-30s | %-10s\n" "$SITE_NAME" "❌ Failed" | tee -a "$LOG_FILE"
        ((FAIL_COUNT++))
    fi
done

# --- สรุปผล ---
echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "🏁 Mass Update Finished!"
echo "Successfully updated : $SUCCESS_COUNT"
echo "Failed               : $FAIL_COUNT"
echo "Log saved to         : $LOG_FILE"
