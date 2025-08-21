#!/bin/bash
set -e

###########################################################################
# Script de Instalação Automática do Novo SGA CE + Mercure + Apache + MySQL
#
# Autor: Anderson Rocha
# Data de criação: 20/08/2025
# Versão: 1.0
#
# Descrição:
#   Script modularizado para instalar e configurar o ambiente completo:
#     - MySQL 8.0
#     - PHP 7.4
#     - Apache 2.4
#     - Composer
#     - Novo SGA CE v2.1.9
#     - Mercure v0.10.4
#     - Painel Web (Senha) v2.0.1
#     - Triagem Touch Web v2.0.2
#     - Configurações de segurança e agendamento via crontab
#
# Uso:
#   apt install dos2unix unzip curl git
#   dos2unix setup.sh
#   chmod +x setup.sh
#   ./setup.sh
#
# Créditos:
#   Desenvolvido por Anderson Rocha
#   https://github.com/andersonhrocha
###########################################################################

#######################################
# VARIÁVEIS DE CONFIGURAÇÃO
#######################################

# SERVIDOR - Altere conforme o IP do seu servidor
IP_HOST="192.168.100.22" 

# MySQL
DB_ROOT_PASS="SenhaForte123"
DB_NAME="novosgaDB"
DB_USER="usernovosga"
DB_USER_PASS="SENHA1234"

# PHP
PHP_VERSION="7.4"
TIMEZONE="America/Recife"

# Mercure
MERCURE_URL=${MERCURE_URL:=https://github.com/dunglas/mercure/releases/download/v0.10.4/mercure_0.10.4_Linux_x86_64.tar.gz}
JWT_KEY=${JWT_KEY:=!ChangeMe!}
MERCURE_FILE=${MERCURE_URL##*/}

#######################################
# ATUALIZAÇÃO DO SISTEMA
#######################################

echo ">> Atualizando sistema..."
echo "";
apt update && apt upgrade -y

#######################################
# TIMEZONE
#######################################

echo ">> Configurando timezone para $TIMEZONE..."
echo "";
timedatectl set-timezone "$TIMEZONE"

#######################################
# MYSQL
#######################################

echo ">> Instalando MySQL..."
echo "";
apt install -y mysql-server mysql-client
systemctl enable mysql
systemctl start mysql

echo ">> Configurando banco de dados..."
echo "";
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
FLUSH PRIVILEGES;
CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo ">> Permitindo conexões remotas MySQL..."
echo "";
sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

#######################################
# PHP E APACHE
#######################################

echo ">> Instalando PHP e Apache..."
echo "";
apt install -y software-properties-common apt-transport-https lsb-release ca-certificates curl unzip git gnupg2 dos2unix
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

apt install -y php${PHP_VERSION} php-cli php-common php-mysql php-curl php-zip php-intl php-xml php-mbstring libapache2-mod-php php-gd php-bcmath php-ldap php-bz2
apt install -y apache2
a2enmod env rewrite
apache2ctl configtest
systemctl restart apache2

echo ">> Ajustando configuração do Apache..."
echo "";
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bkp
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf
systemctl restart apache2

echo ">> Configurando PHP timezone e parâmetros..."
echo "";
cp /etc/php/${PHP_VERSION}/apache2/php.ini /etc/php/${PHP_VERSION}/apache2/php.ini.bkp
echo "date.timezone = $TIMEZONE" > /etc/php/${PHP_VERSION}/apache2/conf.d/datetimezone.ini
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

# Exporta as variáveis de ambiente antes do comando de instalação
export APP_ENV="prod"
export LANGUAGE="pt_BR"
export DATABASE_URL="mysql://$DB_USER:$DB_USER_PASS@localhost:3306/$DB_NAME"

# Move para o diretório do Apache
mv ~/novosga /var/www/html/
cd /var/www/html/novosga

# Torna o bin/console executável e limpa/prepara o cache
chmod +x bin/console
bin/console cache:clear --no-debug --no-warmup --env=prod -vv
bin/console cache:warmup --env=prod

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
echo "Acesse em: http://$IP_HOST/novosga/public/painel-web/index.html"

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
echo "Acesse em: http://$IP_HOST/novosga/public/triagem-touch/index.html"

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