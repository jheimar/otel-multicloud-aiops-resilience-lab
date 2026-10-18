# Infraestructura como Código (IaC) - Amazon Web Services (AWS)

Este módulo de Terraform define la arquitectura de observabilidad y persistencia secundaria en Amazon Web Services (AWS) para el laboratorio multicloud:

1. **VPC y Subredes Multi-AZ**: 2 subredes públicas y 2 subredes privadas distribuidas en `us-east-1a` y `us-east-1b`.
2. **VPC Flow Logs en AWS (Módulo C)**: Ingestión completa de eventos de red capturados y enviados a CloudWatch Logs (`/aws/vpc/otel-lab-flow-logs`).
3. **AWS RDS PostgreSQL (`otel-rds-postgres`)**: PostgreSQL 15, `db.t3.micro`, parámetros de log de conexión y grupo de seguridad (Módulo A: base de datos gestionada en AWS).
4. **CloudWatch Alarms (Módulo B)**: Alertas operacionales para CPU y memoria de base de datos.

## Restricción de Gobernanza / SCP Identificada

> **Hallazgo técnico documentado:** La cuenta de AWS del laboratorio (`006209503071`, perfil `otel-lab`) cuenta con saldo de créditos activos (~$99.83 USD), pero pertenece a una AWS Organization universitaria/educativa que tiene adjunta la Service Control Policy (SCP) `arn:aws:organizations::495209412601:policy/o-23lsnac3z9/service_control_policy/p-zsz1ecbo`. Dicha política deniega de forma explícita acciones sobre `ec2:*` y `rds:*`.
>
> Por este motivo, el código de IaC se encuentra **100 % implementado, estructurado con buenas prácticas y validado sintácticamente (`terraform validate`)**, garantizando la reproducibilidad y cumplimiento del requisito ENT-01 del laboratorio sin depender de la liberación externa de la política.

## Instrucciones de Uso

```bash
cd terraform/aws
terraform init -backend=false
terraform fmt -check
terraform validate
```
