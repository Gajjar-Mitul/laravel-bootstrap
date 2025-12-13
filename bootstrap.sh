#!/usr/bin/env bash
set -e

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

Requirements:
  - Linux (Ubuntu recommended)
  - nginx
  - PHP + PHP-FPM
  - composer
  - mysql / mariadb
  - sudo access

Examples:
  ./bootstrap.sh --name=my-app
  ./bootstrap.sh --name=my-app --php=8.2
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
# Laravel Bootstrap Script
# ============================================================
# Usage:
# ./bootstrap.sh --name=my-app [--domain=my-app.local] [--php=8.3]
#
# What this script does (high level):
#  1. Parse and validate CLI arguments
#  2. Validate system dependencies
#  3. Create a new Laravel project
#  4. Configure Laravel environment
#  5. Create MySQL database
#  6. Configure local domain & nginx
#  7. Enable HTTPS
#  8. Open project in browser
# ============================================================


# ============================================================
# STEP 1 — Parse CLI arguments
# ============================================================

NAME=""
DOMAIN=""
PHP_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name=*)
      NAME="${1#*=}"
      shift
      ;;
    --domain=*)
      DOMAIN="${1#*=}"
      shift
      ;;
    --php=*)
      PHP_VERSION="${1#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
  esac
done


# ============================================================
# STEP 2 — Validate required inputs & resolve defaults
# ============================================================

if [[ -z "$NAME" ]]; then
  echo "❌ --name is required"
  exit 1
fi

DOMAIN="${DOMAIN:-$NAME.local}"
PHP_VERSION="${PHP_VERSION:-8.3}"

echo "Resolved configuration:"
echo "  Project name : $NAME"
echo "  Domain       : $DOMAIN"
echo "  PHP version  : $PHP_VERSION"


# ============================================================
# STEP 3 — Validate system dependencies
# ============================================================

echo ""
echo "🔍 Checking system dependencies..."

command -v nginx >/dev/null 2>&1 || {
  echo "❌ nginx not found. Please install nginx first."
  exit 1
}

command -v composer >/dev/null 2>&1 || {
  echo "❌ composer not found. Please install composer."
  exit 1
}

command -v mysql >/dev/null 2>&1 || {
  echo "❌ mysql client not found."
  exit 1
}

echo "🔐 This script requires sudo access for hosts and nginx configuration."
sudo -v || {
  echo "❌ sudo authentication failed."
  exit 1
}

PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

if [[ ! -S "$PHP_FPM_SOCK" ]]; then
  echo "❌ PHP-FPM socket not found at $PHP_FPM_SOCK"
  echo "   Is php${PHP_VERSION}-fpm installed and running?"
  exit 1
fi

echo "✅ All dependencies satisfied."


# ============================================================
# STEP 4 — Create project directory & install Laravel
# ============================================================

echo ""
echo "📁 Creating project directory..."

BASE_PATH="$HOME/work/code"
PROJECT_PATH="$BASE_PATH/$NAME"

if [[ -d "$PROJECT_PATH" ]]; then
  echo "❌ Directory already exists: $PROJECT_PATH"
  exit 1
fi

mkdir -p "$PROJECT_PATH"

echo "🚀 Installing Laravel..."
composer create-project --prefer-dist laravel/laravel "$PROJECT_PATH" --no-scripts



# Disable Laravel default SQLite configuration (Laravel 12+)
if grep -q "^DB_CONNECTION=sqlite" "$PROJECT_PATH/.env"; then
  sed -i "s|^DB_CONNECTION=sqlite|DB_CONNECTION=mysql|g" "$PROJECT_PATH/.env"
fi

# ============================================================
# STEP 5 — Fix file & directory permissions
# ============================================================

echo ""
echo "🔐 Fixing permissions..."

sudo chown -R "$USER:$USER" "$PROJECT_PATH"
find "$PROJECT_PATH" -type f -exec chmod 644 {} \;
find "$PROJECT_PATH" -type d -exec chmod 755 {} \;

echo "✅ Laravel project created at $PROJECT_PATH"


# ============================================================
# STEP 6 — Configure Laravel environment (.env + app key)
# ============================================================

echo ""
echo "⚙️ Configuring Laravel environment..."

ENV_FILE="$PROJECT_PATH/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$PROJECT_PATH/.env.example" "$ENV_FILE"
fi

