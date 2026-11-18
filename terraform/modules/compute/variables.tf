# =============================================================================
# modules/compute/variables.tf — Variáveis do módulo de compute (EC2)
# =============================================================================
# TODO: ec2_public_key e db_password devem vir do terraform.tfvars.
#       Nunca grave chaves ou senhas diretamente neste arquivo.
# =============================================================================

variable "project_name" {
  description = "Prefixo para nomes e tags dos recursos de compute."
  type        = string
}

variable "public_subnet_id" {
  description = "ID da subnet pública onde a EC2 será alocada (recebido do módulo networking)."
  type        = string
}

variable "ec2_sg_id" {
  description = "ID do security group da EC2 (recebido do módulo networking)."
  type        = string
}

variable "ec2_instance_type" {
  description = "Tipo da instância EC2 (ex.: t3.medium)."
  type        = string
  default     = "t3.medium"
}

variable "ec2_public_key" {
  description = "Chave pública SSH para o key pair da EC2 (conteúdo de ~/.ssh/moodle_key.pub)."
  type        = string
}

variable "rds_endpoint" {
  description = "Hostname do RDS PostgreSQL (sem porta), injetado no user_data.sh."
  type        = string
}

variable "rds_port" {
  description = "Porta do RDS PostgreSQL (normalmente 5432)."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL."
  type        = string
  default     = "moodle"
}

variable "db_username" {
  description = "Usuário do banco de dados RDS."
  type        = string
  default     = "moodle"
}

variable "db_password" {
  description = "Senha do banco de dados RDS. Sensível — injetada no user_data em runtime."
  type        = string
  sensitive   = true
}

variable "moodle_admin_password" {
  description = "Senha do administrador do Moodle. Sensível — nunca exibida nos logs."
  type        = string
  sensitive   = true
}
