## Hetzner Scripts
This repo holds some scripts that will help you set up multiple wordpress instances on a single Ubuntu server.
While this was created for Hetzner Cloud instances, it will work for any Ubuntu based server where you have SSH access.


## Prerequisites 
* Ubuntu 22.04
* NGINX
* MYSQL-SERVER
* PHP 7.4 -> php7.4-cli php7.4-common php7.4-json php7.4-opcache php7.4-mysql php7.4-mbstring php7.4-mcrypt php7.4-zip
* Domains pointing at ubuntu server with A and CNAME record

## Setup New Wordpress Site
Run ./setup_new_wordpress.sh, as the root user, and fill in the prompts
You are required to fill in two pieces of information:
* the domain name e.g. mycooldomain.com
* the root password to your mysql server, this is needed to set up separate databases per wordpress instance

Upon completion of the script, you'll get the following output:
```
========== INSTALLATION COMPLETE ==========
Website: http://mycooldomain.com
Database Name: mycooldomain_com
Database User: mycooldomain_user
Database Password: eBIq5XanRaHmgpxi
Credentials saved in: /random/path/.mycooldomain.com_credentials.txt
=========================================
You can now complete the WordPress installation by visiting http://mycooldomain.com
```

You can no go ahead and access your website over HTTP only, assuming you pointed your domain to this server.

## Enable HTTPS and create SSL certificate
Run ./enable_https.sh mycooldomain.com as the root user on the server.
You'll then be prompted to provide an email address
```
Enter email address for SSL certificate registration: mycoolemail@gmail.com
```

Upon completion of the script you'll get this summary:
```
========== SSL SETUP COMPLETE ==========
Domain: jan-schwoebel.com
✓ SSL certificate installed
✓ HTTPS configured
✓ Security headers added
✓ Auto-renewal configured
✓ Nginx optimized for SSL

Your site is now accessible via HTTPS:
https://jan-schwoebel.com
A backup of your original configuration has been saved to:
/etc/nginx/sites-available/jan-schwoebel.com.backup
====================================
Testing HTTPS access...
✓ HTTPS is working correctly
```

## Clean up HTTPS config for a specific domain
Run ./cleanup_https.sh mycooldomain.com as the root user on the server.
You'll then be prompted if you want to delete the follwoing

```
WARNING: This will remove SSL configuration for mycooldomain.com
This includes:
- Let's Encrypt certificates
- SSL-related Nginx configurations
- SSL parameter files (if not used by other domains)

Are you sure you want to continue? (y/N): y
```

At the end you should see the following
```
========== SSL CLEANUP COMPLETE ==========
✓ SSL certificates removed
✓ Nginx SSL configuration removed
✓ Certbot renewal configuration removed

A backup of your original configuration has been saved to:
/etc/nginx/sites-available/mycooldomain.com.backup_20241223_121646

Your site should now be accessible via HTTP only:
http://mycooldomain.com
====================================
Testing HTTP access...
✓ HTTP is working correctly
```

## Clean up a Wordpress instance after you ran cleanup_https.sh
Run ./cleanup_wordpress.sh mycooldomain.com as the root user.
You'll get an overview of everything that's going to be deleted and are prompt to answer with Y. Additionally, you'll need to have your mysql root password handy again.

```
./cleanup_wordpress.sh mycooldomain.com
WARNING: This will completely remove the WordPress site at mycooldomain.com
This includes:
- All website files
- Database and database user
- Nginx configuration
- SSL certificates (if any)

Are you sure you want to continue? (y/N): y
Starting cleanup for mycooldomain.com...
Removing database and user...
Enter password:
```

Upon completion of the script, you'll see the following message, letting you know it was successful:

```
========== CLEANUP COMPLETE ==========
The following items have been removed:
✓ Website files from /var/www/html/mycooldomain.com
✓ Database 'mycooldomain_com' and user 'mycooldomain_user'
✓ Nginx configuration for mycooldomain.com
✓ SSL certificates (if they existed)
✓ Credentials file
✓ Backup files

The site mycooldomain.com has been completely removed from the system.
====================================
```
