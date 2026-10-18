# Data Service — contrato y alcance real

- API HTTP FastAPI en puerto 8002; `/health` y `/ready` son checks de proceso.
- `GET /data/gcp` consulta Cloud SQL; `GET /data/aws` consulta RDS, **solo cuando haya conectividad y credenciales autorizadas**.
- Cada consulta genera spans OTel de aplicación y spans DB por auto-instrumentación psycopg2; las métricas se exportan por OTLP a Collector y los logs JSON a stdout.
- Las convenciones `db.system.name`, `db.operation.name` y `db.namespace` se usan sin valores SQL sensibles.
- Errores L7: `FAULT_ENABLED=true` con `FAULT_RATE=0.10` provoca ~10% de respuestas 503 en `/data/{backend}`. La probabilidad observada debe medirse con suficiente tráfico; 10% es expectativa estadística, no garantía exacta.
- Los errores de conectividad real devuelven 503 sin publicar credenciales. Hasta aprovisionar Cloud SQL/RDS, los endpoints de datos **no son funcionales**.
- Para no alterar el ambiente anterior, la plantilla Kubernetes no está aplicada ni incorpora credenciales: se debe reemplazar la imagen y provisionar un Secret fuera de Git.
- AWS actualmente presenta prohibición explícita de SCP sobre RDS y VPC. **No afirmar integración AWS activa** hasta que un administrador resuelva la restricción.
- El flujo Service A → Data Service requiere integrar una nueva llamada en Service A; **todavía no está hecho**. Este parche incorpora únicamente el tercer servicio y manifiestos de despliegue.
