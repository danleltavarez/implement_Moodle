# =============================================================================
# modules/networking/variables.tf — Variáveis do módulo de rede
# =============================================================================
# TODO: Revise os CIDRs abaixo se quiser usar um range de endereços diferente.
# =============================================================================

variable "project_name" {
  description = "Prefixo para nomes e tags dos recursos de rede."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC principal (ex.: 10.0.0.0/16)."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (us-east-1a) onde a EC2 ficará alocada."
  type        = string
}

variable "private_subnet_cidr_a" {
  description = "CIDR da primeira subnet privada (us-east-1a) para o subnet group do RDS."
  type        = string
}

variable "private_subnet_cidr_b" {
  description = "CIDR da segunda subnet privada (us-east-1b) para o subnet group do RDS. Obrigatória: aws_db_subnet_group exige pelo menos 2 AZs distintas."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado para SSH (porta 22) na EC2. Use seu IP/32 em produção."
  type        = string
}
