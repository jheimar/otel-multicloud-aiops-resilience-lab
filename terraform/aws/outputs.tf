output "vpc_id" {
  description = "The ID of the AWS VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "rds_endpoint" {
  description = "The connection endpoint for the AWS RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.postgres.address
}

output "database_url_aws_example" {
  description = "Formato de conexion DATABASE_URL_AWS para data-service"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
  sensitive   = true
}

output "flow_logs_group_name" {
  description = "CloudWatch log group for VPC flow logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
