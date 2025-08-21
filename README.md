# Instalador Automático - Novo SGA CE + Mercure + Apache + MySQL

## 📌 Descrição
Este repositório contém um **script automatizado** para instalar e configurar todo o ambiente do **Novo SGA CE v2.1.9**, incluindo:

- MySQL 8.0
- PHP 7.4
- Apache 2.4
- Composer
- Novo SGA CE v2.1.9
- Mercure v0.10.4
- Painel Web (Senha) v2.0.1
- Triagem Touch Web v2.0.2
- Configurações de segurança e agendamento via crontab

---

## 🚀 Requisitos

Antes de executar o script, instale os pacotes básicos:

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

- **IP do servidor** (`IP_HOST`): Exemplo: `192.168.100.22`
- **Banco de Dados:**
  - `DB_ROOT_PASS`: senha do usuário root do MySQL
  - `DB_NAME`: nome do banco de dados
  - `DB_USER` / `DB_USER_PASS`: usuário e senha do banco
- **PHP:**
  - `PHP_VERSION`: versão do PHP (padrão: 7.4)
  - `TIMEZONE`: fuso horário do servidor (padrão: America/Recife)
- **Mercure:**
  - `MERCURE_URL`: link para download do binário
  - `JWT_KEY`: chave JWT usada pelo Mercure

---

## 🌐 Acessos

Após a instalação, os serviços estarão disponíveis nos links abaixo:

- 🔗 **NovoSGA Login:** `http://<IP_SERVIDOR>/novosga/public/login`
- 🔗 **Painel de Senhas:** `http://<IP_SERVIDOR>/novosga/public/painel-web/index.html`
- 🔗 **Triagem Touch:** `http://<IP_SERVIDOR>/novosga/public/triagem-touch/index.html`

---

## 🛠️ Recursos Extras

- **Reset diário de senhas** configurado via **crontab** (`00:05 AM`)
- Configurações de **segurança no Apache e PHP**
- Instalação e ativação do **Mercure como serviço systemd**

---

## 👨‍💻 Autor

- **Anderson Rocha**
- 🌍 [GitHub](https://github.com/andersonhrocha)

---

## 📜 Licença

Este projeto é distribuído sob a licença **MIT**.
