# =============================================================================
# versions.tf — Requisitos de versão do Terraform e do provider AWS
# =============================================================================
# Este arquivo declara a versão mínima do Terraform e fixa o provider AWS
# na série 5.x. Não contém stubs — é funcional conforme entregue.
# Excluído da verificação de # TODO: por design (ver test_todo_comments.py).
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
