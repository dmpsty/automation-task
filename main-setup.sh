#!/usr/bin/env bash
# ==============================================================================
# SCRIPT 2     : AUTOMATED DEPLOYMENT WEB SERVER, DATABASE, MULTI-PHP & CMS
# Target OS    : AlmaLinux 10
# Target User  : Non-Root User dengan Akses Sudo (Prinsip Least Privilege)
# Apps         : MySQL 8.4, Nginx 1.30.4, Apache 2.4.68, PHP Multi-version, 
#                WordPress, Nextcloud, PrestaShop, Grav, Joomla, Drupal, phpMyAdmin
# ==============================================================================

set -euo pipefail

# --- DEFINISI VARIABEL CONFIGURABLE ---
WORKING_DIR="/home/damay"
APP_USER="damay"
SSH_PORT="[port]"                     # SSH Port Custom sesuai task PKL
DOMAIN_NAME="[domain]"   # Target Base Domain SSL

# Database Passwords & Users
DB_ROOT_PASS="SecureRootPass123!"
DB_PASS_WP="WpPassSecure123!"
DB_PASS_NC="NcPassSecure123!"
DB_PASS_PS="PsPassSecure123!"
DB_PASS_JM="JmPassSecure123!"
DB_PASS_DP="DpPassSecure123!"

echo "=== [SECTION 1] Validasi User Sistem & Working Directory ==="
# Memastikan direktori kerja ada dan dimiliki oleh user non-root
sudo mkdir -p "$WORKING_DIR"
sudo chown -R "$APP_USER:$APP_USER" "$WORKING_DIR"

echo "=== [SECTION 2] Setup Modul Repository PHP Multi-Version (Remi Repo) ==="
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-10.rpm || true
sudo dnf module reset php -y

# Install PHP 8.1 / 8.2 / 8.3 via Remi
sudo dnf install -y php82-php-fpm php82-php-mysqlnd php82-php-gd php82-php-xml php82-php-mbstring php82-php-zip php82-php-intl php82-php-curl \
                    php81-php-fpm php81-php-mysqlnd php81-php-gd php81-php-xml \
                    php83-php-fpm php83-php-mysqlnd php83-php-gd php83-php-xml php83-php-opcache

sudo systemctl enable --now php82-php-fpm php81-php-fpm php83-php-fpm

echo "=== [SECTION 3] Install & Setup MySQL 8.4.11 ==="
sudo dnf install -y mysql-server
sudo systemctl enable --now mysqld

# Tuning RAM untuk MySQL (2GB RAM Limit)
sudo bash -c 'cat <<EOF > /etc/my.cnf.d/z_custom.cnf
[mysqld]
innodb_buffer_pool_size = 512M
max_connections = 60
innodb_log_buffer_size = 16M
EOF'
sudo systemctl restart mysqld

echo "=== [SECTION 4] Install Nginx Latest / Apache HTTPD Latest ==="
# sudo dnf install -y nginx httpd
sudo dnf install -y nginx

# sudo systemctl enable --now nginx httpd
sudo systemctl enable --now nginx

# Mengatur Port Apache agar tidak konflik dengan Nginx (Apache Port 8080)
# sudo sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf
# sudo systemctl restart httpd

echo "=== [SECTION 5] Pengaturan Database & User Privileges (1 User 1 DB) ==="
sudo mysql -u root <<MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';
CREATE DATABASE db_wordpress;
CREATE USER 'user_wp'@'localhost' IDENTIFIED BY '$DB_PASS_WP';
GRANT ALL PRIVILEGES ON db_wordpress.* TO 'user_wp'@'localhost';

CREATE DATABASE db_nextcloud;
CREATE USER 'user_nc'@'localhost' IDENTIFIED BY '$DB_PASS_NC';
GRANT ALL PRIVILEGES ON db_nextcloud.* TO 'user_nc'@'localhost';

CREATE DATABASE db_prestashop;
CREATE USER 'user_ps'@'localhost' IDENTIFIED BY '$DB_PASS_PS';
GRANT ALL PRIVILEGES ON db_prestashop.* TO 'user_ps'@'localhost';

CREATE DATABASE db_joomla;
CREATE USER 'user_jm'@'localhost' IDENTIFIED BY '$DB_PASS_JM';
GRANT ALL PRIVILEGES ON db_joomla.* TO 'user_jm'@'localhost';

CREATE DATABASE db_drupal;
CREATE USER 'user_dp'@'localhost' IDENTIFIED BY '$DB_PASS_DP';
GRANT ALL PRIVILEGES ON db_drupal.* TO 'user_dp'@'localhost';

FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "=== [SECTION 6] Download Repository CMS / Aplikasi ke Working Dir ==="
# Berjalan sebagai user biasa tanpa sudo agar ownership berkas tetap 'damay'
cd "$WORKING_DIR"

