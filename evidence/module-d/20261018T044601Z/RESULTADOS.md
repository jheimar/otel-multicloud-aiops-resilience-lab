# Evidencia incremental del laboratorio integrador

- E1: executed.
- E2: ejecutado y fallos desactivados.
- Detección: correlador **local experimental**, no servicio gestionado de Cloud Monitoring.
- E1 genera alertas de latencia; no implica necesariamente la regla AND de errores + p99.
- Base de datos: PostgreSQL sandbox en GKE, NO Cloud SQL ni RDS AWS.
- La visibilidad en Jaeger y las capacidades de Security/Network aún requieren comprobación.
