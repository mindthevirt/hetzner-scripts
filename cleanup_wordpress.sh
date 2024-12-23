#!/bin/bash

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "✓ Success: $1"
    else
        echo "✗ Error: $1 failed"
        exit 1
    fi
}

# Function to sanitize domain name for database name
sanitize_domain() {
    echo "$1" | tr '.' '_' | tr '-' '_'
}

# Check if domain name is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a domain name"
    echo "Usage: $0 example.com"
    exit 1
fi

domain_name="$1"
db_name=$(sanitize_domain "$domain_name")
db_user="${db_name%%_*}_user"

echo "WARNING: This will completely remove the WordPress site at $domain_name"
echo "This includes:"
echo "- All website files"
echo "- Database and database user"
echo "- Nginx configuration"
echo "- SSL certificates (if any)"
echo
read -p "Are you sure you want to continue? (y/N): " confirm

if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Operation cancelled"
    exit 0
fi

echo "Starting cleanup for $domain_name..."

# 1. Remove database and user
echo "Removing database and user..."
mysql_commands="
DROP DATABASE IF EXISTS ${db_name};
DROP USER IF EXISTS '${db_user}'@'localhost';
FLUSH PRIVILEGES;"

if mysql -u root -p <<< "$mysql_commands"; then
    check_status "Database cleanup"
else
    echo "Warning: Database cleanup failed. Continuing with other cleanup tasks..."
fi

# 2. Remove Nginx configurations
echo "Removing Nginx configurations..."
sudo rm -f /etc/nginx/sites-enabled/$domain_name
sudo rm -f /etc/nginx/sites-available/$domain_name
check_status "Nginx configuration removal"

# 3. Remove website files
echo "Removing website files..."
sudo rm -rf /var/www/html/$domain_name
check_status "Website files removal"

# 4. Remove SSL certificates if they exist (Let's Encrypt)
if [ -d "/etc/letsencrypt/live/$domain_name" ]; then
    echo "Removing SSL certificates..."
    sudo certbot delete --cert-name $domain_name
    check_status "SSL certificate removal"
fi

# 5. Remove credentials file
echo "Removing credentials file..."
sudo rm -f "/root/.${domain_name}_credentials.txt"
check_status "Credentials file removal"

# 6. Restart Nginx
echo "Restarting Nginx..."
sudo nginx -t && sudo systemctl restart nginx
check_status "Nginx restart"

# 7. Clean any potential backup files
echo "Removing any backup files..."
sudo rm -f /var/www/html/${domain_name}*.tar.gz
sudo rm -f /var/www/html/${domain_name}*.backup
check_status "Backup files cleanup"

echo "========== CLEANUP COMPLETE =========="
echo "The following items have been removed:"
echo "✓ Website files from /var/www/html/$domain_name"
echo "✓ Database '$db_name' and user '$db_user'"
echo "✓ Nginx configuration for $domain_name"
echo "✓ SSL certificates (if they existed)"
echo "✓ Credentials file"
echo "✓ Backup files"
echo
echo "The site $domain_name has been completely removed from the system."
echo "===================================="
