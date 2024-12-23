## Hetzner Scripts
This repo holds some scripts that will help you set up multiple wordpress instances on a single Ubuntu server.
While this was created for Hetzner Cloud instances, it will work for any Ubuntu based server where you have SSH access.


## Prerequisites 
* Ubuntu 22.04
* NGINX
* MYSQL-SERVER
* PHP 7.4 -> php7.4-cli php7.4-common php7.4-json php7.4-opcache php7.4-mysql php7.4-mbstring php7.4-mcrypt php7.4-zip
* Domains pointing at ubuntu server with A and CNAME record

## Setup New Wordpress 
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
