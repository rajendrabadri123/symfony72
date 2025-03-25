# Build stage
FROM composer:2.6 as builder

WORKDIR /app
COPY . .
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction

# Development stage
FROM php:8.3-fpm-alpine as dev

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    libzip-dev \
    icu-dev \
    postgresql-dev \
    oniguruma-dev \
    libpng-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxml2-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install -j$(nproc) \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    opcache \
    zip \
    intl \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    xml

# Install Composer
COPY --from=composer:2.6 /usr/bin/composer /usr/bin/composer

# Create non-root user
RUN addgroup -g 1000 symfony && \
    adduser -u 1000 -G symfony -h /home/symfony -D symfony && \
    mkdir -p /var/www && \
    chown symfony:symfony /var/www

WORKDIR /var/www
USER symfony

# Health check endpoint
RUN mkdir -p public && echo "<?php echo 'OK';" > public/health

CMD ["php-fpm"]

# Production stage
FROM dev as prod

# Copy application files
COPY --chown=symfony:symfony --from=builder /app /var/www

# Optimize Symfony for production
RUN php bin/console cache:warmup --env=prod && \
    chmod -R 0755 var && \
    chown -R symfony:symfony var

# Use FPM with production configuration
CMD ["php-fpm", "--allow-to-run-as-root"]
