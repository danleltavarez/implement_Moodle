# =============================================================================
# modules/networking/outputs.tf — Saídas do módulo de rede
# =============================================================================
# TODO: Consulte estes outputs em outros módulos usando module.networking.<nome>.
# =============================================================================

output "vpc_id" {
  description = "ID da VPC criada."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID da subnet pública (us-east-1a) onde a EC2 será alocada."
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Lista com os IDs das duas subnets privadas (us-east-1a e us-east-1b) para o DB subnet group."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "ec2_sg_id" {
  description = "ID do security group da EC2 (portas 80 e 22)."
  value       = aws_security_group.ec2.id
}

output "rds_sg_id" {
  description = "ID do security group do RDS (porta 5432 restrita ao SG da EC2)."
  value       = aws_security_group.rds.id
}
