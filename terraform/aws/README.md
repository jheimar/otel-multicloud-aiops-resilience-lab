# Infraestructura como Código (IaC) - Amazon Web Services (AWS)

Este módulo de Terraform define y aprovisiona la arquitectura de observabilidad y persistencia secundaria en Amazon Web Services (AWS) para el laboratorio multicloud:

1. **VPC y Subredes Multi-AZ en `us-east-2` (Ohio)**: 2 subredes públicas y 2 subredes privadas distribuidas en `us-east-2a` y `us-east-2b` con Internet Gateway y tablas de ruteo dedicadas.
2. **VPC Flow Logs en AWS (Módulo C)**: Ingestión completa de eventos de red capturados y enviados a CloudWatch Logs (`/aws/vpc/otel-lab-flow-logs`).
3. **AWS RDS PostgreSQL (`otel-rds-postgres`)**: Instancia PostgreSQL 15.13 (`db.t3.micro`), almacenamiento GP2, grupo de seguridad y DB subnet group multi-AZ (Módulo A: base de datos gestionada en AWS).
4. **CloudWatch Alarms (Módulo B)**: Alertas operacionales para CPU y memoria libre de base de datos.

## Estado de Despliegue en Vivo y Resolución de Gobernanza

> **Hallazgo técnico resuelto:** La cuenta de AWS del laboratorio (`006209503071`, perfil `otel-lab`) pertenece a una organización con una Service Control Policy (SCP) que restringe la creación de VPC y RDS en `us-east-1`. Tras auditar los permisos regionales de la cuenta administradora, se confirmó que la región autorizada para despliegue es **`us-east-2` (Ohio)**.
> 
> La infraestructura completa fue **desplegada exitosamente mediante `terraform apply`**, quedando la base de datos `otel-rds-postgres` en estado `available` y recibiendo consultas en vivo desde los microservicios en GKE.

## Parámetros de Salida Comprobados

* **VPC ID:** `vpc-08ae89a92bf8dfef6`
* **RDS Endpoint:** `otel-rds-postgres.cp4a4is2qnjx.us-east-2.rds.amazonaws.com:5432`
* **Flow Logs Group:** `/aws/vpc/otel-lab-flow-logs`

## Instrucciones de Uso

```bash
cd terraform/aws
terraform init
terraform fmt -check
terraform validate
AWS_PROFILE=otel-lab terraform apply
```
