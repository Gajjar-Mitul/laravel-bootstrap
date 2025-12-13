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
