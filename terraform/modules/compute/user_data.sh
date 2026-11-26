#!/bin/bash
# =============================================================================
# user_data.sh — Inicialização da EC2: instala Docker e sobe o Moodle
# =============================================================================
# Executado UMA VEZ no primeiro boot da instância EC2 (Amazon Linux 2023).
# Log público (sem credenciais): /var/log/user-data.log
#
# Variáveis injetadas pelo templatefile() do Terraform:
#   ${rds_endpoint}            — hostname do RDS PostgreSQL (sem porta)
#   ${rds_port}                — porta do RDS (5432)
#   ${db_name}                 — nome do banco de dados
#   ${db_username}             — usuário do banco de dados
#   ${db_password_b64}         — senha do banco (Base64-encoded, decodificada em runtime)
#   ${moodle_admin_password_b64} — senha do admin Moodle (Base64-encoded, decodificada em runtime)
#   ${project_name}            — prefixo do projeto
#
# Segurança — transporte de senhas:
#   As senhas são passadas como Base64 para evitar que apareçam como texto
#   plano no atributo user-data da EC2 (visível via describe-instance-attribute).
#   Base64 é ENCODING, não CRIPTOGRAFIA — protege apenas contra exposição acidental
#   em logs e interfaces de console. O .env gerado tem permissões 600.
#
# TODO: Ajuste a URL do repositório Git abaixo se usar um fork.
# =============================================================================

# set -euo pipefail deve preceder qualquer operação para que falhas na
# decodificação Base64 (ou em qualquer etapa posterior) abortem o script.
set -euo pipefail

# -----------------------------------------------------------------------------
# Decodificar senhas ANTES de qualquer redirecionamento de log.
# Base64 é encoding, não criptografia — evita que senhas apareçam como texto
# plano no atributo user-data (visível via aws ec2 describe-instance-attribute).
# Essas variáveis NUNCA são escritas em nenhum arquivo de log.
# -----------------------------------------------------------------------------
DB_PASS=$(echo "${db_password_b64}" | base64 -d)
ADMIN_PASS=$(echo "${moodle_admin_password_b64}" | base64 -d)

# Log público — credenciais NUNCA são escritas aqui
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] user_data: inicio ==="

# -----------------------------------------------------------------------------
# 1. Atualizar pacotes do sistema
# -----------------------------------------------------------------------------
echo "=== [$(date)] Atualizando pacotes ==="
dnf update -y --quiet

# -----------------------------------------------------------------------------
# 2. Instalar Git (necessário para clonar o repositório)
# -----------------------------------------------------------------------------
dnf install -y --quiet git

# -----------------------------------------------------------------------------
# 3. Instalar Docker Engine
# Amazon Linux 2023 distribui Docker via dnf. O pacote "docker" instala
# o daemon + CLI. Docker Compose v2 é instalado como plugin separado.
# -----------------------------------------------------------------------------
echo "=== [$(date)] Instalando Docker ==="
dnf install -y --quiet docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# -----------------------------------------------------------------------------
# 4. Instalar Docker Compose v2 como plugin Docker
# O binário fica em /usr/local/lib/docker/cli-plugins/ para que todos os
# usuários possam usar "docker compose" (com espaço, não hífen).
# TODO: Atualize COMPOSE_VERSION se quiser uma versão mais recente.
# -----------------------------------------------------------------------------
echo "=== [$(date)] Instalando Docker Compose v2 ==="
COMPOSE_VERSION="v2.27.1"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL \
  "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version

# -----------------------------------------------------------------------------
# 5. Clonar o repositório
# TODO: Substitua pela URL do seu fork se tiver feito fork do repositório.
# -----------------------------------------------------------------------------
echo "=== [$(date)] Clonando repositorio ==="
REPO_URL="https://github.com/danleltavarez/implement_Moodle.git"
WORK_DIR="/opt/moodle"
git clone --depth=1 "$REPO_URL" "$WORK_DIR"

