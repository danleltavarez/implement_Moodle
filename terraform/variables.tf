# =============================================================================
# variables.tf — Variáveis raiz do projeto Terraform
# =============================================================================
# TODO: Copie terraform.tfvars.example para terraform.tfvars e preencha os
#       valores reais antes de executar terraform plan ou terraform apply.
#       O arquivo terraform.tfvars está no .gitignore e nunca deve ser commitado.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuração geral
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Região AWS onde os recursos serão provisionados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado no nome de todos os recursos AWS (ex.: tags, nomes de SG)."
  type        = string
  default     = "moodle-challenge"
}

# -----------------------------------------------------------------------------
# Rede
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC principal."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública onde a EC2 será alocada (us-east-1a)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_a" {
  description = "CIDR da primeira subnet privada para o RDS (us-east-1a)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_b" {
  description = "CIDR da segunda subnet privada para o RDS (us-east-1b). Obrigatória para aws_db_subnet_group."
  type        = string
  default     = "10.0.3.0/24"
}

# -----------------------------------------------------------------------------
# Compute — EC2
# -----------------------------------------------------------------------------

variable "ec2_instance_type" {
  description = "Tipo da instância EC2 para o Moodle."
  type        = string
  default     = "t3.medium"
}

variable "ec2_public_key" {
  description = "Chave pública SSH para o key pair da EC2 (conteúdo de ~/.ssh/moodle_key.pub)."
  type        = string
  # Sem default — deve ser fornecida via terraform.tfvars ou TF_VAR_ec2_public_key.
}

variable "ssh_allowed_cidr" {
  description = <<-EOT
    CIDR autorizado para acesso SSH (porta 22) à EC2.
    Use seu IP público com /32 (ex.: 203.0.113.10/32).
    TODO: Defina seu IP/32 no terraform.tfvars antes de executar terraform apply.
    Consulte seu IP em: https://checkip.amazonaws.com
  EOT
  type = string
  # No default — must be set explicitly to prevent accidental 0.0.0.0/0 exposure.

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid CIDR block. Use your IP/32, e.g. 203.0.113.10/32."
  }
}

# -----------------------------------------------------------------------------
# Database — RDS
# -----------------------------------------------------------------------------

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL criado no RDS."
  type        = string
  default     = "moodle"
}

variable "db_username" {
  description = "Usuário master do banco de dados RDS."
  type        = string
  default     = "moodle"
}

variable "db_password" {
  description = "Senha do usuário master do RDS. Valor sensível — nunca commitar."
  type        = string
  sensitive   = true
  # Sem default — deve ser fornecida via terraform.tfvars (db_password = "...") ou
  # via variável de ambiente: export TF_VAR_db_password="SenhaForte#2024!"
}

variable "moodle_admin_password" {
  description = "Senha do administrador do Moodle. Sensível — nunca commitar. Requisitos: mínimo 8 chars, maiúscula, número e símbolo."
  type        = string
  sensitive   = true
  # Sem default — forneça via terraform.tfvars ou TF_VAR_moodle_admin_password
}
