#!/bin/bash
set -e

###################################################################################
# Script de Instalação Automática do Novo SGA CE + Mercure + Apache + MySQL/MariaDB
#
# Autor: Anderson Rocha
# Data de criação: 20/08/2025
# Última atualização: 23/08/2025
# Versão: 2.0
#
# Compatível com:
#   - Ubuntu 20.04 (MySQL + PHP 7.4)
#   - Debian 12/13 (MariaDB + PHP 8.2)
#
# Uso:
#   apt install dos2unix
#   dos2unix setup.sh
#   chmod +x setup.sh
#   ./setup.sh
#
# Créditos:
#   Desenvolvido por Anderson Rocha
#   https://github.com/andersonhrocha
###################################################################################

#######################################
# DETECTAR SISTEMA
#######################################
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
VERSION=$(lsb_release -rs)

echo ">> Detectando sistema: $DISTRO $VERSION"
echo ""

if [[ "$DISTRO" == "ubuntu" ]]; then
    DB_SERVER_PKG="mysql-server mysql-client"
    PHP_VERSION="7.4"
    EXTRA_PKGS="software-properties-common apt-transport-https lsb-release ca-certificates curl unzip git gnupg2"

    # Repositório PHP Sury (Ubuntu)
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

elif [[ "$DISTRO" == "debian" ]]; then
    DB_SERVER_PKG="mariadb-server mariadb-client"
    PHP_VERSION="8.2"
    EXTRA_PKGS="apt-transport-https lsb-release ca-certificates curl unzip git gnupg2"

    # Repositório PHP Sury (Debian)
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

else
    echo ">> Distribuição não suportada: $DISTRO $VERSION"
    exit 1
fi

#######################################
# VARIÁVEIS DE CONFIGURAÇÃO
#######################################

IP_HOST="192.168.100.22" 

DB_ROOT_PASS="SenhaForte123"
DB_NAME="novosgaDB"
DB_USER="usernovosga"
DB_USER_PASS="SENHA1234"

