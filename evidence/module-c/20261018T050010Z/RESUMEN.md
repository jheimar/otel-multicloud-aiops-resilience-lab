# Cierre técnico incremental — Observabilidad GCP

La evidencia de esta fase es **una consulta real**, no una simulación. No equivale a validación de AWS ni a cumplimiento total de la rúbrica.

| Capacidad | Resultado observado |
|---|---|
| Integración de Service A | ok |
| Traza consultada en Jaeger | found |
| API Prometheus | api_ok |
| Loki /ready | unavailable |
| VPC Flow Logs subred default | enabled_by_script |
| Registros Flow Logs recuperados | 0 |
| Security Command Center | unavailable_or_access_denied |
| Número de hallazgos (si accesible) | None |
| NetworkChaos E1 | not_present |
| Data Service inyección de fallos | disabled |

**Limitaciones:** solo GCP. AWS RDS/VPC está bloqueado por SCP. No hay evidencia operativa de Cloud SQL, Cloud Service Mesh ni alerta gestionada de anomalías. Consultar un backend no demuestra por sí solo que todos sus datos estén correlacionados. Un panel vacío no equivale a cero errores. VPC Flow Logs se basa en muestreo y puede tener retraso de ingesta.

Los archivos JSON de este directorio conservan los resultados específicos; el contenido resumido evita publicar secretos y direcciones IP de la VPC.
