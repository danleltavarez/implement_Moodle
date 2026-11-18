# =============================================================================
# modules/database/outputs.tf — Saídas do módulo de banco de dados
# =============================================================================
# TODO: Use module.database.rds_endpoint no módulo compute para injetar o
#       endereço do banco no user_data.sh da EC2.
# =============================================================================

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL no formato host:porta. Usado pelo Moodle para conectar ao banco."
  # O atributo address retorna apenas o hostname, sem a porta.
  value = aws_db_instance.main.address
}

output "rds_port" {
  description = "Porta do RDS PostgreSQL (5432)."
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "Nome do banco de dados criado no RDS."
  value       = aws_db_instance.main.db_name
}
