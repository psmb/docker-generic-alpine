#!/usr/bin/env bash
set -ex

# Provision conainer at first run
if [ -f /data/www/composer.json ] || [ -z "$REPOSITORY_URL" ]
then
	echo "Do nothing, initial provisioning done"
else
    # Layout default directory structure
    mkdir -p /data/www
    mkdir -p /data/logs
    mkdir -p /data/tmp/nginx

    ###
    # Install into /data/www
    ###
    cd /data/www
    git clone -b $VERSION $REPOSITORY_URL .
    composer install --prefer-source

    # Set permissions
    chown www-data:www-data -R /tmp/
	chown www-data:www-data -R /data/
	chmod g+rwx -R /data/

	# Set ssh permissions
	if [ -z "/data/.ssh/authorized_keys" ]
		then
			chown www-data:www-data -R /data/.ssh
			chmod go-w /data/
			chmod 700 /data/.ssh
			chmod 600 /data/.ssh/authorized_keys
	fi
fi
