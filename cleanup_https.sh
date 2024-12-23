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

echo "WARNING: This will remove SSL configuration for $domain_name"
echo "This includes:"
echo "- Let's Encrypt certificates"
echo "- SSL-related Nginx configurations"
echo "- SSL parameter files (if not used by other domains)"
echo
read -p "Are you sure you want to continue? (y/N): " confirm

if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "Operation cancelled"
    exit 0
fi

echo "Starting SSL cleanup for $domain_name..."

# Backup current Nginx configuration
echo "Creating backup of Nginx configuration..."
timestamp=$(date +%Y%m%d_%H%M%S)
if [ -f "/etc/nginx/sites-available/$domain_name" ]; then
    sudo cp "/etc/nginx/sites-available/$domain_name" "/etc/nginx/sites-available/${domain_name}.backup_${timestamp}"
    check_status "Nginx configuration backup"
fi

# Remove Let's Encrypt certificates
echo "Removing SSL certificates..."
if [ -d "/etc/letsencrypt/live/$domain_name" ]; then
    sudo certbot delete --cert-name $domain_name --non-interactive
    check_status "Certificate removal"
else
    echo "No Let's Encrypt certificate found for $domain_name"
fi

# Remove SSL configurations from Nginx site config
if [ -f "/etc/nginx/sites-available/$domain_name" ]; then
    echo "Removing SSL configurations from Nginx site config..."
    
    # Create temporary file
    tmp_file=$(mktemp)
    
    # Remove SSL-related lines from the configuration
    sudo sed '/ssl_certificate/d' "/etc/nginx/sites-available/$domain_name" | \
    sed '/ssl_certificate_key/d' | \
    sed '/ssl_dhparam/d' | \
    sed '/ssl-params.conf/d' | \
    sed '/listen 443/d' | \
    sed '/ssl http2/d' | \
    sed '/if ($scheme != "https")/,/}/d' > "$tmp_file"
    
    # Replace the original file
    sudo mv "$tmp_file" "/etc/nginx/sites-available/$domain_name"
    sudo chmod 644 "/etc/nginx/sites-available/$domain_name"
    check_status "SSL configuration removal"
    
    # Remove temp file if it still exists
    rm -f "$tmp_file"
fi

# Check if ssl-params.conf is used by other sites
echo "Checking if ssl-params.conf is still needed..."
ssl_params_in_use=false
for config in /etc/nginx/sites-available/*; do
    if [ "$config" != "/etc/nginx/sites-available/$domain_name" ] && \
       [ -f "$config" ] && \
       grep -q "ssl-params.conf" "$config"; then
        ssl_params_in_use=true
        break
    fi
done

if [ "$ssl_params_in_use" = false ]; then
    echo "Removing ssl-params.conf..."
    sudo rm -f /etc/nginx/conf.d/ssl-params.conf
    check_status "SSL parameters file removal"
else
    echo "ssl-params.conf is still used by other sites, keeping it..."
fi

# Check if dhparam.pem is used by other sites
echo "Checking if dhparam.pem is still needed..."
dhparam_in_use=false
for config in /etc/nginx/sites-available/*; do
    if [ "$config" != "/etc/nginx/sites-available/$domain_name" ] && \
       [ -f "$config" ] && \
       grep -q "ssl_dhparam" "$config"; then
        dhparam_in_use=true
        break
    fi
done

if [ "$dhparam_in_use" = false ]; then
    echo "Removing dhparam.pem..."
    sudo rm -f /etc/nginx/dhparam.pem
    check_status "DH parameters file removal"
else
    echo "dhparam.pem is still used by other sites, keeping it..."
fi

# Remove any SSL-related certbot renewal configurations
echo "Removing Certbot renewal configurations..."
sudo rm -f "/etc/letsencrypt/renewal/$domain_name.conf"
check_status "Renewal configuration removal"

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t
check_status "Nginx configuration test"

# Restart Nginx
echo "Restarting Nginx..."
sudo systemctl restart nginx
check_status "Nginx restart"

echo "========== SSL CLEANUP COMPLETE =========="
echo "✓ SSL certificates removed"
echo "✓ Nginx SSL configuration removed"
echo "✓ Certbot renewal configuration removed"
echo
echo "A backup of your original configuration has been saved to:"
echo "/etc/nginx/sites-available/${domain_name}.backup_${timestamp}"
echo
echo "Your site should now be accessible via HTTP only:"
echo "http://$domain_name"
echo "===================================="

# Test HTTP access
echo "Testing HTTP access..."
if curl -s -I "http://$domain_name" | grep -q "200 OK"; then
    echo "✓ HTTP is working correctly"
else
    echo "! Warning: HTTP test failed. Please check your Nginx configuration"
    echo "  and make sure the site is properly configured."
fi
