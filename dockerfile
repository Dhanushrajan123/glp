# Check "require.php" in composer.json and match this version
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
      git unzip curl ca-certificates libzip-dev libpng-dev libjpeg-dev \
      libfreetype6-dev libicu-dev libldap2-dev libbz2-dev libxml2-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" mysqli gd intl zip bz2 ldap exif bcmath opcache \
 && a2enmod rewrite \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# GLPI serves from the public/ folder
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
 && printf '<Directory /var/www/html/public>\n AllowOverride All\n Require all granted\n</Directory>\n' \
    > /etc/apache2/conf-available/glpi.conf \
 && a2enconf glpi

WORKDIR /var/www/html
COPY . .

# Install PHP and JS dependencies, build assets, compile translations
RUN composer install --no-dev --optimize-autoloader --no-interaction \
 && npm ci \
 && npm run build \
 && php bin/console locales:compile || true

RUN chown -R www-data:www-data /var/www/html/files /var/www/html/config

EXPOSE 80