# -----------------------------------------------------------------------------
# 6. Obter o DNS público da EC2 via IMDSv2
# IMDSv2 exige token com TTL — não funciona sem o cabeçalho X-aws-ec2-metadata-token.
# O wwwroot precisa do DNS real para que links internos do Moodle funcionem.
# -----------------------------------------------------------------------------
echo "=== [$(date)] Obtendo DNS publico via IMDSv2 ==="
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
EC2_PUBLIC_DNS=$(curl -s \
  -H "X-aws-ec2-metadata-token: $${IMDS_TOKEN}" \
  "http://169.254.169.254/latest/meta-data/public-hostname")
echo "=== [$(date)] DNS publico: $${EC2_PUBLIC_DNS} ==="

# -----------------------------------------------------------------------------
# 7. Criar o arquivo .env com credenciais — FORA do log
# O log é pausado neste bloco para que a senha nunca apareça em
# /var/log/user-data.log nem nos logs do CloudWatch.
# umask 077 garante que o arquivo seja criado com permissão 600 (somente root).
# As variáveis $DB_PASS e $ADMIN_PASS foram decodificadas no início do script,
# antes do redirecionamento de log.
# -----------------------------------------------------------------------------
echo "=== [$(date)] Criando .env (credenciais omitidas do log) ==="
# O .env é escrito redirecionando stdout/stderr do heredoc para /dev/null
# durante a escrita, de modo que as senhas ($DB_PASS, $ADMIN_PASS) nunca
# aparecem em /var/log/user-data.log. O exec do tee segue ativo para todo
# o restante do script.
umask 077
(
  # Subshell com stdout e stderr desviados: protege o log sem ocultar erros
  # do restante do script. Se o cat falhar, o subshell retorna código != 0
  # e o set -e do script pai aborta a execução.
  exec 1>/dev/null 2>/dev/null
  cat > "$${WORK_DIR}/docker/.env" <<ENVEOF
# Gerado automaticamente em runtime pelo user_data.sh — nao editar manualmente
# Banco de dados (RDS PostgreSQL)
POSTGRES_DB=${db_name}
POSTGRES_USER=${db_username}
POSTGRES_PASSWORD=$DB_PASS

# Variaveis do entrypoint do Moodle
MOODLE_DB_TYPE=pgsql
MOODLE_DB_HOST=${rds_endpoint}
MOODLE_DB_PORT=${rds_port}
MOODLE_DB_NAME=${db_name}
MOODLE_DB_USER=${db_username}
MOODLE_DB_PASSWORD=$DB_PASS
MOODLE_DB_PREFIX=mdl_
MOODLE_WWWROOT=http://EC2_DNS_PLACEHOLDER
MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=$ADMIN_PASS
MOODLE_ADMIN_EMAIL=admin@example.com
MOODLE_SITE_NAME=Moodle Challenge AWS
ENVEOF
)

# Restringe permissão explicitamente (defence in depth, além do umask 077)
chmod 600 "$${WORK_DIR}/docker/.env"

# Substitui o placeholder do DNS público agora que temos o valor real.
# sed não escreve senhas — apenas o hostname público, que já está no log.
sed -i "s|http://EC2_DNS_PLACEHOLDER|http://$${EC2_PUBLIC_DNS}|g" \
  "$${WORK_DIR}/docker/.env"

echo "=== [$(date)] .env criado com permissao 600 ==="

# -----------------------------------------------------------------------------
# 8. Subir o Moodle com o compose standalone para AWS
# docker-compose.aws.yml não depende do compose local — usa apenas RDS,
# sem container de banco. Mapeado na porta 80 (HTTP público).
# -----------------------------------------------------------------------------
echo "=== [$(date)] Subindo Moodle com Docker Compose (AWS) ==="
cd "$${WORK_DIR}/docker"
docker compose -f docker-compose.aws.yml up -d --build

echo "=== [$(date)] user_data: concluido ==="
echo "=== [$(date)] Moodle sera acessivel em: http://$${EC2_PUBLIC_DNS} ==="
echo "=== [$(date)] Aguarde ~5 min para o instalador CLI do Moodle concluir ==="
