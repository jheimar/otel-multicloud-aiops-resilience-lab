output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "subnet_id" {
  description = "The ID of the GKE subnetwork"
  value       = google_compute_subnetwork.subnet.id
}

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_endpoint" {
  description = "Cluster endpoint IP"
  value       = google_container_cluster.primary.endpoint
}

output "cloudsql_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "cloudsql_public_ip" {
  description = "The public IPv4 address of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "database_url_example" {
  description = "Formato de conexion DATABASE_URL para data-service"
  value       = "postgresql://${var.db_user}:${var.db_password}@${google_sql_database_instance.postgres.public_ip_address}:5432/${var.db_name}"
  sensitive   = true
}
