# Data Service — Contrato, Alcance y Operación Multicloud
**Laboratorio Integrador: Observabilidad End-to-End en GCP y AWS**  
**Universidad de La Sabana** · **Repositorio:** `otel-multicloud-aiops-resilience-lab`

---

## 1. Alcance Operativo

Data Service es un microservicio FastAPI desplegado en Kubernetes (`otel-lab`) en el puerto `8002`, encargado de proveer persistencia políglota y telemetría de base de datos multicloud:

* **Endpoint `/data/gcp`:** Conecta directamente a la instancia **Google Cloud SQL PostgreSQL** (`otel-cloudsql-postgres`, IP `34.56.188.238:5432/appdb`), ejecutando la consulta de verificación con auto-instrumentación `Psycopg2Instrumentor`.
* **Endpoint `/data/aws`:** Conecta a la instancia **AWS RDS PostgreSQL** (`otel-rds-postgres` en `us-east-2`, puerto `5432/appdb`), verificando la conectividad cross-cloud desde el clúster GKE hacia la nube de AWS.
* **Health & Readiness:** `/health` y `/ready` validan el estado de vida y disponibilidad del proceso del servicio.

---

## 2. Convenciones Semánticas y Trazabilidad OpenTelemetry

Cada consulta a base de datos genera spans OTel bajo las convenciones semánticas oficiales `db.*`:
* `db.system.name`: `postgresql`
* `db.operation.name`: `SELECT`
* `db.namespace`: `appdb` (o `gcp` / `aws` según backend)
* `cloud.provider`: `gcp` o `aws`

Las credenciales no se exponen en las respuestas HTTP, ni en las trazas ni en los registros de log estructurados. Las cadenas de conexión DSN se inyectan dinámicamente mediante el Kubernetes Secret `otel-lab-secret` (`database-url` y `aws-database-url`).

---

## 3. Inyección de Fallos L7 y Resiliencia (Experimento E2)

Para las pruebas de Chaos Engineering (Experimento E2):
* `FAULT_ENABLED=true`: Habilita la inyección probabilística de fallos en `/data/{backend}`.
* `FAULT_RATE=0.10`: Introduce ~10% de respuestas `HTTP 503 Service Unavailable` con una latencia controlada (`FAULT_DELAY_MS=250`), permitiendo evaluar la capacidad del correlador AIOps y el consumo de presupuesto de error (error budget).
* Durante la operación normal, `FAULT_ENABLED=false` garantiza respuestas 200 continuas.

---

## 4. Evidencias Verificadas en Producción

* **Prueba GCP Cloud SQL:** Respuesta `HTTP 200` con `{"backend":"gcp","database":"appdb","probe":1,"trace_id":"37816e898ccb783a2a71f1349fac1da5"}` ([`evidence/module-a/gcp-cloudsql-evidence.json`](../evidence/module-a/gcp-cloudsql-evidence.json)).
* **Prueba AWS RDS:** Respuesta `HTTP 200` con `{"backend":"aws","database":"appdb","probe":1,"trace_id":"7d0a8ad77b1fdde5744f338f59fc58a9"}` ([`evidence/module-a/aws-rds-evidence.json`](../evidence/module-a/aws-rds-evidence.json)).
* **Traza de 17 Spans:** Verificada en Jaeger conectando `service-a` &rarr; `service-b` &rarr; `data-service` &rarr; `db` ([`evidence/module-a/trace-end-to-end-full.json`](../evidence/module-a/trace-end-to-end-full.json)).
