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

# Check if domain name is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a domain name"
    echo "Usage: $0 example.com"
    exit 1
fi

domain_name="$1"

# Prompt for email address
read -p "Enter email address for SSL certificate registration: " email_address

if [ -z "$email_address" ]; then
    echo "Error: Email address cannot be empty"
    exit 1
fi

# Validate email format (basic check)
if ! echo "$email_address" | grep -E "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$" >/dev/null; then
    echo "Error: Invalid email address format"
    exit 1
fi

# Check if the domain's Nginx configuration exists
if [ ! -f "/etc/nginx/sites-available/$domain_name" ]; then
    echo "Error: Nginx configuration for $domain_name not found"
    exit 1
fi

echo "Starting SSL setup for $domain_name..."

# Install Certbot if not already installed
echo "Checking for Certbot..."
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    sudo apt-get update
    sudo apt-get install -y certbot python3-certbot-nginx
    check_status "Certbot installation"
fi

# Backup existing Nginx configuration
echo "Backing up current Nginx configuration..."
sudo cp "/etc/nginx/sites-available/$domain_name" "/etc/nginx/sites-available/${domain_name}.backup"
check_status "Nginx configuration backup"

# Obtain SSL certificate
echo "Obtaining SSL certificate..."
sudo certbot --nginx \
    -d $domain_name -d www.$domain_name \
    --agree-tos \
    --non-interactive \
    --email $email_address \
    --reinstall

# Wait a moment for certificates to be properly installed
sleep 2

# Configure Nginx with specific certificate paths
cert_path="/etc/letsencrypt/live/$domain_name/fullchain.pem"
key_path="/etc/letsencrypt/live/$domain_name/privkey.pem"

if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
    echo "Configuring Nginx with SSL certificates for $domain_name..."
    
    # Backup existing configuration if it exists
    if [ -f "/etc/nginx/sites-available/$domain_name" ]; then
        sudo cp "/etc/nginx/sites-available/$domain_name" "/etc/nginx/sites-available/${domain_name}.backup"
    fi
    
    # Create or update the Nginx configuration
    sudo tee "/etc/nginx/sites-available/$domain_name" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain_name www.$domain_name;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain_name www.$domain_name;
    root /var/www/html/$domain_name;
    index index.php index.html index.htm;

    # SSL certificates
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;

    # Include Certbot's SSL configuration
    include /etc/letsencrypt/options-ssl-nginx.conf;

    # Security headers
    include /etc/nginx/conf.d/ssl-params.conf;

    # Performance settings
    client_max_body_size 64M;
    
    # WordPress settings
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    # Deny access to sensitive files
    location ~ /\.(ht|git|env) {
        deny all;
    }

    # Deny access to wp-config.php
    location = /wp-config.php {
        deny all;
    }
}
EOF
    check_status "Nginx SSL configuration"

    # Ensure the site is enabled
    if [ ! -f "/etc/nginx/sites-enabled/$domain_name" ]; then
        sudo ln -s "/etc/nginx/sites-available/$domain_name" "/etc/nginx/sites-enabled/"
    fi
else
    echo "Error: SSL certificates not found at expected location"
    echo "Certificate path: $cert_path"
    echo "Key path: $key_path"
    exit 1
fi
check_status "SSL certificate generation"

# Remove existing ssl-params.conf to avoid conflicts
echo "Removing any existing SSL parameters file..."
sudo rm -f /etc/nginx/conf.d/ssl-params.conf

# Create fresh ssl-params.conf with only security headers
echo "Creating security headers configuration..."
sudo tee /etc/nginx/conf.d/ssl-params.conf << EOF
# Security headers
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options SAMEORIGIN;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF
check_status "Security headers configuration"
check_status "SSL parameters configuration"

# Create a stronger Diffie-Hellman group
if [ ! -f /etc/nginx/dhparam.pem ]; then
    echo "Generating Diffie-Hellman parameters (this may take a while)..."
    sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
    check_status "DH parameters generation"
fi

# Update Nginx configuration to include SSL parameters
echo "Updating Nginx configuration with SSL parameters..."
if [ -f "/etc/nginx/sites-available/$domain_name" ]; then
    if ! grep -q "ssl_dhparam" "/etc/nginx/sites-available/$domain_name" && [ -f /etc/nginx/dhparam.pem ]; then
        echo "Adding DH parameters to Nginx configuration..."
        sudo sed -i "/listen 443/a \ \ \ \ ssl_dhparam /etc/nginx/dhparam.pem;" "/etc/nginx/sites-available/$domain_name"
    fi

    # Only include our custom ssl-params.conf if it contains additional settings
    if [ -f /etc/nginx/conf.d/ssl-params.conf ] && ! grep -q "ssl-params.conf" "/etc/nginx/sites-available/$domain_name"; then
        echo "Including SSL parameters in Nginx configuration..."
        sudo sed -i "/listen 443/a \ \ \ \ include /etc/nginx/conf.d/ssl-params.conf;" "/etc/nginx/sites-available/$domain_name"
    fi
fi

# Add security headers
echo "Adding security headers..."
if ! grep -q "add_header X-Frame-Options" "/etc/nginx/sites-available/$domain_name"; then
    sudo tee -a "/etc/nginx/sites-available/$domain_name" << EOF

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
EOF
fi

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t
check_status "Nginx configuration test"

# Restart Nginx
echo "Restarting Nginx..."
sudo systemctl restart nginx
check_status "Nginx restart"

# Set up auto-renewal cron job
echo "Setting up auto-renewal cron job..."
if ! sudo crontab -l | grep -q "certbot renew"; then
    (sudo crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | sudo crontab -
    check_status "Auto-renewal cron job setup"
fi

echo "========== SSL SETUP COMPLETE =========="
echo "Domain: $domain_name"
echo "✓ SSL certificate installed"
echo "✓ HTTPS configured"
echo "✓ Security headers added"
echo "✓ Auto-renewal configured"
echo "✓ Nginx optimized for SSL"
echo
echo "Your site is now accessible via HTTPS:"
echo "https://$domain_name"
echo "A backup of your original configuration has been saved to:"
echo "/etc/nginx/sites-available/${domain_name}.backup"
echo "===================================="

# Test HTTPS access
echo "Testing HTTPS access..."
if curl -s -I "https://$domain_name" | grep -q "200 OK"; then
    echo "✓ HTTPS is working correctly"
else
    echo "! Warning: HTTPS test failed. Please check your DNS settings"
    echo "  and make sure they point to this server."
fi
