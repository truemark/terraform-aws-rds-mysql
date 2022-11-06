variable "create_db_instance" {
  description = "Whether to create the database instance"
  type        = bool
  default     = true
}

variable "ingress_cidrs" {
  description = "List of allowed CIDRs that can access this RDS instance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "egress_cidrs" {
  description = "List of allowed CIDRs that this RDS instance can access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "copy_tags_to_snapshot" {
  description = "Copy all cluster tags to snapshots"
  type        = bool
  default     = false
}

variable "create_secrets" {
  description = "Toggle on or off storing passwords in AWS Secrets Manager."
  type        = bool
  default     = true
}

variable "random_password_length" {
  description = "The length of the password to generate for root user."
  type        = number
  default     = 16
}

variable "username" {
  description = "The master database account to create."
  type        = string
  default     = "admin" # This is the default in the AWS console
}

variable "create_security_group" {
  description = "Whether to create the security group for the RDS instance"
  default     = true
  type        = bool
}

variable "security_group_tags" {
  description = "Additional tags for the security group"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The ID of the VPC to provision into"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to use"
  type        = list(string)
}

variable "allocated_storage" {
  description = "Storage size in GB."
  default     = 100
}

variable "max_allocated_storage" {
  description = "Maximum storage size in GB."
  default     = 500
}

variable "storage_type" {
  description = "One of 'standard', 'gp2' or 'io1'."
  type        = string
  default     = "io1"
}

variable "iops" {
  description = "The amount of provisioned IOPS. Setting implies a storage_type of io1."
  type        = number
  default     = 500
}

variable "kms_key_arn" {
  description = "The KMS key to use. Setting this overrides any value put in kms_key_id and kms_key_alias."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "The ID of the KMS key to use. Setting this overrides any value put in kms_key_alias."
  type        = string
  default     = null
}

variable "kms_key_alias" {
  description = "The alias of the KMS key to use."
  type        = string
  default     = null
}

variable "db_parameters" {
  description = "Map of parameters to use in the aws_db_parameter_group resource"
  type        = list(map(any))
  default     = []
}

variable "db_parameter_group_tags" {
  description = "A map of tags to add to the aws_db_parameter_group resource if one is created."
  default     = {}
}

variable "instance_name" {
  description = "Name for the db instance. This will display in the console."
  type        = string
}

# aws rds describe-db-engine-versions --query "DBEngineVersions[].DBParameterGroupFamily"
variable "family" {
  description = "The DB parameter group family name"
  type        = string
  default     = "mysql8.0"
}

variable "major_engine_version" {
  description = "MySQL database engine version."
  type        = string
  default     = "8.0"
}

variable "engine_version" {
  description = "MySQL database engine version."
  type        = string
  default     = "8.0.30"
}

variable "instance_type" {
  description = "Instance type to use at master instance. If instance_type_replica is not set it will use the same type for replica instances"
  type        = string
  default     = "db.t4g.small"
}

variable "apply_immediately" {
  description = "Determines whether or not any DB modifications are applied immediately, or during the maintenance window"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Should a final snapshot be created on cluster destroy"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "How long to keep backups for (in days)"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "When to perform DB backups"
  type        = string
  default     = "02:00-03:00" # 7PM-8PM MST
}

variable "preferred_maintenance_window" {
  description = "When to perform DB maintenance"
  type        = string
  default     = "sat:03:00-sat:05:00" # 8PM-10PM MST
}

variable "deletion_protection" {
  description = "Sets deletion protection on the instance"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "DB snapshot to create this database from"
  type        = string
  default     = null
}

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0."
  type        = number
  default     = 60
}

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window."
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ."
  type        = bool
  default     = false
}

variable "database_name" {
  description = "Name for the database to be created."
  type        = string
  default     = null
}

variable "additional_users" {
  description = "Additional users to generate secrets for"
  type = list(object({
    username      = string
    database_name = string
  }))
  default = []
}
