variable "aws_region" {
  description = "Primary AWS Region (Authorized region in AWS Organization)"
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "AWS CLI profile name configured locally"
  type        = string
  default     = "otel-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment in us-east-2"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (RDS)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "db_instance_identifier" {
  description = "Identifier for AWS RDS PostgreSQL"
  type        = string
  default     = "otel-rds-postgres"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "oteladmin"
}

variable "allowed_ingress_cidrs" {
  description = "Allowed CIDR blocks for RDS PostgreSQL ingress (restricts public access)"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.128.0.0/20"]
}

variable "db_password" {
  description = "Master password for RDS (Must be passed via TF_VAR_db_password or secure secret manager)"
  type        = string
  sensitive   = true
}
