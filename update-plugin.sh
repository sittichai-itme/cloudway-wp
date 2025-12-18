#!/bin/bash
#update plugin

BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/plugin_update.txt"
ZIP_FILE="$BASE_DIR/seo-by-rank-math-pro.zip"

echo "------ Plugin Update started at $(date) ------" >> "$LOG_FILE"
echo "Current Base Directory: $BASE_DIR" | tee -a "$LOG_FILE"


if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File $ZIP_FILE not found!" | tee -a "$LOG_FILE"
    exit 1
fi

for SITE in $(ls -d */ 2>/dev/null | sed 's/\///' | grep -E '\.[a-zA-Z]{2,4}$'); do
    SITE_PATH="$BASE_DIR/$SITE"

    if [ -d "$SITE_PATH" ]; then
        echo "Processing site: $SITE" | tee -a "$LOG_FILE"

        cd "$SITE_PATH" || continue


        wp plugin install "$ZIP_FILE" --activate --force --allow-root >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            echo "Result: Successfully updated in $SITE" | tee -a "$LOG_FILE"
        else
            echo "Result: Update FAILED in $SITE (Check log for details)" | tee -a "$LOG_FILE"
        fi

        echo "--------------------------------------" | tee -a "$LOG_FILE"
        
        cd "$BASE_DIR"
    fi
done

echo "------ Process finished at $(date) ------" >> "$LOG_FILE"
