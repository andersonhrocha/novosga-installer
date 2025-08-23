# Instalador Automático - Novo SGA CE + Mercure + Apache + MySQL/MariaDB  

## 📌 Descrição  
Este repositório contém um **script automatizado** para instalar e configurar o ambiente do **Novo SGA CE**, com suporte tanto para **Debian** quanto para **Ubuntu**.  

### 🔹 Compatibilidade e versões utilizadas  
- **Debian 12 / 13**  
  - Banco de Dados: **MariaDB 10.x**  
  - PHP: **8.2**  
  - Novo SGA CE: **v2.2.7**  

- **Ubuntu 20.04**  
  - Banco de Dados: **MySQL 8.0**  
  - PHP: **7.4**  
  - Novo SGA CE: **v2.1.9**  

Inclui ainda:  
- Apache 2.4  
- Composer  
- Mercure v0.10.4  
- Painel Web (Senha) v2.0.1  
- Triagem Touch Web v2.0.2  
- Configurações de segurança e agendamento via crontab  

---

## 🚀 Requisitos  

Antes de executar o script, instale os pacotes básicos (**válido para Debian e Ubuntu**):  

```bash
sudo apt update && sudo apt install -y dos2unix unzip curl git
```

---

## ⚙️ Uso  

Baixe o script `setup.sh` e execute os comandos abaixo:  

```bash
dos2unix setup.sh
chmod +x setup.sh
./setup.sh
```

---

## 🔧 Configurações Principais  

As variáveis podem ser ajustadas no início do script:  

- **IP do servidor** (`IP_HOST`)  
- **Banco de Dados**  
  - `DB_ROOT_PASS` → senha do root (MySQL/MariaDB)  
  - `DB_NAME` → nome do banco  
  - `DB_USER` / `DB_USER_PASS` → usuário e senha  
- **PHP**  
  - `PHP_VERSION`: (8.2 no Debian, 7.4 no Ubuntu)  
  - `TIMEZONE`: (padrão: America/Recife)  
- **Mercure**  
  - `MERCURE_URL` → link do binário  
  - `JWT_KEY` → chave JWT  

---

## 🌐 Acessos  

Após a instalação, os serviços estarão disponíveis nos links abaixo:  

- 🔗 **NovoSGA Login:** `http://<IP_SERVIDOR>/novosga/public/login`  
- 🔗 **Painel de Senhas:** `http://<IP_SERVIDOR>/novosga/public/painel-web/index.html`  
- 🔗 **Triagem Touch:** `http://<IP_SERVIDOR>/novosga/public/triagem-touch/index.html`  

---

## 🛠️ Recursos Extras  

- **Reset diário de senhas** via **crontab** (`00:05 AM`)  
- Configurações de **segurança no Apache e PHP**  
- Instalação e ativação do **Mercure como serviço systemd**  

---

## 👨‍💻 Autor  

- **Anderson Rocha**  
- 🌍 [GitHub](https://github.com/andersonhrocha)  

---

## 📜 Licença  

Distribuído sob a licença **MIT**.  
