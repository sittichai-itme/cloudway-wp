#!/bin/bash
# Deactive Plugin Cpanel
PLUGIN_NAME="seo-by-rank-math-pro"

echo "------------------------------------------"
echo "Starting to deactivate $PLUGIN_NAME on all WordPress sites..."
echo "------------------------------------------"
find . -name "wp-config.php" | while read config_path; do
    
    # ดึงเฉพาะ path ของโฟลเดอร์ออกมา
    wp_dir=$(dirname "$config_path")
    
    echo "Processing site in: $wp_dir"
    
    wp plugin deactivate $PLUGIN_NAME --skip-plugins --path="$wp_dir" --allow-root
    
    echo "Done for $wp_dir"
    echo "------------------------------------------"
done

echo "Process complete!"
