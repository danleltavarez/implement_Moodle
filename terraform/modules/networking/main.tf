# =============================================================================
# modules/networking/main.tf — VPC, subnets, IGW, route tables e security groups
# =============================================================================
# TODO: Ajuste os CIDRs nas variáveis se precisar de ranges diferentes.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC principal
# enable_dns_hostnames = true é necessário para que as instâncias EC2 recebam
# um hostname DNS público (usado no output ec2_public_dns).
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Subnet pública — us-east-1a
# map_public_ip_on_launch = true garante que a EC2 receba um IP público
# automaticamente, sem necessidade de Elastic IP adicional.
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-public"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Subnets privadas — para o DB subnet group do RDS
# O aws_db_subnet_group exige ao menos 2 AZs distintas; criamos uma em
# us-east-1a e outra em us-east-1b. Nenhuma tem rota para o IGW.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_a
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name    = "${var.project_name}-subnet-private-a"
    Project = var.project_name
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_b
  availability_zone = "${data.aws_region.current.name}b"

  tags = {
    Name    = "${var.project_name}-subnet-private-b"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway — permite tráfego de entrada e saída para a subnet pública
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Route Table pública — rota 0.0.0.0/0 apontando para o IGW
# Associada apenas à subnet pública; as subnets privadas não têm rota de saída.
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-rt-public"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Security Group da EC2
# Ingresso: HTTP (80) aberto para a internet; SSH (22) restrito ao CIDR
# configurado (use seu IP/32 em vez de 0.0.0.0/0).
# Egresso: irrestrito — a EC2 precisa baixar imagens Docker e pacotes dnf.
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg-ec2"
  description = "Security group da EC2 Moodle: HTTP publico e SSH restrito"
  vpc_id      = aws_vpc.main.id

  # TODO: Restrinja ssh_allowed_cidr ao seu IP (/32) antes do terraform apply
  ingress {
    description = "SSH restrito ao CIDR configurado"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP publico para o Moodle"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egresso irrestrito (Docker pull, dnf, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ec2"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Security Group do RDS
# Ingresso: PostgreSQL (5432) SOMENTE a partir do security group da EC2.
# Nunca abrir 0.0.0.0/0 para o banco — princípio do menor privilégio.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "Security group do RDS: PostgreSQL acessivel apenas pelo SG da EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL somente da EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Egresso irrestrito (respostas ao cliente)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-rds"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Data source: região atual
# Usado para construir nomes de AZ dinamicamente (ex.: us-east-1a),
# evitando hardcode da região nos recursos de subnet.
# -----------------------------------------------------------------------------
data "aws_region" "current" {}
