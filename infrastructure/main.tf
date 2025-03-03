terraform {
  required_version = "~> 1.3"

  backend "s3" {
    bucket  = "s3-ror"
    key     = "tf-infra/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

module "tf_state" {
  source      = "./modules/tf-state"
  bucket_name = local.bucket_name
  table_name  = local.table_name
  output "vpc_id" {
    value = aws_vpc.main.id
  } 
}

module "ecrRepo" {
  source = "./modules/ecr"

  ecr_repo_name  = local.ecr_repo_name
  ecr_repo_name1 = local.ecr_repo_name1
  ecr_repo_name2 = local.ecr_repo_name2
  ecr_repo_name3 = local.ecr_repo_name3
}

module "ecsCluster" {
  source = "./modules/ecs"

  ror_app_cluster_name = local.ror_app_cluster_name
  availability_zones   = local.availability_zones

  ror_app_task_family          = local.ror_app_task_family
  ecr_repo_url                 = module.ecrRepo.repository_url
  ecr_repo_url1                = module.ecrRepo.repository_url1
  ecr_repo_url2                = module.ecrRepo.repository_url2
  ecr_repo_url3                = module.ecrRepo.repository_url3
  container_port               = local.container_port
  container_port1              = local.container_port1
  container_port2              = local.container_port2
  ror_app_task_name            = local.ror_app_task_name
  ror_app_task_name1           = local.ror_app_task_name1
  ror_app_task_name2           = local.ror_app_task_name2
  ror_app_task_name3           = local.ror_app_task_name3
  ecs_task_execution_role_name = local.ecs_task_execution_role_name
  vpc_id                       = "${module.tf_state.vpc-id}"
}
