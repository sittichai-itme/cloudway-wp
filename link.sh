#!/bin/bash

LOGIN_REDIRECT_URL=""
REGISTER_REDIRECT_URL=""
NEW_CONTACT_URL=""

while getopts "L:R:C:" opt; do
  case $opt in
    L) LOGIN_REDIRECT_URL="$OPTARG" ;;
    R) REGISTER_REDIRECT_URL="$OPTARG" ;;
    C) NEW_CONTACT_URL="$OPTARG" ;;
    \?) exit 1 ;;
  esac
done

if [ -z "$LOGIN_REDIRECT_URL" ] && [ -z "$REGISTER_REDIRECT_URL" ] && [ -z "$NEW_CONTACT_URL" ]; then
    #echo "Usage: $0 -L "https://site.com" -R "https://site.com" -C "https://site.com""
    echo "Usage: $0 [-L login_url] [-R register_url] [-C contact_url]"
    exit 1
fi

BASE_DIR=$HOME
LOG_FILE="$BASE_DIR/update_wp.log"
UPDATED_SITES_LIST="/tmp/updated_sites.txt"
SKIPPED_SITES_LIST="/tmp/skipped_sites.txt"

> "$UPDATED_SITES_LIST"
> "$SKIPPED_SITES_LIST"

echo "------ Update started at $(date) ------" >> "$LOG_FILE"
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
    REASON=""

    echo "[$CURRENT/$TOTAL_SITES] Processing: $DISPLAY_NAME" | tee -a "$LOG_FILE"
    cd "$SITE_PATH" || { echo "$DISPLAY_NAME (Access Denied)" >> "$SKIPPED_SITES_LIST"; continue; }

    if ! wp core is-installed --allow-root &>/dev/null; then
        echo "    [SKIP] Invalid WP installation." | tee -a "$LOG_FILE"
        echo "$DISPLAY_NAME (Invalid WP)" >> "$SKIPPED_SITES_LIST"
        continue
    fi

    # 1. Login Update (Redirect แบบทับ Content เดิม)
    if [ -n "$LOGIN_REDIRECT_URL" ]; then
        LOGIN_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',login-2' | cut -d',' -f1 | head -n 1)
        if [ -n "$LOGIN_ID" ]; then
            #wp post update "$LOGIN_ID" --post_content='<!-- wp:html -->"<script>window.location.href = "$LOGIN_REDIRECT_URL";</script>"<!-- /wp:html -->' --allow-root >> "$LOG_FILE" 2>&1
            wp post update "$LOGIN_ID" --post_content='<!-- wp:html -->"<script>window.location.href = "$LOGIN_REDIRECT_URL";</script>"<!-- /wp:html -->' --allow-root >> "$LOG_FILE" 2>&1
            echo "    [OK] Updated login-2 -> $LOGIN_REDIRECT_URL" | tee -a "$LOG_FILE"
            WAS_UPDATED=true
        fi
    fi

    # 2. Register Update (Redirect แบบทับ Content เดิม)
    if [ -n "$REGISTER_REDIRECT_URL" ]; then
        REGISTER_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',register-2' | cut -d',' -f1 | head -n 1)
        if [ -n "$REGISTER_ID" ]; then
            wp post update "$REGISTER_ID" --post_content='<!-- wp:html -->"<script>window.location.href = "$REGISTER_REDIRECT_URL";</script>"<!-- /wp:html -->' --allow-root >> "$LOG_FILE" 2>&1
            echo "    [OK] Updated register-2 -> $REGISTER_REDIRECT_URL" | tee -a "$LOG_FILE"
            WAS_UPDATED=true
        fi
    fi

    # 3. Contact Update (ปรับปรุงให้ใส่ Quote ครอบ URL ใหม่เสมอ)
    if [ -n "$NEW_CONTACT_URL" ]; then
        CONTACT_ID=$(wp post list --post_type=page --post_status=publish --fields=ID,post_name --format=csv --allow-root | grep ',contact-us-2' | cut -d',' -f1 | head -n 1)
        if [ -n "$CONTACT_ID" ]; then
            OLD_CONTENT=$(wp post get "$CONTACT_ID" --field=post_content --allow-root)

            # สกัดเอาเฉพาะ URL เดิมออกมาเพื่อแสดงใน Log (แบบสะอาด)
            OLD_URL=$(echo "$OLD_CONTENT" | grep -oP "window.location.href = ['\"]?\K[^'\"; ]*" | head -n 1)

            if echo "$OLD_CONTENT" | grep -q "window.location.href"; then
                # แก้ไขตรงนี้: บังคับให้ปลายทางเป็น '$NEW_CONTACT_URL' (มี single quote ครอบ)
                NEW_CONTENT=$(echo "$OLD_CONTENT" | sed -E "s|window.location.href = ['\"]?([^'\"; ]*)['\"]?;?|window.location.href = '$NEW_CONTACT_URL';|g")

                wp post update "$CONTACT_ID" --post_content="$NEW_CONTENT" --allow-root >> "$LOG_FILE" 2>&1

                # แสดง Log เฉพาะ URL เก่า -> ใหม่ จะได้ไม่รก
                echo "    [OK] Updated contact-us-2: ${OLD_URL:-"unknown"} -> $NEW_CONTACT_URL" | tee -a "$LOG_FILE"
                WAS_UPDATED=true
            else
                REASON="(window.location.href not found)"
            fi
        else
            REASON="(Page contact-us-2 not found)"
        fi
    fi

    if [ "$WAS_UPDATED" = true ]; then
        echo "$DISPLAY_NAME" >> "$UPDATED_SITES_LIST"
    else
        echo "$DISPLAY_NAME $REASON" >> "$SKIPPED_SITES_LIST"
    fi
done

# ส่วนสรุปผล
UPDATED_COUNT=$(wc -l < "$UPDATED_SITES_LIST")
SKIPPED_COUNT=$(wc -l < "$SKIPPED_SITES_LIST")

echo "" | tee -a "$LOG_FILE"
echo "================ SUMMARY ================" | tee -a "$LOG_FILE"
echo "Total processed: $TOTAL_SITES" | tee -a "$LOG_FILE"
echo "Successfully updated: $UPDATED_COUNT sites" | tee -a "$LOG_FILE"
echo "Skipped/No changes: $SKIPPED_COUNT sites" | tee -a "$LOG_FILE"

if [ "$SKIPPED_COUNT" -gt 0 ]; then
    echo "--------------------------------------" | tee -a "$LOG_FILE"
    echo "List of Skipped Sites:" | tee -a "$LOG_FILE"
    cat "$SKIPPED_SITES_LIST" | tee -a "$LOG_FILE"
fi
echo "=========================================" | tee -a "$LOG_FILE"

rm -f "$UPDATED_SITES_LIST" "$SKIPPED_SITES_LIST"
echo "------ Update finished at $(date) ------" >> "$LOG_FILE"
