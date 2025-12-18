#!/bin/bash

BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/plugin_upgrade_report.txt"
ZIP_FILE="$BASE_DIR/seo-by-rank-math-pro.zip"
PLUGIN_NAME="seo-by-rank-math-pro"

echo "===============================================" >> "$LOG_FILE"
echo "Process started at $(date)" >> "$LOG_FILE"
echo "Base Directory: $BASE_DIR" | tee -a "$LOG_FILE"
echo "===============================================" >> "$LOG_FILE"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File $ZIP_FILE not found! Script aborted." | tee -a "$LOG_FILE"
    exit 1
fi

for SITE in $(ls -d */ 2>/dev/null | sed 's/\///' | grep -E '\.[a-zA-Z]{2,4}$'); do
    SITE_PATH="$BASE_DIR/$SITE"

    if [ -d "$SITE_PATH" ]; then

        cd "$SITE_PATH" || continue


        if [ ! -d "wp-content/plugins/$PLUGIN_NAME" ]; then
            echo "Skipping: $SITE (Plugin not found, will not install new)" | tee -a "$LOG_FILE"
            cd "$BASE_DIR"
            continue
        fi

        echo "Processing site: $SITE" | tee -a "$LOG_FILE"

        
        if wp plugin is-active "$PLUGIN_NAME" --skip-plugins --allow-root --quiet; then
            echo "Status: Plugin is active. Deactivating..." | tee -a "$LOG_FILE"
            wp plugin deactivate "$PLUGIN_NAME" --skip-plugins --allow-root >> "$LOG_FILE" 2>&1
        else
            echo "Status: Plugin is installed but not active." | tee -a "$LOG_FILE"
        fi

        
        echo "Action: Updating $PLUGIN_NAME..." | tee -a "$LOG_FILE"
        wp plugin install "$ZIP_FILE" --activate --force --allow-root >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            echo "Result: SUCCESS for $SITE" | tee -a "$LOG_FILE"
        else
            echo "Result: FAILED for $SITE" | tee -a "$LOG_FILE"
        fi

        echo "----------------------------------------------" | tee -a "$LOG_FILE"
        
        cd "$BASE_DIR"
    fi
done

echo "===============================================" >> "$LOG_FILE"
echo "All processes finished at $(date)" >> "$LOG_FILE"
echo "Log saved to: $LOG_FILE"
echo "===============================================" >> "$LOG_FILE"
