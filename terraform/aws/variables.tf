variable "aws_region" {
  description = "Primary AWS Region"
  type        = string
  default     = "us-east-1"
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
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
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

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
  default     = "OtelLabAwsSecure2026!"
}
