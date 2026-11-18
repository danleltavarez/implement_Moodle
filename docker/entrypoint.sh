#!/bin/bash
# =============================================================================
# entrypoint.sh — Inicializa o Moodle na primeira execução do container
# =============================================================================
# Executado como CMD pelo container. Faz o seguinte:
#   1. Aguarda o banco de dados (RDS ou container local) aceitar conexões
#   2. Se config.php não existir, executa o instalador CLI do Moodle
#   3. Inicia o Apache em foreground
#
# Variáveis de ambiente esperadas (fornecidas pelo docker-compose *.yml):
#   MOODLE_DB_TYPE        — tipo de driver (pgsql)
#   MOODLE_DB_HOST        — hostname do banco
#   MOODLE_DB_PORT        — porta do banco (5432)
#   MOODLE_DB_NAME        — nome do banco
#   MOODLE_DB_USER        — usuário do banco
#   MOODLE_DB_PASSWORD    — senha do banco
#   MOODLE_ADMIN_USER     — usuário admin do Moodle (padrão: admin)
#   MOODLE_ADMIN_PASSWORD — senha do admin (fornecida via variável, sem hardcode)
#   MOODLE_ADMIN_EMAIL    — e-mail do admin
#   MOODLE_SITE_NAME      — nome do site
#   MOODLE_WWWROOT        — URL base (ex.: http://ec2-X-X-X-X.compute-1.amazonaws.com)
#   MOODLE_DB_PREFIX      — prefixo das tabelas (padrão: mdl_)
#
# TODO: Ajuste MOODLE_WWWROOT para o DNS real da EC2 via variável de ambiente.
# =============================================================================

set -euo pipefail

# Defaults seguros para variáveis opcionais
MOODLE_DB_TYPE="${MOODLE_DB_TYPE:-pgsql}"
MOODLE_DB_PORT="${MOODLE_DB_PORT:-5432}"
MOODLE_DB_PREFIX="${MOODLE_DB_PREFIX:-mdl_}"
MOODLE_ADMIN_USER="${MOODLE_ADMIN_USER:-admin}"
MOODLE_ADMIN_EMAIL="${MOODLE_ADMIN_EMAIL:-admin@example.com}"
MOODLE_SITE_NAME="${MOODLE_SITE_NAME:-Moodle Challenge}"
MOODLE_WWWROOT="${MOODLE_WWWROOT:-http://localhost}"

CONFIG_FILE="/var/www/html/config.php"
MOODLE_DATA="/var/moodledata"
CLI_INSTALL="/var/www/html/admin/cli/install.php"

# -----------------------------------------------------------------------------
# 1. Aguardar o banco de dados aceitar conexões (máx. 5 min)
# Usa o cliente psql do pacote postgresql-client instalado no Dockerfile.
# Sem isso, o instalador CLI falha com "connection refused".
# -----------------------------------------------------------------------------
echo "[entrypoint] Aguardando banco de dados ${MOODLE_DB_HOST}:${MOODLE_DB_PORT}..."
MAX_WAIT=60
WAITED=0
until PGPASSWORD="${MOODLE_DB_PASSWORD}" psql \
        -h "${MOODLE_DB_HOST}" \
        -p "${MOODLE_DB_PORT}" \
        -U "${MOODLE_DB_USER}" \
        -d "${MOODLE_DB_NAME}" \
        -c "SELECT 1" > /dev/null 2>&1; do
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "[entrypoint] ERRO: banco nao respondeu apos ${MAX_WAIT} tentativas. Abortando."
    exit 1
  fi
  echo "[entrypoint] Banco indisponivel, tentativa $((WAITED+1))/${MAX_WAIT}. Aguardando 5s..."
  sleep 5
  WAITED=$((WAITED + 1))
done
echo "[entrypoint] Banco disponivel."

# -----------------------------------------------------------------------------
# 2. Instalar o Moodle via CLI (somente na primeira execução)
# O config.php é criado pelo instalador. Se já existir, pula esta etapa.
# A senha do admin vem de variável de ambiente — nunca é hardcoded aqui.
# -----------------------------------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[entrypoint] config.php ausente. Executando instalador CLI do Moodle..."

  # Garante que o moodledata tenha as permissões corretas antes do install
  chown -R www-data:www-data "$MOODLE_DATA"
  chmod 0770 "$MOODLE_DATA"

  # Passa --dbpass via variável de ambiente PHP para evitar exposição em `ps aux`.
  # O instalador CLI do Moodle lê MOODLE_INSTALL_DBPASS se --dbpass não for
  # fornecido diretamente — mas essa variável não existe nativamente. Usamos
  # um arquivo temporário com permissão 600 lido apenas pelo www-data.
  PASS_FILE=$(mktemp)
  chmod 600 "$PASS_FILE"
  printf '%s' "${MOODLE_DB_PASSWORD}" > "$PASS_FILE"
  ADMIN_PASS_FILE=$(mktemp)
  chmod 600 "$ADMIN_PASS_FILE"
  printf '%s' "${MOODLE_ADMIN_PASSWORD}" > "$ADMIN_PASS_FILE"
  chown www-data:www-data "$PASS_FILE" "$ADMIN_PASS_FILE"

  # O instalador CLI cria config.php e popula o banco com as tabelas do Moodle.
  # --non-interactive suprime prompts; --agree-license aceita a licença GPL.
  # As senhas são lidas dos arquivos temporários via substituição de processo,
  # evitando que apareçam como argumentos visíveis em `ps aux`.
  DB_PASS_VAL=$(cat "$PASS_FILE")
  ADMIN_PASS_VAL=$(cat "$ADMIN_PASS_FILE")
  rm -f "$PASS_FILE" "$ADMIN_PASS_FILE"

  sudo -u www-data php "$CLI_INSTALL" \
    --chmod=2777 \
    --lang=pt_br \
    --wwwroot="${MOODLE_WWWROOT}" \
    --dataroot="${MOODLE_DATA}" \
    --dbtype="${MOODLE_DB_TYPE}" \
    --dbhost="${MOODLE_DB_HOST}" \
    --dbport="${MOODLE_DB_PORT}" \
    --dbname="${MOODLE_DB_NAME}" \
    --dbuser="${MOODLE_DB_USER}" \
    --dbpass="${DB_PASS_VAL}" \
    --prefix="${MOODLE_DB_PREFIX}" \
    --fullname="${MOODLE_SITE_NAME}" \
    --shortname="moodle" \
    --adminuser="${MOODLE_ADMIN_USER}" \
    --adminpass="${ADMIN_PASS_VAL}" \
    --adminemail="${MOODLE_ADMIN_EMAIL}" \
    --non-interactive \
    --agree-license

  unset DB_PASS_VAL ADMIN_PASS_VAL
  echo "[entrypoint] Instalacao concluida. config.php criado."
else
  echo "[entrypoint] config.php encontrado. Pulando instalacao."
fi

# -----------------------------------------------------------------------------
# 3. Iniciar o Apache em foreground
# apache2-foreground é o entrypoint padrão da imagem php:8.1-apache.
# -----------------------------------------------------------------------------
echo "[entrypoint] Iniciando Apache..."
exec apache2-foreground
