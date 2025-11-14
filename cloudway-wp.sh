#!/bin/bash

# --- CONFIGURATION START ---

# กำหนด Path ไปยังโฟลเดอร์ Applications ของ Cloudways
# สำคัญ: แก้ไข 'master' เป็นชื่อผู้ใช้งาน SSH ของคุณ หากไม่ใช่ 'master'
USER_HOME=$(dirname "$APPS_DIR")
LOG_FILE="$USER_HOME/update_log_$(date +%Y%m%d_%H%M%S).txt"

# --- CONFIGURATION END ---

echo "------ Mass Update started at $(date) ------" >> "$LOG_FILE"

# เข้าสู่ไดเรกทอรี Applications
cd "$APPS_DIR" || { echo "Error: Could not change to $APPS_DIR. Exiting." | tee -a "$LOG_FILE"; exit 1; }

# วนลูปผ่านทุกโฟลเดอร์ Application (ชื่อสุ่ม) ที่อยู่ใน APPS_DIR
for APP_FOLDER in */; do
    # ตัด / ที่ท้ายชื่อโฟลเดอร์ออก (e.g., atveeexaya)
    APP_NAME="${APP_FOLDER%/}"
    SITE_PATH="$APP_FOLDER/public_html"

    # ตรวจสอบว่า Application Folder นี้มีโฟลเดอร์ public_html หรือไม่ (ยืนยันว่าเป็น WP Site)
    if [ -d "$SITE_PATH" ]; then
        echo ">>> กำลังดำเนินการกับ Application Folder: $APP_NAME" | tee -a "$LOG_FILE"
        
        # *** CRITICAL: เข้าสู่ไดเรกทอรี WordPress root ก่อนรัน wp-cli ***
        cd "$SITE_PATH" || continue

        # --- WP-CLI COMMANDS START ---

        # 1. Update contact-us-2 page
        CONTACT_ID=$(wp post list --post_type=page --fields=ID,post_name --format=csv --allow-root | grep ',contact-us-2' | cut -d',' -f1)
        if [ -n "$CONTACT_ID" ]; then
          # รันคำสั่งอัพเดทเนื้อหา Post
          wp post update "$CONTACT_ID" --post_content='<!-- wp:html -->
<script>window.location.href = "https://ufamiracle2.com/contact-us/";</script>
<!-- /wp:html -->' --allow-root
          echo "Updated login-2 ID $CONTACT_ID in $APP_NAME" | tee -a "$LOG_FILE"
        els
          echo "login-2 page not found in $APP_NAME" | tee -a "$LOG_FILE"
        fi
        
        # --- WP-CLI COMMANDS END ---

        echo "<<< ดำเนินการเสร็จสิ้นกับ $APP_NAME" | tee -a "$LOG_FILE"
        echo "--------------------------------------" | tee -a "$LOG_FILE"
        
        # กลับไปที่ไดเรกทอรี Applications เพื่อวนลูปต่อไป
        cd "$APPS_DIR"
    else
        echo "Warning: Public_html not found in $APP_NAME. Skipping." | tee -a "$LOG_FILE"
    fi
done

echo "------ Mass Update finished at $(date) ------" >> "$LOG_FILE"
