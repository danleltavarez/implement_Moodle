# =============================================================================
# modules/database/variables.tf — Variáveis do módulo de banco de dados
# =============================================================================
# TODO: db_password deve ser fornecido via terraform.tfvars ou TF_VAR_db_password.
#       Nunca grave a senha diretamente neste arquivo.
# =============================================================================

variable "project_name" {
  description = "Prefixo para nomes e tags dos recursos de banco de dados."
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas para o DB subnet group (mínimo 2 AZs distintas)."
  type        = list(string)
}

variable "rds_sg_id" {
  description = "ID do security group do RDS (recebido do módulo networking)."
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL a ser criado."
  type        = string
  default     = "moodle"
}

variable "db_username" {
  description = "Usuário master do banco de dados RDS."
  type        = string
  default     = "moodle"
}

variable "db_password" {
  description = "Senha do usuário master do RDS. Sensível — nunca commitar."
  type        = string
  sensitive   = true
}
