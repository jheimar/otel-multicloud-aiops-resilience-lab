variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "project-138a5e79-5342-4c60-94f"
}

variable "region" {
  description = "Primary GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary GCP Zone"
  type        = string
  default     = "us-central1-b"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "otel-lab-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range for the primary GKE subnet"
  type        = string
  default     = "10.128.0.0/20"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "otel-chaos-gameday"
}

variable "db_instance_name" {
  description = "Cloud SQL Instance Name"
  type        = string
  default     = "otel-cloudsql-postgres"
}

variable "db_name" {
  description = "Database name inside Cloud SQL"
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Database user for application"
  type        = string
  default     = "oteluser"
}

variable "db_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true
  default     = "OtelLabSecure2026!"
}
