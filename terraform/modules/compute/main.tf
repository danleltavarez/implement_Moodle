# =============================================================================
# modules/compute/main.tf — Instância EC2 com Docker e Moodle
# =============================================================================
# TODO: Substitua ec2_public_key no terraform.tfvars pela sua chave pública SSH.
# =============================================================================

# -----------------------------------------------------------------------------
# Data source: AMI mais recente do Amazon Linux 2023
# O parâmetro SSM é mantido pela AWS e resolve sempre a AMI recomendada,
# sem necessidade de hardcode de ID (que muda por região e release).
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------------------------------
# Data source: LabRole instance profile
# "LabRole" is the pre-existing IAM instance profile in AWS Academy Learner Lab.
# Confirmed name from AWS Academy documentation. Do NOT create aws_iam_role resources.
# O AWS Learn Lab proíbe aws_iam_role e aws_iam_instance_profile como recursos.
# O perfil "LabRole" já existe na conta — referenciamos via data source.
# -----------------------------------------------------------------------------
data "aws_iam_instance_profile" "lab_role" {
  name = "LabRole"
}

# -----------------------------------------------------------------------------
# Key Pair — permite acesso SSH à instância com sua chave privada local
# A chave pública é passada via variável; a privada fica em ~/.ssh/
# -----------------------------------------------------------------------------
resource "aws_key_pair" "moodle" {
  key_name   = "${var.project_name}-key"
  public_key = var.ec2_public_key

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Instância EC2 — Amazon Linux 2023, t3.medium
#
# Decisões:
#   - metadata_options: IMDSv2 obrigatório (http_tokens = "required").
#     Sem isso a instância aceita IMDSv1, que não exige token e é vulnerável
#     a SSRF que vaza credenciais de instância.
#   - user_data_replace_on_change = true: se qualquer variável de template
#     mudar (ex.: nova senha, novo endpoint RDS), o Terraform destrói e
#     recria a instância para garantir que o user_data mais recente seja
#     executado. Para o Learn Lab isso é o comportamento desejado.
#   - templatefile(): substitui variáveis Terraform no script antes de enviar.
#     Variáveis bash no script usam $${VAR} para escapar a interpolação do HCL.
# -----------------------------------------------------------------------------
resource "aws_instance" "moodle" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.ec2_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.ec2_sg_id]
  key_name               = aws_key_pair.moodle.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab_role.name

  # IMDSv2 obrigatório: impede acesso ao metadata service sem token explícito
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Renderiza user_data.sh com as variáveis do Terraform.
  # Senhas são passadas em Base64 para evitar que apareçam como texto plano
  # no atributo user-data (visível via aws ec2 describe-instance-attribute).
  # Base64 é encoding, não criptografia — o script decodifica em runtime
  # antes de qualquer redirecionamento de log.
  user_data = templatefile("${path.module}/user_data.sh", {
    rds_endpoint              = var.rds_endpoint
    rds_port                  = var.rds_port
    db_name                   = var.db_name
    db_username               = var.db_username
    db_password_b64           = base64encode(var.db_password)
    moodle_admin_password_b64 = base64encode(var.moodle_admin_password)
    project_name              = var.project_name
  })

  # true: se o user_data mudar (ex.: nova senha ou endpoint), Terraform
  # recria a instância para executar o novo script. Correto para este deploy.
  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name
  }
}
