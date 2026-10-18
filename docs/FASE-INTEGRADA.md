# Entrega técnica agrupada — Data Service, A→Data Service y base AIOps

**Estado:** código preparado y probado sintácticamente, NO desplegado mediante este paquete.

- Se corrige el requisito `GCP_DATABASE_URL` utilizando `otel-lab-secret`/`DATABASE_URL`, que pertenece al PostgreSQL sandbox existente en GKE. **Esto NO implementa Cloud SQL**.
- Se reutiliza Service B. Se extiende Service A con `GET /order/{order_id}/observed`, que consulta su pedido y luego Data Service con HTTPX, propagando el contexto W3C.
- Data Service activa fallas HTTP 503 de forma opcional, probabilística, y con latencia inyectada de 250ms para poder probar una correlación de errores+P99. **Predeterminado: deshabilitado**.
- El módulo `aiops/correlation.py` implementa la conjunción `error_rate > media+2*sigma Y p99 > SLO` y alerta de solo latencia para E1, con pruebas unitarias. **Todavía no es un detector desplegado ni utiliza Cloud Monitoring**.
- `scripts/execute_integrated_phase.sh` comprueba precondiciones, construye/publica dos imágenes, despliega y valida datos, sin configurar AWS ni ejecutar caos. Su ejecución afecta Service A y Data Service. **No correr sobre recursos compartidos**.

## Limitaciones de la rúbrica
AWS RDS/VPC sigue bloqueado por SCP; Cloud SQL y Cloud Service Mesh siguen pendientes. Las alertas AIOps con MTTD aún requieren integración operacional, las evidencias de Flow Logs y los dos nuevos experimentos no se han realizado. La evidencia del PostgreSQL en GKE no reemplaza Cloud SQL.

## Validación local realizada durante preparación
Compilación de Python, pruebas de correlación, sintaxis shell y validación YAML; el despliegue real solo puede validarse con permisos y acceso al clúster del usuario.
