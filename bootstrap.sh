#!/usr/bin/env bash
set -e

# Usage:
# ./bootstrap.sh --name=my-app [--domain=my-app.local] [--php=8.3]

# 1. Parse arguments (--name, --domain, --php)
# 2. Validate required inputs
# 3. Resolve defaults
# 4. Validate dependencies (nginx, php-fpm, composer, mysql)
# 5. Create Laravel project
# 6. Fix permissions
# 7. Create database
# 8. Add hosts entry
# 9. Generate SSL cert
# 10. Create nginx vhost
# 11. Reload nginx
# 12. Open browser

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

exit 0

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

if ! sudo -n true 2>/dev/null; then
  echo "❌ sudo access is required to modify hosts and nginx config."
  exit 1
fi

PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

if [[ ! -S "$PHP_FPM_SOCK" ]]; then
  echo "❌ PHP-FPM socket not found at $PHP_FPM_SOCK"
  echo "   Is php${PHP_VERSION}-fpm installed and running?"
  exit 1
fi

echo "✅ All dependencies satisfied."

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

composer create-project --prefer-dist laravel/laravel "$PROJECT_PATH"

echo "🔐 Fixing permissions..."

sudo chown -R "$USER:$USER" "$PROJECT_PATH"
find "$PROJECT_PATH" -type f -exec chmod 644 {} \;
find "$PROJECT_PATH" -type d -exec chmod 755 {} \;

echo "✅ Laravel project created at $PROJECT_PATH"
