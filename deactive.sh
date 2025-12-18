#!/bin/bash

PLUGIN_NAME="seo-by-rank-math-pro"

# 1. นับจำนวนโดเมนทั้งหมดก่อนเพื่อใช้คำนวณความคืบหน้า
echo "Counting WordPress installations... please wait."
TOTAL_SITES=$(find . -name "wp-config.php" | wc -l)
CURRENT_COUNT=0

echo "------------------------------------------"
echo "Found $TOTAL_SITES sites. Starting deactivation..."
echo "------------------------------------------"

# 2. เริ่มวนลูปทำงาน
find . -name "wp-config.php" | while read config_path; do
    ((CURRENT_COUNT++))
    
    wp_dir=$(dirname "$config_path")
    
    # แสดงลำดับที่กำลังทำ (เช่น [15/300]) พร้อมชื่อโฟลเดอร์
    printf "[%d/%d] Processing: %s\n" "$CURRENT_COUNT" "$TOTAL_SITES" "$wp_dir"
    
    # รันคำสั่งปิด Plugin (ลดข้อความ output ของ wp-cli ให้ดูสะอาดขึ้น)
    wp plugin deactivate $PLUGIN_NAME --skip-plugins --path="$wp_dir" --allow-root > /dev/null 2>&1
    
    # ตรวจสอบว่าสำเร็จหรือไม่
    if [ $? -eq 0 ]; then
        echo "   ✅ Success"
    else
        echo "   ❌ Failed or Plugin not found"
    fi
    
    echo "------------------------------------------"
done

echo "Done! All $TOTAL_SITES sites have been processed."
