#!/bin/bash

# หา path ของโฟลเดอร์ปัจจุบันที่สคริปต์นี้ตั้งอยู่แบบอัตโนมัติ
BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/plugin.txt"

echo "------ Plugin Deactivation started at $(date) ------" >> "$LOG_FILE"
echo "Current Base Directory: $BASE_DIR" | tee -a "$LOG_FILE"

# วนลูปหาโฟลเดอร์ที่เป็นชื่อโดเมน
for SITE in $(ls -d */ 2>/dev/null | sed 's/\///' | grep -E '\.[a-zA-Z]{2,4}$'); do
    SITE_PATH="$BASE_DIR/$SITE"

    if [ -d "$SITE_PATH" ]; then
        echo "Processing site: $SITE" | tee -a "$LOG_FILE"

        # เข้าไปยังโฟลเดอร์ของเว็บไซต์
        cd "$SITE_PATH" || continue

        # ตรวจสอบและสั่ง Deactivate Plugin
        if wp plugin is-active seo-by-rank-math-pro --allow-root --quiet; then
            wp plugin deactivate seo-by-rank-math-pro --skip-plugins --allow-root >> "$LOG_FILE" 2>&1
            echo "Result: Deactivated in $SITE" | tee -a "$LOG_FILE"
        else
            echo "Result: Plugin not active or not found in $SITE" | tee -a "$LOG_FILE"
        fi

        echo "--------------------------------------" | tee -a "$LOG_FILE"
        
        # ถอยกลับมาที่ BASE_DIR เพื่อเริ่ม loop ถัดไป
        cd "$BASE_DIR"
    fi
done

echo "------ Process finished at $(date) ------" >> "$LOG_FILE"
