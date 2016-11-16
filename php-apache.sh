#!/bin/bash -f

# We'll need our username
USERNAME=`whoami`

# Extra Brew Taps
brew tap homebrew/dupes
brew tap homebrew/versions
brew tap homebrew/php
brew tap homebrew/apache

# Update again just in case.
brew update


# Apache
# First we stop the default apache and install a new apache with brew.
# @See https://getgrav.org/blog/macos-sierra-apache-multiple-php-versions
sudo apachectl stop
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
brew install httpd24 --with-privileged-ports --with-http2

# Start apache now and on startup.
sudo brew services start homebrew/apache/httpd24

# Modify Apache Configs
sudo sed -i "" "s~Listen 8080~Listen 80~g" /usr/local/etc/apache2/2.4/httpd.conf # Ensure apache is set to port 80
sudo sed -i "" "s~#LoadModule vhost_alias_module~LoadModule vhost_alias_module~g" /usr/local/etc/apache2/2.4/httpd.conf # Enable vhost module
sudo sed -i "" "s~#LoadModule rewrite_module~LoadModule rewrite_module~g" /usr/local/etc/apache2/2.4/httpd.conf # Enable rewrite module

# Setup apache to use proper Users and Group.
sudo sed -i "" "s~User _www~User $USERNAME~g" /usr/local/etc/apache2/2.4/httpd.conf
sudo sed -i "" "s~Group _www~Group staff~g" /usr/local/etc/apache2/2.4/httpd.conf
sudo sed -i "" "s~User daemon~User $USERNAME~g" /usr/local/etc/apache2/2.4/httpd.conf
sudo sed -i "" "s~Group daemon~Group staff~g" /usr/local/etc/apache2/2.4/httpd.conf
sudo sed -i "" s~/Library/WebServer/Documents~/Users/$USERNAME/Sites~g /usr/local/etc/apache2/2.4/httpd.conf
sudo sed -i "" s~/usr/local/var/www/htdocs~/Users/$USERNAME/Sites~g /usr/local/etc/apache2/2.4/httpd.conf

# Set Apache to process php files.
perl -i -0pe 's~<IfModule dir_module>\
.*\
</IfModule>~\
<IfModule dir_module>\
    DirectoryIndex index.php index.html\
</IfModule>\
\
<FilesMatch \\.php\$>\
    SetHandler application/x-httpd-php\
</FilesMatch>~' /usr/local/etc/apache2/2.4/httpd.conf

# Enable .htaccess files
sudo sed -i "" 's~AllowOverride NoneAllowOverride all~g' /usr/local/etc/apache2/2.4/httpd.conf

# Normalize logging to use /var/log/apache2
sudo sed -i "" 's~ErrorLog "/usr/local/var/log/apache2/error_log"~ErrorLog "/var/log/apache2/error_log"~g' /usr/local/etc/apache2/2.4/httpd.conf
sudo sed -i "" 's~CustomLog "/usr/local/var/log/apache2/access_log" common~CustomLog "/var/log/apache2/access_log" common~g' /usr/local/etc/apache2/2.4/httpd.conf

# Add extra sites config 
echo "Include /usr/local/etc/apache2/2.4/sites.conf" | sudo tee -a /usr/local/etc/apache2/2.4/httpd.conf

# Setup basic sites.conf vhosts.
sudo touch /usr/local/etc/apache2/2.4/sites.conf
sudo tee /usr/local/etc/apache2/2.4/sites.conf >/dev/null <<EOF
# Workaround for missing Authorization header under CGI/FastCGI Apache:
<IfModule setenvif_module>
  SetEnvIf Authorization .+ HTTP_AUTHORIZATION=$0
</IfModule>

# Serve ~/Sites at http://localhost
ServerName localhost

<VirtualHost *:80>
  ServerName localhost
  DocumentRoot /Users/$USERNAME/Sites
</VirtualHost>

# Serve ~/Sites/laravel/* at http://*.laravel.localhost
<VirtualHost *:80>
  ServerName laravel.localhost
  ServerAlias *.laravel.localhost
  VirtualDocumentRoot /Users/$USERNAME/Sites/laravel/%1/laravel/public
  DirectoryIndex index.php
</VirtualHost>
EOF


# Create start phpinfo file
touch $HOME/Sites/phpinfo.php
tee $HOME/Sites/phpinfo.php >/dev/null <<EOF
<?php phpinfo();
EOF

# Start PHP installations.
brew install php56 --with-apache --with-postgresql --with-phpdbg --with-mssql --with-pear --with-phpdbg
brew install php56-couchbase php56-event php56-gearman php56-geoip php56-kafka php56-imagick php56-mcrypt php56-mongodb php56-pdo-pgsql php56-redis php56-solr php56-xdebug php56-yaml
brew unlink php56

brew install php70 --with-apache --with-postgresql --with-phpdbg --with-mssql --with-pear --with-phpdbg
brew install php70-couchbase php70-event php70-gearman php70-geoip php70-kafka php70-imagick php70-mcrypt php70-mongodb php70-pdo-pgsql php70-redis php70-solr php70-xdebug php70-yaml

# Get sphp
curl -L https://raw.githubusercontent.com/sgotre/sphp-osx/master/sphp > /usr/local/bin/sphp
chmod +x /usr/local/bin/sphp

# Get Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin
mv /usr/local/bin/composer.phar /usr/local/bin/composer

# Restart Apache
sudo apachectl -k restart