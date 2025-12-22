#!/bin/bash

BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/plugin_upgrade_report.txt"
ZIP_FILE="$BASE_DIR/seo-by-rank-math-pro.zip"
PLUGIN_NAME="seo-by-rank-math-pro"

SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SITES=""
echo "===============================================" > "$LOG_FILE"
echo "Process started at $(date)" >> "$LOG_FILE"
echo "Base Directory: $BASE_DIR" >> "$LOG_FILE"
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File $ZIP_FILE not found!" | tee -a "$LOG_FILE"
    exit 1
fi

SITE_LIST=$(ls -d */ 2>/dev/null | sed 's/\///' | grep -E '\.[a-zA-Z]{2,4}$')
TOTAL_SITES=$(echo "$SITE_LIST" | grep -c .)
echo "Total sites found: $TOTAL_SITES" | tee -a "$LOG_FILE"
echo "===============================================" >> "$LOG_FILE"

for SITE in $SITE_LIST; do
    SITE_PATH="$BASE_DIR/$SITE"

    if [ -d "$SITE_PATH/wp-content/plugins/$PLUGIN_NAME" ]; then
        
        wp plugin install "$ZIP_FILE" --activate --force --allow-root --path="$SITE_PATH" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "[$(date +'%H:%M:%S')] SUCCESS: $SITE" | tee -a "$LOG_FILE"
            ((SUCCESS_COUNT++))
        else
            echo "[$(date +'%H:%M:%S')] FAILED: $SITE" | tee -a "$LOG_FILE"
            ((FAILED_COUNT++))
            FAILED_SITES+="$SITE "
        fi
    else
        echo "[$(date +'%H:%M:%S')] SKIP: $SITE (Plugin not found)" >> "$LOG_FILE"
    fi
done

echo "===============================================" >> "$LOG_FILE"
echo "Summary Report:" | tee -a "$LOG_FILE"
echo "Success: $SUCCESS_COUNT" | tee -a "$LOG_FILE"
echo "Failed: $FAILED_COUNT" | tee -a "$LOG_FILE"

if [ $FAILED_COUNT -gt 0 ]; then
    echo "Failed Folders: $FAILED_SITES" | tee -a "$LOG_FILE"
fi

echo "Finished at $(date)" >> "$LOG_FILE"
