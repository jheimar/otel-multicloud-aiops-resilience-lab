# Alcance técnico — fase 1

**Confirmado en el entorno anterior:** GKE activo, namespace `otel-lab`, Service A (1/1), Service B (2/2), PostgreSQL, Collector, Prometheus, Grafana, Jaeger, Loki y Promtail. AWS STS respondió con un usuario IAM, pero aún no confirma permisos para aprovisionamiento.

**Pendiente de implementar:** tercer servicio y accesos a Cloud SQL y RDS; IaC para nuevos recursos; service mesh L7; tres pilares con database spans; detección estadística de anomalías y alerta enriquecida; Flow Logs en dos nubes; hallazgos de seguridad; dos ensayos integradores con MTTD y error budget.

**Límite de seguridad:** no modificar el trabajo previo ni ejecutar caos fuera de un sandbox aislado. Validar rutas seguras hacia las bases antes de aprovisionar. Las credenciales nunca irán a Git.

**E1 anterior:** la plantilla de `chaos/e1-network-latency.yaml` es referencia; las capturas y resultados antiguos no se consideran pruebas del nuevo integrador.
