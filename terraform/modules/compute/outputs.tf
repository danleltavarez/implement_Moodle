# =============================================================================
# modules/compute/outputs.tf — Saídas do módulo de compute
# =============================================================================
# TODO: Use ec2_public_dns no health-check.sh após o terraform apply:
#       ./scripts/health-check.sh http://$(terraform output -raw ec2_public_dns)
# =============================================================================

output "ec2_public_dns" {
  description = "DNS público da instância EC2. Use este endereço para acessar o Moodle e no health-check.sh."
  value       = aws_instance.moodle.public_dns
}

output "ec2_instance_id" {
  description = "ID da instância EC2 criada."
  value       = aws_instance.moodle.id
}

output "ec2_public_ip" {
  description = "IP público da instância EC2."
  value       = aws_instance.moodle.public_ip
}
