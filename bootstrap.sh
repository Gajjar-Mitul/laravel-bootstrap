#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Help / Usage
# ============================================================
show_help() {
  cat <<'EOF'
Laravel Bootstrap CLI

Usage:
  ./bootstrap.sh --name=<project-name> [options]

Required:
  --name            Project name (used for directory and database)

Optional:
  --domain          Local domain (default: <name>.local)
  --php             PHP version (default: 8.3)
  --help            Show this help message

Description:
  Instantly bootstrap a Laravel project on Linux with:
  - nginx vhost
  - SSL (mkcert if available)
  - MySQL database
  - PHP-FPM configuration
EOF
}

# ============================================================
# Early exit for --help
# ============================================================
for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

# ============================================================
# Parse CLI arguments
# ============================================================
NAME=""
DOMAIN=""
PHP_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name=*) NAME="${1#*=}" ;;
    --domain=*) DOMAIN="${1#*=}" ;;
    --php=*) PHP_VERSION="${1#*=}" ;;
    *) echo "❌ Unknown option: $1"; exit 1 ;;
  esac
  shift
done

PHP_BIN="/usr/bin/php$PHP_VERSION"

if [[ ! -x "$PHP_BIN" ]]; then
  echo "❌ PHP $PHP_VERSION binary not found at $PHP_BIN"
  echo "👉 Install php$PHP_VERSION-cli"
  exit 1
fi


# ============================================================
# Validate & defaults
# ============================================================
[[ -z "$NAME" ]] && { echo "❌ --name is required"; exit 1; }

DOMAIN="${DOMAIN:-$NAME.local}"
PHP_VERSION="${PHP_VERSION:-8.3}"

BASE_PATH="$HOME/work/code"
PROJECT_PATH="$BASE_PATH/$NAME"
DB_NAME="${NAME//-/_}"

PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

echo "Resolved configuration:"
echo "  Project name : $NAME"
echo "  Domain       : $DOMAIN"
echo "  PHP version  : $PHP_VERSION"

# ============================================================
# Dependencies
# ============================================================
echo "🔍 Checking dependencies..."

command -v nginx >/dev/null || { echo "❌ nginx not installed"; exit 1; }
command -v composer >/dev/null || { echo "❌ composer not installed"; exit 1; }
command -v mysql >/dev/null || { echo "❌ mysql client missing"; exit 1; }
[[ -S "$PHP_FPM_SOCK" ]] || { echo "❌ PHP-FPM socket not found"; exit 1; }

echo "🔐 Requesting sudo access..."
sudo -v

# ============================================================
# Install Laravel
# ============================================================
echo "📁 Creating project directory..."
[[ -d "$PROJECT_PATH" ]] && { echo "❌ Directory exists"; exit 1; }
mkdir -p "$PROJECT_PATH"

echo "🚀 Installing Laravel..."
"$PHP_BIN" "$(command -v composer)" create-project laravel/laravel "$PROJECT_PATH"

echo "🔐 Fixing permissions..."

sudo chown -R "$USER:$USER" "$PROJECT_PATH"

sudo chown -R www-data:www-data \
  "$PROJECT_PATH/storage" \
  "$PROJECT_PATH/bootstrap/cache"

sudo chmod -R 775 \
  "$PROJECT_PATH/storage" \
  "$PROJECT_PATH/bootstrap/cache"


# ============================================================
# Laravel env
# ============================================================
ENV_FILE="$PROJECT_PATH/.env"

# Ensure .env exists
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$PROJECT_PATH/.env.example" "$ENV_FILE"
fi

# Basic app config
sed -i "s|^APP_NAME=.*|APP_NAME=\"$NAME\"|" "$ENV_FILE"
sed -i "s|^APP_URL=.*|APP_URL=https://$DOMAIN|" "$ENV_FILE"

# Force safe local defaults
sed -i "s|^SESSION_DRIVER=.*|SESSION_DRIVER=file|" "$ENV_FILE"
sed -i "s|^CACHE_STORE=.*|CACHE_STORE=file|" "$ENV_FILE"
sed -i "s|^QUEUE_CONNECTION=.*|QUEUE_CONNECTION=sync|" "$ENV_FILE"

# Generate key using selected PHP version
"$PHP_BIN" "$PROJECT_PATH/artisan" key:generate --force

# ============================================================
# Database
# ============================================================
echo "🗄️ Creating database..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4;"

sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|" "$ENV_FILE"
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" "$ENV_FILE"
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=root|" "$ENV_FILE"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=|" "$ENV_FILE"

# ============================================================
# Hosts
# ============================================================
echo "🌐 Updating hosts..."
grep -q "$DOMAIN" /etc/hosts || echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts >/dev/null

# ============================================================
# SSL (FIXED, SAFE LOCATION)
# ============================================================
echo "🔐 Generating SSL certificate..."

SSL_DIR="/etc/nginx/ssl"
CERT_PATH="$SSL_DIR/$NAME.crt"
KEY_PATH="$SSL_DIR/$NAME.key"

TMP_CERT="/tmp/$NAME.crt"
TMP_KEY="/tmp/$NAME.key"

sudo mkdir -p "$SSL_DIR"

if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
  if command -v mkcert >/dev/null 2>&1; then
    echo "🔒 Using mkcert for trusted local SSL"
    mkcert -cert-file "$TMP_CERT" -key-file "$TMP_KEY" "$DOMAIN"
  else
    echo "⚠️ mkcert not found, generating self-signed certificate"
    sudo openssl req -x509 -nodes -days 365 \
      -newkey rsa:2048 \
      -keyout "$TMP_KEY" \
      -out "$TMP_CERT" \
      -subj "/CN=$DOMAIN"
  fi

  [[ -f "$TMP_CERT" && -f "$TMP_KEY" ]] || {
    echo "❌ SSL temp files not created"
    exit 1
  }

  sudo mv "$TMP_CERT" "$CERT_PATH"
  sudo mv "$TMP_KEY" "$KEY_PATH"

  sudo chmod 644 "$CERT_PATH"
  sudo chmod 600 "$KEY_PATH"
fi

[[ -f "$CERT_PATH" && -f "$KEY_PATH" ]] || {
  echo "❌ SSL generation failed"
  exit 1
}

echo "✅ SSL ready"

# ============================================================
# nginx vhost (NOW SAFE)
# ============================================================
echo "🧩 Creating nginx vhost..."

VHOST="/etc/nginx/sites-available/$DOMAIN"

sudo tee "$VHOST" >/dev/null <<EOF
server {
    listen 80;
    listen 443 ssl http2;
    server_name $DOMAIN;

    root $PROJECT_PATH/public;
    index index.php index.html;

    ssl_certificate     /etc/nginx/ssl/$NAME.crt;
    ssl_certificate_key /etc/nginx/ssl/$NAME.key;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_FPM_SOCK;
    }
}
EOF

sudo ln -sf "$VHOST" /etc/nginx/sites-enabled/$DOMAIN

sudo nginx -t
sudo systemctl reload nginx

# ============================================================
# Done
# ============================================================
echo "🎉 Laravel project ready!"
echo "🌐 https://$DOMAIN"

command -v xdg-open >/dev/null && xdg-open "https://$DOMAIN" >/dev/null 2>&1 || true
