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

# Function to generate a random password
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | cut -c1-16
}

# Function to sanitize domain name for database name
sanitize_domain() {
    echo "$1" | tr '.' '_' | tr '-' '_'
}

# Prompt for domain name
read -p "Enter the domain name (e.g., example.com): " domain_name

if [ -z "$domain_name" ]; then
    echo "Error: Domain name cannot be empty"
    exit 1
fi

# Generate database name from domain
db_name=$(sanitize_domain "$domain_name")

# Generate database user from domain
db_user="${db_name%%_*}_user"

# Generate random password
db_password=$(generate_password)

echo "Starting WordPress site setup for $domain_name..."

# Step 1: Update system
echo "Step 1: Updating system..."
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
check_status "System update"

# Step 3: Create MySQL database and user
echo "Step 3: Setting up MySQL database..."
mysql_commands="
CREATE DATABASE IF NOT EXISTS ${db_name};
CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;"

if mysql -u root -p <<< "$mysql_commands"; then
    check_status "Database setup"
else
    echo "Error: Database setup failed"
    exit 1
fi

# Step 6: Create Nginx Server Block
echo "Step 6: Creating Nginx server block..."
sudo tee /etc/nginx/sites-available/$domain_name << EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/html/$domain_name;
    index index.php index.html index.htm;
    server_name $domain_name www.$domain_name;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
check_status "Nginx server block creation"

# Step 7: Create Document Root
echo "Step 7: Creating document root..."
sudo mkdir -p /var/www/html/$domain_name
check_status "Document root creation"

# Step 8: Download and install WordPress
echo "Step 8: Downloading WordPress..."
cd /tmp
wget https://wordpress.org/latest.tar.gz
check_status "WordPress download"

echo "Extracting WordPress..."
tar -xzvf latest.tar.gz
check_status "WordPress extraction"

echo "Copying WordPress files..."
sudo cp -R wordpress/* /var/www/html/$domain_name/
check_status "WordPress files copy"

# Step 9: Configure WordPress
echo "Step 9: Configuring WordPress..."
sudo cp /var/www/html/$domain_name/wp-config-sample.php /var/www/html/$domain_name/wp-config.php
sudo sed -i "s/database_name_here/$db_name/" /var/www/html/$domain_name/wp-config.php
sudo sed -i "s/username_here/$db_user/" /var/www/html/$domain_name/wp-config.php
sudo sed -i "s/password_here/$db_password/" /var/www/html/$domain_name/wp-config.php
check_status "WordPress configuration"

# Set correct permissions
echo "Setting permissions..."
sudo chown -R www-data:www-data /var/www/html/$domain_name
sudo chmod -R 755 /var/www/html/$domain_name
check_status "Permissions setup"

# Enable site and restart Nginx
echo "Enabling site and restarting Nginx..."
cd /etc/nginx/sites-enabled
sudo ln -s /etc/nginx/sites-available/$domain_name
sudo nginx -t && sudo systemctl restart nginx
check_status "Nginx restart"

# Clean up
echo "Cleaning up..."
rm -rf /tmp/wordpress /tmp/latest.tar.gz

# Save credentials
echo "Saving credentials..."
credentials_file="/root/.${domain_name}_credentials.txt"
echo "Website: $domain_name
Database Name: $db_name
Database User: $db_user
Database Password: $db_password" | sudo tee $credentials_file > /dev/null
sudo chmod 600 $credentials_file

echo "========== INSTALLATION COMPLETE =========="
echo "Website: http://$domain_name"
echo "Database Name: $db_name"
echo "Database User: $db_user"
echo "Database Password: $db_password"
echo "Credentials saved in: $credentials_file"
echo "========================================="
echo "You can now complete the WordPress installation by visiting http://$domain_name"
