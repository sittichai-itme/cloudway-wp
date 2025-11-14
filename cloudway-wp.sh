#!/bin/bash

# --- CONFIGURATION START ---

# กำหนด Path ไปยังโฟลเดอร์ Applications ของ Cloudways
# *สำคัญ: แก้ไข 'master' เป็นชื่อผู้ใช้งาน SSH ของคุณ หากไม่ใช่ 'master'*
APPS_DIR="/home/master/applications" 

# กำหนดไฟล์ Log ให้เขียนลงใน Home Directory เพื่อหลีกเลี่ยงปัญหา Permission Denied
# Path นี้จะกลายเป็น /home/master/update_log_[...]
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
    
    # *** NEW GUARD: ข้ามโฟลเดอร์ที่ไม่ใช่ Application (เช่น 'applications' หรือโฟลเดอร์อื่นๆ ที่ไม่ควรมี) ***
    # Cloudways Application folder names are typically 10 characters long, but we just check for obvious anomalies.
    if [ "$APP_NAME" == "applications" ] || [ "$APP_NAME" == "." ] || [ "$APP_NAME" == ".." ]; then
        continue
    fi
    
    # Path สัมพัทธ์ไปยัง public_html
    SITE_PATH="$APP_FOLDER/public_html" 

    # ตรวจสอบว่า Application Folder นี้มีโฟลเดอร์ public_html หรือไม่ (ยืนยันว่าเป็น WP Site)
    if [ -d "$SITE_PATH" ]; then
        echo ">>> กำลังดำเนินการกับ Application Folder: $APP_NAME" | tee -a "$LOG_FILE"
        
        # *** CRITICAL: เข้าสู่ไดเรกทอรี WordPress root ก่อนรัน wp-cli ***
        # ใช้ชื่อโฟลเดอร์สัมพัทธ์ในการ cd เพราะเราอยู่ใน $APPS_DIR แล้ว
        cd "$SITE_PATH" || continue

        # --- WP-CLI COMMANDS START ---

        # 1. Update contact-us-2 page
        CONT_ID=$(wp post list --post_type=page --fields=ID,post_name --format=csv --allow-root | grep ',contact-us-2' | cut -d',' -f1)
        if [ -n "$CONT_ID" ]; then
          # รันคำสั่งอัพเดทเนื้อหา Post
          wp post update "$CONT_ID" --post_content='<!-- wp:html -->
<script>window.location.href = "https://member.ufamiracle.bet/";</script>
<!-- /wp:html -->' --allow-root
          echo "Updated login-2 ID $CONT_ID in $APP_NAME" | tee -a "$LOG_FILE"
        else
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