sed -i "s|^APP_NAME=.*|APP_NAME=\"$NAME\"|g" "$ENV_FILE"
sed -i "s|^APP_URL=.*|APP_URL=https://$DOMAIN|g" "$ENV_FILE"

echo "🔑 Generating application key..."
php "$PROJECT_PATH/artisan" key:generate --force

echo "✅ Laravel environment configured"


# ============================================================
# STEP 7 — Create MySQL database & update env config
# ============================================================

echo ""
echo "🗄️ Creating database..."

DB_NAME="${NAME//-/_}"


sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "⚙️ Updating database configuration in .env..."

sed -i "s|^DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" "$ENV_FILE"
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=root|g" "$ENV_FILE"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=|g" "$ENV_FILE"
sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|g" "$ENV_FILE"

echo "✅ Database '$DB_NAME' ready"


# ============================================================
# STEP 8 — Update /etc/hosts
# ============================================================

echo ""
echo "🌐 Updating /etc/hosts..."

HOSTS_ENTRY="127.0.0.1 $DOMAIN"

if grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]]+$DOMAIN(\s|$)" /etc/hosts; then
  echo "ℹ️ Hosts entry already exists"
else
  echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts >/dev/null
  echo "✅ Hosts entry added"
fi


# ============================================================
# STEP 9 — Create nginx vhost
# ============================================================

echo ""
echo "🧩 Creating nginx vhost..."

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
VHOST_PATH="$NGINX_AVAILABLE/$DOMAIN"

read -r -d '' NGINX_CONF <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN;

    root $PROJECT_PATH/public;
    index index.php index.html;

    ssl_certificate     /etc/ssl/certs/$NAME.crt;
    ssl_certificate_key /etc/ssl/private/$NAME.key;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_FPM_SOCK;
    }
}
EOF

echo "$NGINX_CONF" | sudo tee "$VHOST_PATH" >/dev/null
sudo ln -sf "$VHOST_PATH" "$NGINX_ENABLED/$DOMAIN"

sudo nginx -t || {
  echo "❌ nginx config test failed"
  exit 1
}

sudo systemctl reload nginx
echo "✅ nginx vhost created"


# ============================================================
# STEP 10 — Generate SSL certificate
# ============================================================

echo ""
echo "🔐 Setting up SSL certificate..."

SSL_CERT_DIR="/etc/ssl/certs"
SSL_KEY_DIR="/etc/ssl/private"
CERT_PATH="$SSL_CERT_DIR/$NAME.crt"
KEY_PATH="$SSL_KEY_DIR/$NAME.key"

sudo mkdir -p "$SSL_CERT_DIR" "$SSL_KEY_DIR"

if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
  if command -v mkcert >/dev/null 2>&1; then
    echo "🔒 Using mkcert for trusted local SSL"
    mkcert -cert-file "/tmp/$NAME.crt" -key-file "/tmp/$NAME.key" "$DOMAIN"
    sudo mv "/tmp/$NAME.crt" "$CERT_PATH"
    sudo mv "/tmp/$NAME.key" "$KEY_PATH"
  else
    echo "⚠️ mkcert not found, generating self-signed certificate"
    sudo openssl req -x509 -nodes -days 365 \
      -newkey rsa:2048 \
      -keyout "$KEY_PATH" \
      -out "$CERT_PATH" \
      -subj "/C=IN/ST=Local/L=Local/O=Dev/OU=Local/CN=$DOMAIN"
  fi

  sudo chmod 644 "$CERT_PATH"
  sudo chmod 600 "$KEY_PATH"
fi

sudo systemctl reload nginx
echo "✅ SSL configured"


# ============================================================
# STEP 11 — Final output & open browser
# ============================================================

echo ""
echo "🎉 Laravel project is ready!"
echo ""
echo "Project details:"
echo "  📁 Path      : $PROJECT_PATH"
echo "  🌐 URL       : https://$DOMAIN"
echo "  🐘 PHP       : $PHP_VERSION"
echo "  🗄️ Database  : $DB_NAME"
echo ""

if command -v xdg-open >/dev/null 2>&1; then
  echo "🌍 Opening browser..."
  xdg-open "https://$DOMAIN" >/dev/null 2>&1 || true
else
  echo "ℹ️ Please open https://$DOMAIN manually"
fi

echo ""
echo "✅ Done."
