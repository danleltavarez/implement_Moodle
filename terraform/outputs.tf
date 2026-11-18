# =============================================================================
# outputs.tf — Saídas raiz do projeto Terraform
# =============================================================================
# Estes valores são exibidos após terraform apply e podem ser consultados
# com: terraform output ec2_public_dns
# TODO: Após o apply, use ec2_public_dns no health-check.sh e no Moodle wwwroot.
# =============================================================================

output "ec2_public_dns" {
  description = "DNS público da instância EC2. Use este endereço para acessar o Moodle e no health-check.sh."
  value       = module.compute.ec2_public_dns
}

output "rds_endpoint" {
  description = "Hostname do RDS PostgreSQL (sem porta). A porta está disponível separadamente via rds_port."
  value       = module.database.rds_endpoint
}

output "vpc_id" {
  description = "ID da VPC criada pelo módulo networking."
  value       = module.networking.vpc_id
}

output "moodle_url" {
  description = "URL completa para acessar o Moodle na EC2."
  value       = "http://${module.compute.ec2_public_dns}"
}

output "ssh_command" {
  description = "Comando SSH para acessar a EC2 após o apply."
  value       = "ssh -i ~/.ssh/moodle_key ec2-user@${module.compute.ec2_public_dns}"
}
