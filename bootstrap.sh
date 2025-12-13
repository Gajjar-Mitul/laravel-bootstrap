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
