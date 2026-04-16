# Laravel Bootstrap CLI

Automates and standardises Laravel project setup by eliminating repetitive and error-prone configuration.

---

## 🚧 The Problem

Setting up a Laravel project locally is not just “install and run”.

A typical setup required:
- creating a new Laravel project  
- configuring PHP (CLI + FPM)  
- setting up nginx virtual host  
- updating `/etc/hosts`  
- installing and configuring SSL (trial-and-error)  
- creating and configuring a database  
- fixing permissions  

⏱ This process typically took **45–50 minutes per project**  
❌ It was manual, inconsistent, and error-prone  

---

## ⚙️ The Solution

A CLI tool that handles the entire setup in one command.

With this:
- full environment setup is reduced to **under 10 seconds**  
- SSL setup becomes reliable (no trial-and-error)  
- configuration is consistent across projects  

---

## 🚀 What It Does

In a single command, it:

- Creates a new Laravel project  
- Configures PHP (CLI + FPM)  
- Sets up nginx virtual host  
- Adds local domain mapping  
- Generates SSL certificates (`mkcert`)  
- Creates and configures a database  
- Sets correct permissions  
- Opens the project in the browser  

---

## 🎯 Why This Matters

- Eliminates repetitive setup work  
- Reduces configuration errors  
- Standardises development environments  
- Speeds up onboarding for new projects  

> Built from real-world development friction — not theory.
---

## 🎥 Demo

<video src="https://github.com/user-attachments/assets/bddfec33-b8cd-4316-8c92-186c74a9eafc" controls></video>

## What this tool does

In a single command, this script:

- Creates a new Laravel project
- Let's you choose the PHP version
- Configures PHP-FPM
- Creates a MySQL database
- Updates Laravel `.env`
- Adds a local domain (`.local`)
- Generates SSL certificates (via `mkcert` if available)
- Creates and enables an nginx vhost
- Reloads nginx
- Opens the project in your browser

All with **minimal input** and **sensible defaults**.

---

## Supported OS

- **Linux only (Ubuntu-focused)**

macOS and other operating systems are intentionally out of scope for now.

---

## Prerequisites

You must already have the following installed and configured:

- Linux (Ubuntu recommended)
- `nginx`
- `php` and `php-fpm` (multiple versions supported)
- `composer`
- `mysql` or `mariadb`
- `sudo` access
- `mkcert` (optional but recommended for trusted local SSL)

> This script does **not** install system packages.
> It assumes a working local development environment.

---

## Installation

Clone the repository:

```bash
git clone git@github.com:Gajjar-Mitul/laravel-bootstrap.git
cd laravel-bootstrap


## Make the script executable:
``` bash
chmod +x bootstrap.sh

##Usage

Create a new Laravel project with default settings:
```bash
./bootstrap.sh --name=my-app

Create a project with a custom domain and PHP version:
```bash
./bootstrap.sh --name=my-app --domain=my-app.local --php=8.3


Available options
| Option     | Description             | Default        |
| ---------- | ----------------------- | -------------- |
| `--name`   | Project name (required) | —              |
| `--domain` | Local domain            | `<name>.local` |
| `--php`    | PHP version             | `8.3`          |

What happens under the hood
At a high level, the script performs the following steps:

1. Parses CLI arguments and resolves defaults
2. Validates system dependencies
3. Prompts once for sudo access
4. Creates the Laravel project (Laravel install scripts disabled)
5. Fixes file and directory permissions
6. Configures Laravel environment variables
7. Creates a MySQL database
8. Updates /etc/hosts
9. Generates SSL certificates
10. Creates and enables an nginx vhost
11. Reloads nginx
12. Opens the project in the browser

Each step is clearly separated and documented inside the script.

* Opinionated by design
* This tool is intentionally opinionated:
* Uses nginx, not Apache
* Uses PHP-FPM sockets
* Uses local .local domains
* Uses MySQL, not SQLite
* Assumes direct control over the local system

If this matches how you work, this tool will feel natural.

## Known limitations

* Linux only
* No Docker support
* No Windows or macOS support
* Assumes existing nginx and PHP setup
* Database configuration is intended for local development only

## 🧪 Roadmap
- [x] Setup fresh projects  
- [ ] Setup for existing (cloned) projects  
- [ ] Project teardown (DB, nginx, SSL cleanup)  
- [ ] Multi-project environment support  

## Contributing

This project is intentionally simple.
If you would like to contribute:
* Fork the repository
* Keep changes focused and minimal
* Prefer clarity over cleverness

## License

MIT License

Copyright (c) 2025 Gajjar Mitul

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including, without limitation, the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
