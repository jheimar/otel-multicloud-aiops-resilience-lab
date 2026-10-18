# Infraestructura como Código (IaC) - Google Cloud Platform (GCP)

Este módulo de Terraform aprovisiona la infraestructura principal de observabilidad y resiliencia en Google Cloud Platform:

1. **VPC Network y Subnet personalizada**: con **VPC Flow Logs** activados (muestreo 50%, intervalo 5s, metadatos completos).
2. **Cluster GKE (`otel-chaos-gameday`)**: con nodo e2-standard-2, Workload Identity y Google Cloud Managed Service for Prometheus.
3. **Cloud SQL PostgreSQL (`otel-cloudsql-postgres`)**: versión 15, tier `db-f1-micro` (Módulo A: base de datos gestionada).
4. **Google Cloud Monitoring Alert Policies**: Alertas gestionadas para P99 > 200ms y tasa de error HTTP > 5% (Módulo B).

## Instrucciones de Uso

```bash
cd terraform/gcp
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
```
