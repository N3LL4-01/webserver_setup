#!/bin/bash

# --------------------------------------------------------------------------------

# App		Base system tool
# Version:	0.1 / 0 2
# Date:		05.10.2021
# File:		webserver_base.sh	
# Author:       Ornella 

# --------------------------------------------------------------------------------

APP_TITLE='Base system tool'

# --------------------------------------------------------------------------------

# --- DEFINE: Version
VERSION=0.1

# --- DEFINE: Adding PPA if it doesn't exist
php_ppa="ondrej/php"
if ! grep -q "^deb .*$php_ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    sudo add-apt-repository ppa:ondrej/php
    sudo apt-get update
fi

# --- DEFINE: Packages
APACHE_PACKAGES='apache2-mpm-worker apache2-suexec libapache2-mod-fcgid sudo apt-get install --reinstall apache2 apache2-utils'
COMMON_PACKAGES='bzip2 dialog less mc ntpdate openssh-blacklist openssh-blacklist-extra openssh-client openssh-server openssl openssl-blacklist ssh subversion webalizer whois unzip'
PHP_PACKAGES='php7.4-fpm php7.4-common php7.4-mysql php7.4-xml php7.4-xmlrpc php7.4-curl php7.4-gd php7.4-imagick php7.4-cli php7.4-dev php7.4-imap php7.4-mbstring php7.4-opcache php7.4-soap php7.4-zip php7.4-intl'
MYSQL_PACKAGES='mysql-server aptitude install mysql-server'

# --------------------------------------------------------------------------------

# --- DEFINE: root and config-dir
TEMPROOTDIR="$(dirname $0)"
echo ${TEMPROOTDIR} | grep '^/' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
	ROOTDIR="${TEMPROOTDIR}"
else
	ROOTDIR="$(pwd)/$(dirname $0)"
fi
CONF_DIR="${ROOTDIR}/conf"

# --------------------------------------------------------------------------------

# --- CHECK: Check for dialog app
if [ -f /usr/bin/dialog ] ; then
	echo 'Starting application ...'
else
	echo 'Need dialog ... try to install it ...'
	aptitude -y install dialog
fi

# --------------------------------------------------------------------------------

# --- SETTER: Set tmp-file
_TEMP="/tmp/innomedia.base-system.$$"

# --------------------------------------------------------------------------------

# --- HELPER: Clear the screen and exit all
clear_and_exit () {
	clear
	exit
}

# --- CONFIGURATION: All configuration in one function
configure () {
	clear
	configure_system
	configure_apache
	configure_php5
	configure_mysql
}

