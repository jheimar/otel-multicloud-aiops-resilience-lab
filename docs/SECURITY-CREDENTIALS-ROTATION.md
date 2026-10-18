# Protocolo de Rotación de Credenciales y Remediación de Secretos Históricos

**Laboratorio Integrador de Observabilidad, AIOps y Resiliencia Multicloud**  
**Fecha:** 18 de octubre de 2026  
**Clasificación:** DevSecOps / SRE Security Compliance  
**Estado:** Remediation Completed & Verified  

---

## 1. Resumen Ejecutivo del Hallazgo de Seguridad

Durante la auditoría de seguridad del código de infraestructura como código (IaC), se identificó que versiones preliminares contenían contraseñas de bases de datos predeterminadas (*hardcoded secrets*) en variables locales de Terraform (`terraform/aws/variables.tf` y `terraform/gcp/variables.tf`).

Aunque en la versión actual (`main`) se eliminaron todos los valores por defecto exigiendo inyección externa segura vía `TF_VAR_db_password`, las cadenas de texto permanecían indexadas en el árbol inmutable de commits anteriores de Git (`ebedd0c`, `8345a91`).

Siguiendo las mejores prácticas de la industria (**NIST SP 800-53 Rev. 5 IA-5: Authenticator Management** y **CIS AWS/GCP Database Benchmark**), la remediación de seguridad no se limita a limpiar el archivo en el commit más reciente, sino que exige un protocolo de **invalidación inmediata de credenciales activas**, rotación en los motores de base de datos gestionados y parametrización desacoplada.

---

## 2. Acciones de Remediación Ejecutadas

### 2.1 Invalidación y Rotación en AWS RDS PostgreSQL
1. **Generación de Secreto Criptográfico:** Se generó una clave aleatoria de 32 caracteres con alta entropía mediante generador CSPRNG (`openssl rand -base64 24`).
2. **Aplicación en AWS RDS:** Se ejecutó la actualización directa sobre la instancia `otel-rds-postgres` en AWS `us-east-2` mediante Terraform y AWS CLI (`aws rds modify-db-instance --master-user-password ... --apply-immediately`).
3. **Revocación de Credenciales Previas:** La contraseña histórica quedó instantáneamente invalidada a nivel del motor PostgreSQL en AWS; cualquier intento de conexión con la contraseña antigua es rechazado con error `FATAL: password authentication failed for user "postgres"`.

### 2.2 Invalidación y Rotación en GCP Cloud SQL PostgreSQL
1. **Actualización de Usuario:** Se rotó la contraseña del usuario `postgres` en la instancia `otel-cloudsql-postgres` (`us-central1`).
2. **Revocación en Cloud SQL:** Las sesiones existentes fueron purgadas y la contraseña previa quedó inutilizada.

### 2.3 Sincronización en Cargas de Trabajo de Kubernetes
1. **Actualización de Kubernetes Secret:** Se actualizó el secreto `otel-lab-secret` en el namespace `otel-lab`:
   ```bash
   kubectl set data secret otel-lab-secret -n otel-lab \
     --from-literal=db-password="<NEW_ROTATED_SECRET>" \
     --from-literal=aws-database-url="postgresql://postgres:<NEW_ROTATED_SECRET>@otel-rds-postgres.cp4a4is2qnjx.us-east-2.rds.amazonaws.com:5432/appdb"
   ```
2. **Reinicio Controlado de Microservicios:** Se ejecutó `kubectl rollout restart deployment data-service -n otel-lab` garantizando que los pods activos consumen el nuevo secreto sin interrupción de servicio.
3. **Verificación Operacional:** Las consultas cruzadas a Cloud SQL y AWS RDS (`GET /data/aws` y `GET /order/ord-001/observed`) continuaron respondiendo con código HTTP 200 y trazas distribuidas completas.

---

## 3. Política de Gestión de Historial de Git vs. Rotación Activa

En ingeniería de seguridad y DevSecOps existen dos estrategias complementarias ante la exposición de credenciales en Git:

| Estrategia | Alcance | Ventajas | Limitaciones / Riesgos | Estado en el Lab |
| :--- | :--- | :--- | :--- | :--- |
| **Rotación e Invalidación Activa (Mandatoria)** | Invalidación inmediata de la credencial en el plano de datos (Cloud SQL / RDS). | Anula el vector de ataque real. Si la credencial antigua es extraída del historial, carece de privilegios y es rechazada. | Requiere coordinación de reinicio en clientes de base de datos. | **100% Ejecutado y Activo** |
| **Reescritura de Historial (`git-filter-repo` / BFG)** | Eliminación de cadenas en los commits previos de Git y force-push (`git push --force`). | Elimina la presencia visual de la cadena en commits históricos en GitHub. | Rompe hashes de commit, tags de auditoría previos (`v1.0`), y sincronización de clones locales de colaboradores. No sustituye la rotación (si la credencial no se rota, sigue siendo vulnerable en clones previos). | **Documentado & Aislado** |

> **Principio de Seguridad Aplicado:**  
> *Una credencial expuesta en cualquier medio (incluso durante 1 segundo) debe considerarse comprometida de forma definitiva.*  
> La única remediación válida y segura es la **rotación inmediata en el servidor de base de datos**. Al invalidar la credencial en AWS RDS y GCP Cloud SQL, cualquier valor presente en los commits antiguos de Git se convierte en un artefacto inofensivo sin valor criptográfico ni acceso al sistema.

---

## 4. Controles Preventivos Implementados (Guardrails)

Para evitar reincidencias en futuros desarrollos:
1. **Pre-commit Scan con Trivy / Git-Secrets:** Se integró análisis estático automatizado que bloquea commits que incluyan patrones de credenciales (`terraform-findings` y `trivy-repo-audit.json`).
2. **Plantillas `terraform.tfvars.example`:** Los repositorios sólo incluyen archivos `.example` con variables vacías o comentadas (`db_password = ""`).
3. **Adopción de Secret Managers:** Se preparó la arquitectura para migración a AWS Secrets Manager y Google Cloud Secret Manager en el ciclo de estabilización (Mes 1).
