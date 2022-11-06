locals {
  port = 3306
}

data "aws_kms_alias" "db" {
  count = var.create_db_instance && var.kms_key_arn == null && var.kms_key_id == null && var.kms_key_alias != null ? 1 : 0
  name  = var.kms_key_alias
}

data "aws_kms_key" "db" {
  count  = var.create_db_instance && var.kms_key_arn == null && var.kms_key_id != null ? 1 : 0
  key_id = var.kms_key_id
}

resource "random_password" "db" {
  count   = var.create_db_instance ? 1 : 0
  length  = var.random_password_length
  special = false
}

resource "aws_security_group" "db" {
  count  = var.create_db_instance ? 1 : 0
  name   = var.instance_name
  vpc_id = var.vpc_id
  tags   = var.tags

  ingress {
    from_port   = local.port
    to_port     = local.port
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = var.egress_cidrs
  }
}

data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count              = var.create_db_instance ? 1 : 0
  name               = "rds-enhanced-monitoring-${lower(var.instance_name)}"
  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.create_db_instance ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

module "db" {
  # https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest
  source                                = "terraform-aws-modules/rds/aws"
  version                               = "5.1.0"
  create_db_instance                    = var.create_db_instance
  create_db_parameter_group             = true
  parameters                            = var.db_parameters
  db_name                               = var.database_name
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = var.max_allocated_storage
  storage_type                          = var.storage_type
  iops                                  = var.iops
  storage_encrypted                     = true
  kms_key_id                            = var.kms_key_arn != null ? var.kms_key_arn : (var.kms_key_id != null) ? join("", data.aws_kms_key.db.*.arn) : (var.kms_key_alias != null) ? join("", data.aws_kms_alias.db.*.target_key_arn) : null
  auto_minor_version_upgrade            = var.auto_minor_version_upgrade
  apply_immediately                     = var.apply_immediately
  backup_retention_period               = var.backup_retention_period
  copy_tags_to_snapshot                 = var.copy_tags_to_snapshot
  create_db_subnet_group                = true
  create_random_password                = false
  db_instance_tags                      = var.tags
  db_subnet_group_tags                  = var.tags
  deletion_protection                   = var.deletion_protection
  engine                                = "mysql"
  major_engine_version                  = var.major_engine_version
  engine_version                        = var.engine_version
  family                                = var.family
  identifier                            = var.instance_name
  instance_class                        = var.instance_type
  monitoring_interval                   = var.monitoring_interval
  multi_az                              = var.multi_az
  password                              = join("", random_password.db.*.result)
  skip_final_snapshot                   = var.skip_final_snapshot
  snapshot_identifier                   = var.snapshot_identifier
  subnet_ids                            = var.subnet_ids
  tags                                  = var.tags
  username                              = var.username
  vpc_security_group_ids                = [join("", aws_security_group.db.*.id)]
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_role_arn                   = join("", aws_iam_role.rds_enhanced_monitoring.*.arn)
}

module "master_secret" {
  source   = "truemark/rds-secret/aws"
  version  = "1.0.3"
  create = var.create_db_instance && var.create_secrets
  cluster = false
  identifier = module.db.db_instance_id
  name = "master"
  username = module.db.db_instance_username
  password = join("", random_password.db.*.result)
  database_name = var.database_name != null ? var.database_name : "mysql"
}

module "user_secrets" {
  for_each = {for user in var.additional_users: user.username => user}
  source   = "truemark/rds-secret/aws"
  version  = "1.0.3"
  create = var.create_db_instance && var.create_secrets
  cluster = false
  identifier = module.db.db_instance_id
  name = each.value.username
  database_name = each.value.database_name
}
