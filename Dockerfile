# --- Estágio 1: Build do Frontend ---
FROM node:20-alpine AS frontend-builder

# Instala o PHP e o Composer necessários para o plugin Wayfinder do Laravel
RUN apk add --no-cache php83 php83-phar php83-mbstring php83-openssl php83-xml php83-tokenizer php83-dom php83-session curl
RUN curl -sS https://getcomposer.org/installer | php83 -- --install-dir=/usr/local/bin --filename=composer
RUN ln -s /usr/bin/php83 /usr/bin/php

WORKDIR /app
# Precisamos do backend completo (incluindo vendor) para o Wayfinder funcionar
COPY backend /backend
WORKDIR /backend
RUN composer install --no-dev --optimize-autoloader

# Agora sim, voltamos para o frontend
WORKDIR /app
COPY frontend /app
RUN npm install
RUN npm run build

# --- Estágio 2: PHP & Nginx ---
FROM serversideup/php:8.2-fpm-nginx

# Configurações do PHP
ENV PHP_OPCACHE_ENABLE=1 \
    AUTORUN_ENABLED=true

# Copia o código do backend
WORKDIR /var/www/html
COPY --chown=www-data:www-data backend/ .

# Copia os assets compilados do estágio anterior
COPY --from=frontend-builder --chown=www-data:www-data /app/public/build ./public/build

# Instala dependências do Composer
RUN composer install --no-dev --optimize-autoloader

# Script de inicialização (customizado)
COPY --chown=www-data:www-data scripts/deploy.sh /var/www/html/scripts/deploy.sh
RUN chmod +x /var/www/html/scripts/deploy.sh

# Render espera que a porta seja configurada via variável de ambiente PORT
# O serversideup já lida com isso por padrão se usarmos o entrypoint correto
