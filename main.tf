locals {
  port = 3306
}

module "standard_tags" {
  source  = "truemark/standard-tags/aws"
  version = "1.0.0"
  automation_component = {
    id     = "terraform-aws-rds-mysql"
    url    = "https://registry.terraform.io/modules/truemark/rds-mysql"
    vendor = "TrueMark"
  }
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
  tags   = merge(var.tags, var.security_group_tags, module.standard_tags.tags)

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
  tags               = merge(var.tags, module.standard_tags.tags)
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
  db_instance_tags                      = merge(var.tags, module.standard_tags.tags)
  db_subnet_group_tags                  = merge(var.tags, module.standard_tags.tags)
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
  tags                                  = merge(var.tags, module.standard_tags.tags)
  username                              = var.username
  vpc_security_group_ids                = [join("", aws_security_group.db.*.id)]
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = 7
  monitoring_role_arn                   = join("", aws_iam_role.rds_enhanced_monitoring.*.arn)
}

module "master_secret" {
  source        = "truemark/rds-secret/aws"
  version       = "1.0.6"
  create        = var.create_db_instance && var.create_secrets
  cluster       = false
  identifier    = module.db.db_instance_id
  name          = "master"
  username      = module.db.db_instance_username
  password      = join("", random_password.db.*.result)
  database_name = var.database_name != null ? var.database_name : "mysql"
  tags          = var.tags
}

module "user_secrets" {
  for_each      = { for user in var.additional_users : user.username => user }
  source        = "truemark/rds-secret/aws"
  version       = "1.0.6"
  create        = var.create_db_instance && var.create_secrets
  cluster       = false
  identifier    = module.db.db_instance_id
  name          = each.value.username
  database_name = each.value.database_name
  tags          = var.tags
}

#Common Mysql Admin Prod
#Common MySQL WordPress Prod

locals {
  sdm_instance_name = trimspace(title(replace(replace(var.instance_name, "_", " "), "-", " ")))
  sdm_database_name = trimspace(var.database_name != null ? title(replace(replace(var.database_name, "_", " "), "-", " ")) : local.sdm_instance_name)
  sdm_designation   = trimspace(var.username == var.database_name ? local.sdm_database_name : "${local.sdm_database_name} ${title(replace(replace(var.username, "_", " "), "-", " "))}")
  sdm_environment   = var.sdm_environment != null ? var.sdm_environment : terraform.workspace
  sdm_name          = trimspace("${local.sdm_designation} ${title(local.sdm_environment)}")
  sdm_tags          = merge(local.sdm_environment != "" ? { environment = var.sdm_environment } : {}, var.sdm_tags)
}

resource "sdm_resource" "master" {
  count = var.create_sdm_resources ? 1 : 0
  mysql {
    name     = local.sdm_name
    hostname = module.db.db_instance_address
    port     = local.port
    database = var.database_name == null ? "mysql" : var.database_name
    username = module.db.db_instance_username
    password = module.db.db_instance_password
    tags     = local.sdm_tags
  }
}

resource "sdm_resource" "additional_users" {
  for_each = { for u in var.additional_users : u.username => {
    database_name = u.database_name
    sdm_name      = trimspace("${title(replace(replace(u.username, "_", " "), "-", " "))} ${title(local.sdm_environment)}")
  } if var.create_sdm_resources }
  mysql {
    name     = each.value.sdm_name
    hostname = module.db.db_instance_address
    port     = local.port
    database = each.value.database_name
    username = each.key
    password = module.user_secrets[each.key].password
    tags     = local.sdm_tags
  }
}