# WordPress
wget -q https://wordpress.org/latest.tar.gz -O wp.tar.gz && tar -xf wp.tar.gz && rm -f wp.tar.gz

# Nextcloud
wget -q https://download.nextcloud.com/server/releases/latest.tar.gz -O nc.tar.gz && tar -xf nc.tar.gz && rm -f nc.tar.gz

# Grav CMS
wget -q https://getgrav.org/download/core/grav/latest -O grav.zip && unzip -q grav.zip && rm -f grav.zip

# Joomla
mkdir -p joomla && wget -q "https://downloads.joomla.org/id/cms/joomla6/6-1-2/Joomla_6-1-2-Stable-Full_Package.zip?format=zip" -O joomla/jm.zip && cd joomla && unzip -q jm.zip && rm -f jm.zip && cd "$WORKING_DIR"

# Drupal
wget -q https://www.drupal.org/download-latest/tar.gz -O drupal.tar.gz && tar -xf drupal.tar.gz && mv drupal-* drupal && rm -f drupal.tar.gz

# PrestaShop
mkdir -p prestashop && wget -q https://github.com/PrestaShop/PrestaShop/archive/refs/tags/9.1.5.zip -O prestashop/ps.zip && cd prestashop && unzip -q ps.zip && rm -f ps.zip && cd "$WORKING_DIR"

# phpMyAdmin
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -O pma.tar.gz && tar -xf pma.tar.gz && mv phpMyAdmin-*-all-languages phpmyadmin && rm -f pma.tar.gz

echo "=== [SECTION 7] Konfigurasi Ownership & File Permission Best Practice ==="
# Penyesuaian kepemilikan dan hak akses memerlukan sudo untuk menetapkan grup 'nginx'
sudo chown -R "$APP_USER:nginx" "$WORKING_DIR"
find "$WORKING_DIR" -type d -exec chmod 755 {} \;
find "$WORKING_DIR" -type f -exec chmod 644 {} \;

# Izin Khusus Grav Cache Directories
chmod -R 775 "$WORKING_DIR/grav/cache" "$WORKING_DIR/grav/logs" "$WORKING_DIR/grav/images" "$WORKING_DIR/grav/assets" "$WORKING_DIR/grav/user/accounts" 2>/dev/null || true

echo "=== [SECTION 8] Membuat Nginx Server Blocks ==="
# WordPress Block
sudo bash -c "cat <<EOF > /etc/nginx/conf.d/wp.conf
server {
    listen 80;
    server_name wp.$DOMAIN_NAME;
    root $WORKING_DIR/wordpress;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF"

# Nextcloud Block
sudo bash -c "cat <<EOF > /etc/nginx/conf.d/nc.conf
server {
    listen 80;
    server_name nc.$DOMAIN_NAME;
    root $WORKING_DIR/nextcloud;
    index index.php;

    client_max_body_size 512M;
    fastcgi_buffers 64 4K;

    location / {
        rewrite ^ /index.php;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
        deny all;
    }

    location ~ \.php(?:$|/) {
        include fastcgi_params;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF"

# phpMyAdmin Block
sudo bash -c "cat <<EOF > /etc/nginx/conf.d/phpmyadmin.conf
server {
    listen 80;
    server_name php.$DOMAIN_NAME;
    root $WORKING_DIR/phpmyadmin;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF"

sudo nginx -t && sudo systemctl reload nginx

echo "=== [SECTION 9] Setup Secure Firewall Rules via IPTables ==="
sudo systemctl stop firewalld || true
sudo systemctl disable firewalld || true
sudo systemctl enable iptables

# Reset Rules
sudo iptables -F
sudo iptables -X

# Set Policy: INPUT DROP, FORWARD DROP, OUTPUT ACCEPT
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Rule a: Loopback Interface & Established Connections
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Rule b: Allowed Incoming Ports (ICMP, SSH Custom, HTTP, HTTPS, MySQL)
sudo iptables -A INPUT -p icmp -j ACCEPT
sudo iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3306 -j ACCEPT

# Simpan Aturan IPTables Permanen
sudo service iptables save

echo "=== [SECTION 10] Install Certbot Let's Encrypt & Request SSL Wildcard ==="
sudo dnf install -y certbot python3-certbot-nginx

# Perintah Otomatisasi Sertifikat Single/Wildcard SSL (Manual Validation Ready)
echo "[INFO] Untuk generate SSL Wildcard (*.$DOMAIN_NAME), jalankan perintah berikut secara manual untuk validasi DNS TXT Record:"
echo "sudo certbot certonly --manual --preferred-challenges=dns -d '$DOMAIN_NAME' -d '*.$DOMAIN_NAME'"

echo "=== [COMPLETED] Deployment Berhasil Diselesaikan oleh User $APP_USER! ==="
