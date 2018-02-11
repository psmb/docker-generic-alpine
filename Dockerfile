FROM php:5.6-fpm-alpine3.4

MAINTAINER Dmitri Pisarev <dimaip@gmail.com>

ARG PHP_REDIS_VERSION="3.1.6"
ARG PHP_YAML_VERSION="2.0.2"
ARG PHP_XDEBUG_VERSION="2.6.0beta1"
ARG S6_VERSION="1.21.2.2"

ENV FLOW_REWRITEURLS 1

ENV COMPOSER_VERSION 1.6.2
ENV COMPOSER_HOME /composer
ENV PATH /composer/vendor/bin:$PATH
ENV COMPOSER_ALLOW_SUPERUSER 1

# Set default values for env vars used in init scripts, override them if needed
ENV DB_DATABASE db
ENV DB_HOST db
ENV DB_USER admin
ENV DB_PASS pass
ENV VERSION master

# Basic build-time metadata as defined at http://label-schema.org
LABEL org.label-schema.docker.dockerfile="/Dockerfile" \
	org.label-schema.license="MIT" \
	org.label-schema.name="Neos Alpine Docker Image" \
	org.label-schema.url="https://github.com/psmb/docker-neos-alpine" \
	org.label-schema.vcs-url="https://github.com/psmb/docker-neos-alpine" \
	org.label-schema.vcs-type="Git"

RUN set -x \
	&& apk update \
	&& apk add tar rsync curl sed bash yaml python py-pip py-setuptools groff less freetype mysql-client git nginx icu-dev libjpeg-turbo-utils  openssh pwgen sudo s6 \
	&& pip install awscli \
	&& apk del py-pip py-setuptools \
	&& apk add --virtual .phpize-deps $PHPIZE_DEPS libtool freetype-dev libpng-dev libjpeg-turbo-dev yaml-dev \
	&& docker-php-ext-configure gd \
	--with-gd \
	--with-freetype-dir=/usr/include/ \
	--with-png-dir=/usr/include/ \
	--with-jpeg-dir=/usr/include/ \
	&& docker-php-ext-install \
	gd \
	pdo \
	pdo_mysql \
	mysql \
	mbstring \
	opcache \
	intl \
	exif \
	json \
	tokenizer \
	&& apk del .phpize-deps \
	&& curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
	&& php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} && rm -rf /tmp/composer-setup.php \
	&& git config --global user.email "server@server.com" \
	&& git config --global user.name "Server" \
	&& rm -rf /var/cache/apk/*

# Copy configuration
COPY root /

# Download s6
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz /tmp/

RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / && rm /tmp/s6-overlay-amd64.tar.gz \
	&& echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini \
	&& echo "memory_limit=${PHP_MEMORY_LIMIT:-2048M}" > $PHP_INI_DIR/conf.d/memory_limit.ini \
	&& echo "upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE:-512M}" > $PHP_INI_DIR/conf.d/upload_max_filesize.ini \
	&& echo "post_max_size=${PHP_UPLOAD_MAX_FILESIZE:-512M}" > $PHP_INI_DIR/conf.d/post_max_size.ini \
	&& echo "allow_url_include=${PHP_ALLOW_URL_INCLUDE:-1}" > $PHP_INI_DIR/conf.d/allow_url_include.ini \
	&& echo "max_execution_time=${PHP_MAX_EXECUTION_TIME:-240}" > $PHP_INI_DIR/conf.d/max_execution_time.ini \
	&& echo "max_input_vars=${PHP_MAX_INPUT_VARS:-1500}" > $PHP_INI_DIR/conf.d/max_input_vars.ini \
	&& deluser www-data \
	&& delgroup cdrw \
	&& addgroup -g 80 www-data \
	&& adduser -u 80 -G www-data -s /bin/bash -D www-data -h /data \
	&& rm -Rf /home/www-data \
	&& sed -i -e "s#listen = 9000#listen = /var/run/php-fpm.sock#" /usr/local/etc/php-fpm.d/zz-docker.conf \
	&& echo "clear_env = no" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
	&& echo "listen.owner = www-data" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
	&& echo "listen.group = www-data" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
	&& echo "listen.mode = 0660" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
	&& chown 80:80 -R /var/lib/nginx \
	&& chmod +x /github-keys.sh \
	&& sed -i -r 's/.?UseDNS\syes/UseDNS no/' /etc/ssh/sshd_config \
	&& sed -i -r 's/.?PasswordAuthentication.+/PasswordAuthentication no/' /etc/ssh/sshd_config \
	&& sed -i -r 's/.?ChallengeResponseAuthentication.+/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config \
	&& sed -i -r 's/.?PermitRootLogin.+/PermitRootLogin no/' /etc/ssh/sshd_config \
	&& sed -i '/secure_path/d' /etc/sudoers \
	&& echo 'www-data ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/www

# Expose ports
EXPOSE 80 22

# Define working directory
WORKDIR /data

# Define entrypoint and command
ENTRYPOINT ["/init"]