#!/bin/bash

APPS_DIR="/home/1339491.cloudwaysapps.com"

USER_HOME=$(dirname "$APPS_DIR")
LOG_FILE="$USER_HOME/update_log_$(date +%Y%m%d_%H%M%S).txt"

echo "------ Mass Update started at $(date) ------" >> "$LOG_FILE"

cd "$APPS_DIR" || { echo "Error: Could not change to $APPS_DIR. Exiting." | tee -a "$LOG_FILE"; exit 1; }

for APP_FOLDER in */; do
    APP_NAME="${APP_FOLDER%/}"
    
    if [ "$APP_NAME" == "applications" ] || [ "$APP_NAME" == "." ] || [ "$APP_NAME" == ".." ]; then
        continue
    fi
    
    SITE_PATH="$APP_FOLDER/public_html" 

    if [ -d "$SITE_PATH" ]; then
        echo ">>> กำลังดำเนินการกับ Application Folder: $APP_NAME" | tee -a "$LOG_FILE"
        
        cd "$SITE_PATH" || continue

        # --- WP-CLI COMMANDS START ---

        # 1. Update contact-us-2 page
        CONT_ID=$(wp post list --post_type=page --fields=ID,post_name --format=csv --allow-root | grep ',contact-us-2' | cut -d',' -f1)
        if [ -n "$CONT_ID" ]; then
          # รันคำสั่งอัพเดทเนื้อหา Post
          wp post update "$CONT_ID" --post_content='<!-- wp:html -->
<script>window.location.href = "https://ufamiracle2.com/contact-us/";</script>
<!-- /wp:html -->' --allow-root
          echo "Updated login-2 ID $CONT_ID in $APP_NAME" | tee -a "$LOG_FILE"
        else
          echo "login-2 page not found in $APP_NAME" | tee -a "$LOG_FILE"
        fi
        
        # --- WP-CLI COMMANDS END ---

        echo "<<< ดำเนินการเสร็จสิ้นกับ $APP_NAME" | tee -a "$LOG_FILE"
        echo "--------------------------------------" | tee -a "$LOG_FILE"
        
        cd "$APPS_DIR"
    else
        echo "Warning: Public_html not found in $APP_NAME. Skipping." | tee -a "$LOG_FILE"
    fi
done

echo "------ Mass Update finished at $(date) ------" >> "$LOG_FILE"
