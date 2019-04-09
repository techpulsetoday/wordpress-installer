#!/bin/bash

# Text Reset
RESET='\e[0m'
BLINK='\e[5m'

# Regular Colors
BLACK='\e[0;30m'
RED='\e[0;31m'
BRED='\e[1;31m'
GREEN='\e[0;32m'
BGREEN='\e[1;32m'
YELLOW='\e[0;33m'
BYELLOW='\e[1;33m'
BLUE='\e[0;34m'
BBLUE='\e[1;34m'
PURPLE='\e[0;35m'
CYAN='\e[0;36m'
BCYAN='\e[1;36m'
WHITE='\e[0;37m'

clear
echo -e "${CYAN}=================================================================${RESET}"
echo -e "${GREEN}                 Awesome WordPress Installer!!                  ${RESET}"
echo -e "${CYAN}=================================================================${RESET}"

read -p "Enter DB Name  : " db_name
read -p "Enter ROOT DB Username  : " db_username
read -p "Enter ROOT DB Password  : " db_password
read -p "Enter DB table prefix  : " db_prefix
read -p "Enter the Domain Name (e.g. techpulsetoday.com)  : " domain_name
read -p "Enter Site Title  : " site_title
read -p "Enter Site Email  : " site_email
read -p "Enter Site Admin Username  : " site_username
read -p "Do you want to generate random 12 character password? (y/n)  : " run

if [ "${run}" == n ] ; then
    read -p "Enter Site Admin Password  : " site_password
else
    # Generate random 12 character password
    site_password=$(LC_CTYPE=C tr -dc A-Za-z0-9_\!\@\#\$\%\^\&\*\(\)-+= < /dev/urandom | head -c 12)
fi

echo -e "${CYAN}=================================================================${RESET}"
echo
echo -e "${BCYAN}Creating a VirtualHost file...${RESET}"
sitesEnabled='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'
sitesAvailabledomain_name="${sitesAvailable}${domain_name}.conf"
userDir='/var/www/html/'
rootDir="${userDir}${domain_name}"

# Check if domain already exists
if [ -e "${sitesAvailabledomain_name}" ]; then
    echo -e $"This domain already exists.\nPlease Try Another one"
    exit;
fi

# Create virtualhost rules file
vhost="<VirtualHost *:80>
    ServerAdmin ${site_email}
    ServerName ${domain_name}
    ServerAlias ${domain_name}
    DocumentRoot ${rootDir}
    <Directory ${rootDir}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride all
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/${domain_name}-error.log
    LogLevel error
    CustomLog /var/log/apache2/${domain_name}-access.log combined
</VirtualHost>"
echo "${vhost}" | sudo tee "${sitesAvailabledomain_name}" > /dev/null
echo -e "${BGREEN}Success: ${RESET}Generated '${domain_name}.conf' VirtualHost file."

# Add Domain Name in /etc/hosts
echo "127.0.0.1    ${domain_name}" | sudo tee -a /etc/hosts > /dev/null
echo -e "${BGREEN}Success: ${RESET}Added ${domain_name} in /etc/hosts file."
echo
echo -e "${BCYAN}Enabling the site...${RESET}"
# Enable website
sudo a2ensite "${domain_name}"
echo -e "${BGREEN}Success: ${RESET}Enabled site ${domain_name}."
echo
echo -e "${BCYAN}Restarting Apache2...${RESET}"
# Restart Apache
sudo /etc/init.d/apache2 restart
echo -e "${BGREEN}Success: ${RESET}Apache restarted."
echo

if ! [ -f /usr/local/bin/wp ]; then
    echo -e "${BCYAN}Installing WP CLI...${RESET}"
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    php wp-cli.phar --info
    chmod +x wp-cli.phar
    sudo -u root mv wp-cli.phar /usr/local/bin/wp
    echo -e "${BGREEN}Success: ${RESET}WP CLI Installed Successfully."
    echo
fi

if ! [ -f /home/$USER/wp-completion.bash ]; then
    echo -e "${BCYAN}Installing WP CLI Completion...${RESET}"
    cd ~/
    wget -N https://github.com/wp-cli/wp-cli/raw/master/utils/wp-completion.bash
    echo 'source /home/$USER/wp-completion.bash' >> ~/.bashrc
    source ~/.bashrc
    echo -e "${BGREEN}Success: ${RESET}WP CLI Completion Installed Successfully."
    echo
fi

# Check if directory exists or not
if ! [ -d "${rootDir}" ]; then
    # Create the directory
    sudo mkdir "${rootDir}"
    cd "${rootDir}"

    # Give permission to root dir
    sudo chown -R $USER:www-data "${rootDir}"
    sudo find "${rootDir}" -type d -exec chmod 755 {} \;
    sudo find "${rootDir}" -type f -exec chmod 644 {} \;

    echo -e "${BCYAN}Downloading WordPress Core...${RESET}"
    # Download WordPress Core
    wp core download

    # Create WordPress wp-config.php
    wp config create --dbname="${db_name}" --dbuser="${db_username}" --dbpass="${db_password}" --dbprefix="${db_prefix}"

    # Create WordPress DB
    wp db create

    echo
    echo -e "${BCYAN}Installing WordPress...${RESET}"
    # Install WordPress
    wp core install --url="${domain_name}" --title="${site_title}" --admin_user="${site_username}" --admin_password="${site_password}" --admin_email="${site_email}"

    echo
    read -p "Do you want install the theme (y/n)?  : " install_theme

    if [ "${install_theme}" == y ]; then
        read -p "Do you have child theme (y/n)?  : " child_theme
        if [ "${child_theme}" == y ]; then
            read -p "Enter parent theme slug or url or path  : " theme_path
            read -p "Enter child theme slug or url or path  : " child_theme_path
            wp theme install "${theme_path}"
            wp theme install "${child_theme_path}" --activate
        else
            read -p "Enter theme slug or url or path  : " theme_path
            wp theme install "${theme_path}" --activate
        fi
    fi

    # Create htaccess file
htaccess="apache_modules:
  - mod_rewrite"
    echo "${htaccess}" | sudo tee "${rootDir}"/wp-cli.yml > /dev/null
    echo
    echo -e "${BCYAN}Generating wp-cli.yml and .htaccess file...${RESET}"
    echo -e "${BGREEN}Success: ${RESET}Generated 'wp-cli.yml' config file."

    #  Flush the permalinks
    wp rewrite structure '/%postname%/' --hard

    # Give permission to root dir
    sudo chown -R $USER:www-data "${rootDir}"
    sudo find "${rootDir}" -type d -exec chmod 755 {} \;
    sudo find "${rootDir}" -type f -exec chmod 644 {} \;
else
    echo -e "${BRED}Error: ${RESET}${rootDir} already exists"
fi

clear
echo -e "${CYAN}=================================================================${RESET}"
echo -e "${GREEN}Installation is complete. Your username/password is listed below.${RESET}"
echo
echo -e "${BYELLOW}Username: ${RESET}${PURPLE}${site_username}${RESET}"
echo -e "${BYELLOW}Password: ${RESET}${PURPLE}${site_password}${RESET}"
echo -e "${BYELLOW}Site URL: ${RESET}${BBLUE}${BLINK}http://${domain_name}${RESET}"
echo
echo -e "${CYAN}=================================================================${RESET}"
