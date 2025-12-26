#!/data/data/com.termux/files/usr/bin/bash

set -e

PORT=8888
PREFIX_DIR=$PREFIX
WWW_DIR=$PREFIX/share/nginx/html
PHPMYADMIN_DIR=$WWW_DIR/phpmyadmin

echo "🚀 Termux LEMP Installer Started..."

# ---------------------------
# Helper: check package
# ---------------------------
pkg_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# ---------------------------
# Update packages
# ---------------------------
echo "🔄 Updating packages..."
pkg update -y && pkg upgrade -y

# ---------------------------
# Install required packages
# ---------------------------
PACKAGES=(
    nginx
    php
    php-fpm
    php-mysql
    mariadb
    wget
    unzip
)

for pkg in "${PACKAGES[@]}"; do
    if pkg_installed "$pkg"; then
        echo "✅ $pkg already installed"
    else
        echo "📦 Installing $pkg..."
        pkg install -y "$pkg"
    fi
done

# ---------------------------
# MariaDB init
# ---------------------------
if [ ! -d "$PREFIX/var/lib/mysql/mysql" ]; then
    echo "🗄️ Initializing MariaDB..."
    mariadb-install-db --basedir=$PREFIX --datadir=$PREFIX/var/lib/mysql
fi

# ---------------------------
# phpMyAdmin install
# ---------------------------
if [ ! -d "$PHPMYADMIN_DIR" ]; then
    echo "📦 Installing phpMyAdmin..."
    mkdir -p "$WWW_DIR"
    cd "$WWW_DIR"

    wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
    unzip phpMyAdmin-latest-all-languages.zip
    rm phpMyAdmin-latest-all-languages.zip

    mv phpMyAdmin-*-all-languages phpmyadmin
    cp phpmyadmin/config.sample.inc.php phpmyadmin/config.inc.php
fi

# ---------------------------
# PHP-FPM config
# ---------------------------
echo "⚙️ Configuring PHP-FPM..."
sed -i 's|^;listen =.*|listen = 127.0.0.1:9000|' \
    $PREFIX/etc/php-fpm.d/www.conf

# ---------------------------
# Nginx config
# ---------------------------
echo "⚙️ Configuring Nginx..."

cat > $PREFIX/etc/nginx/nginx.conf <<EOF
worker_processes  1;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen ${PORT};
        server_name 0.0.0.0;

        root ${WWW_DIR};
        index index.php index.html;

        location / {
            try_files \$uri \$uri/ /index.php;
        }

        location ~ \.php\$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_pass 127.0.0.1:9000;
        }
    }
}
EOF

# ---------------------------
# PHP test file
# ---------------------------
echo "<?php phpinfo();" > $WWW_DIR/index.php

# ---------------------------
# Command shortcuts
# ---------------------------
echo "⚙️ Creating helper commands..."

cat > $PREFIX/bin/lemp <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

case "$1" in
start)
    mariadbd-safe --datadir=$PREFIX/var/lib/mysql &
    php-fpm
    nginx
    ;;
stop)
    pkill nginx
    pkill php-fpm
    pkill mariadbd
    ;;
restart)
    $0 stop
    sleep 2
    $0 start
    ;;
temp)
    php-fpm
    nginx
    ;;
status)
    pgrep nginx && echo "nginx running"
    pgrep php-fpm && echo "php-fpm running"
    pgrep mariadbd && echo "mariadb running"
    ;;
*)
    echo "Usage: lemp {start|stop|restart|temp|status}"
    ;;
esac
EOF

chmod +x $PREFIX/bin/lemp

# ---------------------------
# Done
# ---------------------------
cat <<EOF

✅ INSTALLATION COMPLETE (TERMUX)

========================
COMMANDS
========================

▶ Start all:
lemp start

⏹ Stop all:
lemp stop

🔄 Restart:
lemp restart

🔥 TEMP START (nginx + php only):
lemp temp

📊 Status:
lemp status

========================
ACCESS
========================

🌐 PHP:
http://0.0.0.0:${PORT}/

🗄️ phpMyAdmin:
http://0.0.0.0:${PORT}/phpmyadmin/

========================
MariaDB
========================

Start DB only:
mariadbd-safe &

Login:
mysql

========================
DONE ✔
========================

EOF