# --- CONFIGURATION: Apache
configure_apache () {
	echo 'Start configuration of apache2 ...'
	# Configuration files
	rm -f /etc/apache2/cond.d/*
	rm -f /etc/apache2/sites-available/*
	rm -f /etc/apache2/sites-enabled/*
	cp -r ${CONF_DIR}/etc/apache2/* /etc/apache2/
	ln -s /etc/apache2/sites-available/*conf /etc/apache2/sites-enabled/
	HOSTNAME=`hostname`
	cat > /etc/apache2/conf.d/100-servername.conf << EOF
#
# The ServerName directive sets the hostname and
# port that the server uses to identify itself.
#
# You can see more (configuration etc.) at the docs
# of apache:
# http://httpd.apache.org/docs/2.0/en/mod/core.html#servername
#
ServerName ${HOSTNAME}
EOF
	# Modules
	if [ ! -h /etc/apache2/mods-enabled/rewrite.load ]; then
		ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/
	fi
	/etc/init.d/apache2 restart
}

# --- CONFIGURATION: MySQL
configure_mysql () {
	echo 'Start configuration of MySQL5 ...'
	cp -r ${CONF_DIR}/etc/mysql/* /etc/mysql/
	/etc/init.d/mysql restart
}

# --- CONFIGURATION: PHP5
configure_php5 () {
	echo 'Start configuration of PHP7.4 ...'
	cp -r ${CONF_DIR}/etc/php7.4/* /etc/php7.4/
}

# --- CONFIGURATION: Base system, crons etc.
configure_system () {
	echo 'Start configuration of the system ...'
	cp ${CONF_DIR}/root/.bashrc /root/
	cp -r ${CONF_DIR}/etc/cron.d/* /etc/cron.d/
	chmod 700 /etc/cron.d/*
	cp -r ${CONF_DIR}/etc/cron.hourly/* /etc/cron.hourly/
	chmod 700 /etc/cron.hourly/*
	/etc/cron.hourly/ntpdate
	cp -r ${CONF_DIR}/usr/local/* /usr/local/
	chown -R root: /usr/local/innomedia/
	chmod -R 700 /usr/local/innomedia/
}

# --- HELPER: Set the height and the width of each screen
set_screen_height_width () {
	let "SCREEN_HEIGHT_HI=$(tput lines)-5"
	SCREEN_HEIGHT_LO=15
	if [ ${SCREEN_HEIGHT_HI} -lt ${SCREEN_HEIGHT_LO} ] ; then
		SCREEN_HEIGHT_HI=${SCREEN_HEIGHT_LO}
	fi
	let "SCREEN_WIDTH_HI=$(tput cols)"
	SCREEN_WIDTH_LO=90
	if [ ${SCREEN_WIDTH_HI} -lt ${SCREEN_WIDTH_LO} ] ; then
		SCREEN_WIDTH_HI=${SCREEN_WIDTH_LO}
	fi
}

# --- GUI: Choose the first action
gui_choose_main_action () {
	if [ -f /usr/local/innomedia/webserver.version ] ; then
		dialog	--backtitle "${APP_TITLE}" \
						--title 'Start' \
						--cancel-label 'Quit' \
						--menu 'Choose your action:' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 2 \
						0 'Update system' \
						1 'Reconfigure system' 2> ${_TEMP}
		case ${?} in
			0) 
				MAIN_ACTION=`cat ${_TEMP}`
				rm -f ${_TEMP}
				case ${MAIN_ACTION} in
					0) gui_helper_update_system;;
					1) gui_configure_system;;
				esac
				;;
			1) clear_and_exit;;
		esac
	else
		dialog	--backtitle "${APP_TITLE}" \
						--title 'Start' \
						--cancel-label 'Quit' \
						--menu 'Choose your action:' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 2 \
						0 'Install system' 2> ${_TEMP}
		case ${?} in
			0) 
				MAIN_ACTION=`cat ${_TEMP}`
				rm -f ${_TEMP}
				case ${MAIN_ACTION} in
					0) gui_install_system;;
				esac
				;;
			1) clear_and_exit;;
		esac
	fi
}
# --- GUI: Configure the system
gui_configure_system () {
	configure
	dialog	--backtitle "${APP_TITLE}" \
					--title "Base system / Configure" \
					--ok-label 'Back' \
					--msgbox 'System successfully configured.' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
	gui_choose_main_action
}

# --- GUI: Install the system
gui_install_system () {
	helper_update_system
	helper_install_or_update_packages
	helper_make_dirs
	echo 'Enable module ...'
	a2enmod fcgid
	a2enmod suexec
	/etc/init.d/apache2 restart
	mkdir -p /usr/local/innomedia
	cat > /usr/local/innomedia/webserver.version << EOF
${VERSION}
EOF
dialog	--backtitle "${APP_TITLE}" \
				--title "Base system / Installation" \
				--ok-label 'Ok' \
				--msgbox 'System successfully installed, starting configuration.' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
	gui_configure_system
}

# --- GUI: Update the system
gui_helper_update_system () {
	helper_update_system
	helper_install_or_update_packages
	dialog	--backtitle "${APP_TITLE}" \
					--title "Base system / Update" \
					--ok-label 'Back' \
					--msgbox 'System successfully updated.' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
	gui_choose_main_action
}

# --- HELPER: Install or update all defined packages
helper_install_or_update_packages () {
	echo 'Start installation / update of all defined packages ...'
	aptitude install -y ${COMMON_PACKAGES} ${APACHE_PACKAGES} ${PHP_PACKAGES} ${MYSQL_PACKAGES}
}

# --- HELPER: Create necessary dirs
helper_make_dirs () {
	echo 'Create dirs ...'
	mkdir -p /var/www/default
	mkdir -p /var/www/production/vhosts
	mkdir -p /var/www/testing/vhosts
}

# --- HELPER: Update system
helper_update_system () {
	clear
	echo 'Start system update ...'
	cp -r ${CONF_DIR}/etc/apt/* /etc/apt/
	aptitude update
	aptitude safe-upgrade
	aptitude dist-upgrade
}

# --------------------------------------------------------------------------------

main_menu () {
	set_screen_height_width
	gui_choose_main_action
}

# --------------------------------------------------------------------------------

while true; do
	main_menu
done
