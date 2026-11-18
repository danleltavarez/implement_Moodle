# =============================================================================
# modules/database/main.tf — RDS PostgreSQL 15 em subnets privadas
# =============================================================================
# TODO: Revise db_instance_class e allocated_storage se quiser maior capacidade.
# =============================================================================

# -----------------------------------------------------------------------------
# DB Subnet Group
# Agrupa as duas subnets privadas (us-east-1a e us-east-1b) para o RDS.
# O aws_db_subnet_group exige pelo menos 2 AZs distintas — por isso criamos
# duas subnets privadas no módulo networking mesmo que apenas uma hospede o RDS.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group do RDS Moodle (2 AZs: us-east-1a e us-east-1b)"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Parameter Group — desabilita SSL obrigatório
#
# O RDS PostgreSQL 15 tem rds.force_ssl = 1 por padrão, o que faz o Moodle
# rejeitar conexões sem SSL pelo driver nativo pgsql. Como estamos em
# ambiente educacional sem certificado gerenciado, desabilitamos o SSL
# obrigatório via parameter group customizado.
#
# Alternativa: configurar sslmode=require no Moodle e distribuir o certificado
# de CA da AWS para o container — complexidade desnecessária para este desafio.
# TODO: Em produção, mantenha rds.force_ssl = 1 e configure SSL no cliente.
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-pg15-params"
  family      = "postgres15"
  description = "Parameter group do Moodle: SSL opcional para ambiente educacional"

  parameter {
    name         = "rds.force_ssl"
    value        = "0"
    apply_method = "pending-reboot"
  }

  tags = {
    Name    = "${var.project_name}-pg15-params"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Instância RDS PostgreSQL 15
#
# Decisões de configuração:
#   - db.t3.micro: menor instância disponível no Learn Lab; suficiente para carga
#     educacional e minimiza consumo de crédito.
#   - 20 GB gp2: mínimo exigido pelo desafio.
#   - publicly_accessible = false: RDS não recebe IP público; acesso somente
#     pela EC2 dentro da mesma VPC via security group.
#   - skip_final_snapshot = true: evita que o destroy trave aguardando snapshot.
#   - deletion_protection = false: permite destroy limpo no final do Lab.
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"
  # storage_encrypted: omitido intencionalmente.
  # O Learner Lab pode não ter a chave KMS padrão provisionada, causando
  # KMSKeyNotFoundException no apply. Em produção, habilite com:
  #   storage_encrypted = true
  # TODO: Se sua conta Lab suportar KMS, descomente a linha abaixo.
  # storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "${var.project_name}-db"
    Project = var.project_name
  }
}
