#!/bin/bash

USER_HOME="$HOME"

if [ -L "$USER_HOME/applications" ]; then
    APPS_DIR=$(readlink -f "$USER_HOME/applications")
else
    APPS_DIR="$USER_HOME/applications"
fi

if [ ! -d "$APPS_DIR" ]; then
    echo "ERROR: Applications directory not found: $APPS_DIR"
    exit 1
fi

LOG_FILE="$USER_HOME/update_log_$(date +%Y%m%d_%H%M%S).txt"

echo "------ Mass Update started at $(date) ------" >> "$LOG_FILE"
echo "Applications Directory: $APPS_DIR" >> "$LOG_FILE"
echo "Log File: $LOG_FILE" >> "$LOG_FILE"
echo "------------------------------------------------" >> "$LOG_FILE"


cd "$APPS_DIR" || { echo "ERROR: Cannot CD into $APPS_DIR" | tee -a "$LOG_FILE"; exit 1; }

for APP_FOLDER in */; do
    APP_NAME="${APP_FOLDER%/}"

    if [ "$APP_NAME" == "applications" ] || [ "$APP_NAME" == "." ] || [ "$APP_NAME" == ".." ]; then
        continue
    fi

    SITE_PATH="$APPS_DIR/$APP_FOLDER/public_html"

    if [ -d "$SITE_PATH" ]; then
        echo ">>> Start Update : $APP_NAME" | tee -a "$LOG_FILE"

        cd "$SITE_PATH" || { echo "ERROR: Cannot enter $SITE_PATH" | tee -a "$LOG_FILE"; continue; }

        CONT_ID=$(wp post list --post_type=page --fields=ID,post_name --format=csv --allow-root | grep ',contact-us-2' | cut -d',' -f1)

        if [ -n "$CONT_ID" ]; then

            REDIRECT_URL="https://ufamiracle2.com/contact-us/" #เปลี่ยน URL ตรงนี้

            wp post update "$CONT_ID" --post_content="<!-- wp:html -->
<script>window.location.href = \"$REDIRECT_URL\";</script>
<!-- /wp:html -->" --allow-root

            echo "✓ Updated contact-us-2 (ID: $CONT_ID) in $APP_NAME → $REDIRECT_URL" | tee -a "$LOG_FILE"
        else
            echo "✗ contact-us-2 not found in $APP_NAME" | tee -a "$LOG_FILE"
        fi


        echo "<<< Done: $APP_NAME" | tee -a "$LOG_FILE"
        echo "------------------------------------------------" | tee -a "$LOG_FILE"

        cd "$APPS_DIR"
    else
        echo "WARNING: $APP_NAME NotFound public_html — Skip" | tee -a "$LOG_FILE"
    fi

done

echo "------ Mass Update finished at $(date) ------" >> "$LOG_FILE"
echo "Log saved to: $LOG_FILE"