TIMEZONE="America/Recife"
MERCURE_URL=${MERCURE_URL:=https://github.com/dunglas/mercure/releases/download/v0.10.4/mercure_0.10.4_Linux_x86_64.tar.gz}
JWT_KEY=${JWT_KEY:=!ChangeMe!}
MERCURE_FILE=${MERCURE_URL##*/}

#######################################
# ATUALIZAÇÃO
#######################################

echo ">> Atualizando sistema..."
echo "";
apt update && apt upgrade -y

#######################################
# PACOTES BÁSICOS
#######################################

echo ">> Instalando pacotes básicos..."
echo "";
apt install -y build-essential curl wget git vim htop unzip zip tar rsync man-db bash-completion net-tools iproute2 openssh-client openssh-server dos2unix $EXTRA_PKGS

#######################################
# MYSQL/MARIADB
#######################################

echo ">> Instalando Banco de Dados..."
echo "";
apt install -y $DB_SERVER_PKG
systemctl enable mysql || systemctl enable mariadb
systemctl start mysql || systemctl start mariadb

echo ">> Configurando banco de dados..."
echo ""
if [[ "$DISTRO" == "ubuntu" ]]; then
    # MySQL
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
FLUSH PRIVILEGES;
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- recria banco sempre com InnoDB
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

    echo ">> Permitindo conexões remotas MySQL..."
	echo ""
    if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
        sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
        # adiciona engine padrão se não existir
        grep -q "default-storage-engine" /etc/mysql/mysql.conf.d/mysqld.cnf || \
        echo "default-storage-engine = InnoDB" >> /etc/mysql/mysql.conf.d/mysqld.cnf
    fi
    systemctl restart mysql

else
    # MariaDB
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';
FLUSH PRIVILEGES;
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$DB_ROOT_PASS';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- recria banco sempre com InnoDB
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

    echo ">> Permitindo conexões remotas MariaDB..."
	echo ""
    if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
        sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
        # adiciona engine padrão se não existir
        grep -q "default-storage-engine" /etc/mysql/mariadb.conf.d/50-server.cnf || \
        echo "default-storage-engine = InnoDB" >> /etc/mysql/mariadb.conf.d/50-server.cnf
    fi
    systemctl restart mariadb
fi


#######################################
# PHP E APACHE
#######################################

echo ">> Instalando PHP $PHP_VERSION e Apache..."
echo ""
apt install -y apache2 apache2-bin apache2-utils apache2-suexec-pristine \
    php${PHP_VERSION} libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-mysql php${PHP_VERSION}-cli php${PHP_VERSION}-common \
    php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl \
    php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-gd \
    php${PHP_VERSION}-bcmath php${PHP_VERSION}-ldap php${PHP_VERSION}-bz2

#######################################
# HABILITAR MÓDULOS APACHE
#######################################

# Garantir que o PATH contenha /usr/sbin
if ! command -v a2enmod &>/dev/null; then
    export PATH=$PATH:/usr/sbin
fi

# Ativar módulos necessários (com caminho absoluto para garantir)
if [ -x /usr/sbin/a2enmod ]; then
    /usr/sbin/a2enmod env rewrite
    systemctl restart apache2
else
    echo ">> Aviso: a2enmod não encontrado, verifique a instalação do Apache."
fi

# Apache permita que arquivos .htaccess funcionem em qualquer diretório,
echo ">> Ajustando configuração do Apache..."
echo "";
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bkp
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf
systemctl restart apache2

# Configurar timezone do PHP
echo ">> Configurando PHP timezone..."
echo ""
mkdir -p /etc/php/${PHP_VERSION}/apache2/conf.d
echo "date.timezone = $TIMEZONE" > /etc/php/${PHP_VERSION}/apache2/conf.d/datetimezone.ini
cp /etc/php/${PHP_VERSION}/apache2/php.ini /etc/php/${PHP_VERSION}/apache2/php.ini.bkp
sed -i "s/^max_execution_time = .*/max_execution_time = 50/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/^max_input_vars = .*/max_input_vars = 5000/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/^memory_limit = .*/memory_limit = 256M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 5M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s|^;*date.timezone =.*|date.timezone = ${TIMEZONE}|" /etc/php/${PHP_VERSION}/apache2/php.ini
systemctl restart apache2

#######################################
# COMPOSER E NOVO SGA
#######################################

echo ">> Instalando Composer..."
echo "";
cd ~
curl -sS https://getcomposer.org/installer -o composer-setup.php
HASH=$(curl -sS https://composer.github.io/installer.sig)
php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer

echo ">> Cria o projeto usando o Composer..."
echo ""
composer create-project "novosga/novosga" ~/novosga -vvv

# Move para o diretório do Apache
mv ~/novosga /var/www/html/

# Agora entra no diretório
cd /var/www/html/novosga

# Torna o bin/console executável e limpa/prepara o cache
chmod +x bin/console

if [[ "$DISTRO" == "ubuntu" ]]; then
# Ubuntu

export APP_ENV="prod" LANGUAGE="pt_BR" DATABASE_URL="mysql://$DB_USER:$DB_USER_PASS@localhost:3306/$DB_NAME"
	
# Limpar o cache do Symfony
bin/console cache:clear --no-debug --no-warmup --env=prod -vv

bin/console cache:warmup --env=prod

else
# Debian

# Configura DATABASE_URL no .env
ENV_FILE="/var/www/html/novosga/.env"
touch $ENV_FILE
sed -i '/^DATABASE_URL=/d' $ENV_FILE

echo "DATABASE_URL=\"mysql://$DB_USER:$DB_USER_PASS@127.0.0.1:3306/$DB_NAME?charset=utf8mb4\"" >> $ENV_FILE

# Limpar o cache do Symfony
bin/console cache:clear

# Rodar migrations
bin/console doctrine:migrations:migrate --no-interaction
fi

# Criação do .htaccess com as variáveis de ambiente
echo ">> Criando .htaccess..."
echo "";
cat <<EOL > public/.htaccess
Options -MultiViews
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ index.php [QSA,L]
SetEnv APP_ENV prod
SetEnv LANGUAGE pt_BR
SetEnv DATABASE_URL mysql://$DB_USER:$DB_USER_PASS@localhost:3306/$DB_NAME
EOL

echo ">> Instalando Novo SGA..."
echo "";
# Executa a instalação
bin/console novosga:install

echo ">> Ajustando permissões..."
echo "";
cd /var/www/html/
chown -R www-data:www-data novosga
find novosga -type f -exec chmod 640 {} \;
find novosga -type d -exec chmod 750 {} \;

#######################################
# MERCURE
#######################################

echo ">> Instalando Mercure..."
echo "";
groupadd --system mercure || true
useradd --system --gid mercure --create-home --home-dir /var/lib/mercure --shell /usr/sbin/nologin --comment "Mercure Server" mercure || true

mkdir -p /var/lib/mercure/{db,certs,bin}
cd /var/lib/mercure/bin
wget -q $MERCURE_URL
tar -zxf $MERCURE_FILE
chmod +x mercure
chown -R mercure:mercure /var/lib/mercure
ln -sf /var/lib/mercure/bin/mercure /usr/local/bin/mercure

mkdir -p /etc/mercure
cat <<EOF > /etc/mercure/mercure.env
# Chave secreta para assinar os JWTs
JWT_KEY='${JWT_KEY}'

# Endereço que o Mercure escuta (0.0.0.0 para aceitar conexões externas)
ADDR=0.0.0.0:3000

# Banco BoltDB para armazenar dados do Mercure
TRANSPORT_URL="bolt:///var/lib/mercure/db/database.db?size=1000"

# Diretório para certificados TLS/ACME (pode deixar vazio se não usar HTTPS)
ACME_CERT_DIR=/var/lib/mercure/certs

# Origens permitidas para CORS (sua aplicação Novosga e localhost)
CORS_ALLOWED_ORIGINS="http://${IP_HOST},http://127.0.0.1:8002,http://localhost:8002"

# Permitir conexões anônimas (opcional, para testes)
ALLOW_ANONYMOUS=1

# Usar cabeçalhos encaminhados (proxy reverso)
USE_FORWARDED_HEADERS=1

# Permitir todos os tópicos (ajuste conforme segurança)
ALLOWED_TOPICS=.*
EOF

cat <<EOF > /etc/systemd/system/mercure.service
[Unit]
Description=Mercure
After=network.target

[Service]
EnvironmentFile=/etc/mercure/mercure.env
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/mercure
User=mercure
Group=mercure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable mercure
systemctl start mercure

echo ">> Ajustando Mercure no NovoSGA..."
echo "";
cd /var/www/html/novosga/
sed -i "s|^MERCURE_PUBLISH_URL=.*|MERCURE_PUBLISH_URL=http://${IP_HOST}:3000/.well-known/mercure|" .env

#######################################
# PAINEL WEB E TRIAGEM TOUCH WEB
#######################################

# Acesse o diretório do projeto e limpe o cache
cd /var/www/html/novosga

# Limpar o cache
php bin/console cache:clear --env=prod

# Isso remove e recria o cache (incluindo os arquivos de proxy do Doctrine).
php bin/console cache:warmup --env=prod

# Corrigir permissões 
chown -R www-data:www-data var
find var -type f -exec chmod 640 {} \;
find var -type d -exec chmod 750 {} \;

echo ">> Instalando Painel de Senhas Web (painel-web)..."
echo "";
cd /var/opt/

# Baixar e descompactar painel
wget https://github.com/novosga/panel-app/releases/download/v2.0.1/painel-web-2.0.1.zip
unzip painel-web-2.0.1.zip
mv painel-web-2.0.1 painel-web
mv painel-web /var/www/html/novosga/public/

# Ajustar permissões
cd /var/www/html/novosga/public/
chown -R www-data:www-data painel-web
find painel-web -type f -exec chmod 640 {} \;
find painel-web -type d -exec chmod 750 {} \;

echo "✅ Painel Web instalado com sucesso!"
echo ""

echo ">> Instalando Triagem Touch Web (triagem-touch)..."
echo "";
cd /var/opt/

# Baixar e descompactar triagem
wget https://github.com/novosga/triage-app/releases/download/v2.0.2/triagem-touch-2.0.2-web.zip
unzip triagem-touch-2.0.2-web.zip -d triagem-touch-2.0.2-web
mv triagem-touch-2.0.2-web triagem-touch
mv triagem-touch /var/www/html/novosga/public/

# Ajustar permissões
cd /var/www/html/novosga/public/
chown -R www-data:www-data triagem-touch
find triagem-touch -type f -exec chmod 640 {} \;
find triagem-touch -type d -exec chmod 750 {} \;

echo "✅ Triagem Touch Web instalada com sucesso!"
echo ""

#######################################
# CRONTAB RESET SENHAS
#######################################

echo ">> Agendando reset diário de senhas..."
echo "";
(crontab -l 2>/dev/null; echo "05 00 * * * APP_ENV=prod LANGUAGE=pt_BR DATABASE_URL=\"mysql://$DB_USER:$DB_USER_PASS@localhost:3306/$DB_NAME\" /var/www/html/novosga/bin/console novosga:reset") | crontab -

#######################################
# FINAL
#######################################

echo ""
echo ">> Tudo concluído com sucesso!"
echo ""
echo "🔗 NovoSGA Login:       http://$IP_HOST/novosga/public/login"
echo "🔗 Painel de Senhas:    http://$IP_HOST/novosga/public/painel-web/index.html"
echo "🔗 Triagem Touch:       http://$IP_HOST/novosga/public/triagem-touch/index.html"
echo ""
echo "✅ Instalação completa!"
