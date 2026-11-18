# =============================================================================
# main.tf — Raiz do projeto Terraform
# =============================================================================
# Instancia os três módulos na ordem de dependência:
#   1. networking — cria a VPC, subnets, IGW, route tables e security groups
#   2. database   — cria o RDS na subnet privada (depende do networking)
#   3. compute    — cria a EC2 na subnet pública (depende do networking e do database)
#
# TODO: Preencha terraform.tfvars com seus valores antes de executar terraform apply.
# TODO: Para usar backend remoto S3, copie backend.tf.example para backend.tf e
#       configure com seu bucket e tabela DynamoDB antes de rodar terraform init.
# =============================================================================

# -----------------------------------------------------------------------------
# Módulo 1: Networking
# Provisiona a VPC completa: subnets, IGW, route tables e security groups.
# -----------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_cidr_a = var.private_subnet_cidr_a
  private_subnet_cidr_b = var.private_subnet_cidr_b
  ssh_allowed_cidr      = var.ssh_allowed_cidr
}

# -----------------------------------------------------------------------------
# Módulo 2: Database
# Provisiona o RDS PostgreSQL 15 nas subnets privadas criadas pelo módulo de rede.
# -----------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  project_name       = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}

# -----------------------------------------------------------------------------
# Módulo 3: Compute
# Provisiona a EC2 com user_data que instala Docker e sobe o Moodle.
# Depende do módulo database para injetar o endpoint do RDS no user_data.
# -----------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project_name          = var.project_name
  public_subnet_id      = module.networking.public_subnet_id
  ec2_sg_id             = module.networking.ec2_sg_id
  ec2_instance_type     = var.ec2_instance_type
  ec2_public_key        = var.ec2_public_key
  rds_endpoint          = module.database.rds_endpoint
  rds_port              = module.database.rds_port
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  moodle_admin_password = var.moodle_admin_password
}
