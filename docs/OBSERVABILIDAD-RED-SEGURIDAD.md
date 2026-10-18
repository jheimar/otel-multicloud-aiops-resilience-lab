# Observabilidad de Red y Seguridad Multicloud (GCP y AWS)
**Laboratorio Integrador de Observabilidad, AIOps y Resiliencia**  
**Universidad de La Sabana** · **Repositorio:** `otel-multicloud-aiops-resilience-lab` · **Tag:** `v1.0`

---

## 1. Alcance Operativo Multicloud

El Módulo C implementa la observabilidad de red y seguridad integral sobre las dos nubes públicas del laboratorio:
1. **Google Cloud Platform (GCP):** Ingestión de VPC Flow Logs desde la subred de GKE en `us-central1`, análisis analítico de flujos IP y detección de anomalías volumétricas.
2. **Amazon Web Services (AWS):** Ingestión de VPC Flow Logs desde la VPC `vpc-08ae89a92bf8dfef6` en `us-east-2` hacia CloudWatch Logs, evidenciando paquetes rechazados (`REJECT`) por el Security Group de RDS.

---

## 2. Telemetría de Red y Flujos en GCP

* **Configuración:** Activada a nivel de subred en la VPC de GKE (`compute.googleapis.com/vpc_flows`), con intervalo de agregación de 5 segundos, muestreo del 50 % y metadatos completos de VPC.
* **Captura de Evidencia Real:** Archivo [`evidence/module-c/20261018T050010Z/vpc-flow-evidence-real.json`](../evidence/module-c/20261018T050010Z/vpc-flow-evidence-real.json) contiene 20 registros reales extraídos de Cloud Logging con IPs de origen, destino, puertos y volumen de bytes.
* **Clasificación N-S vs E-W (`security/flow_anomaly_detector.py`):**
  - **Tráfico Este-Oeste (E-W):** 15 flujos observados (612 KB) correspondientes a comunicaciones internas entre pods GKE (p. ej., Service A a Data Service en puerto 8002, o scraping de Prometheus hacia pods).
  - **Tráfico Norte-Sur (N-S):** 5 flujos observados (1.12 MB) correspondientes a tráfico hacia APIs externas de Google Cloud y endpoints de telemetría.
* **Regla de Detección de Anomalías:** Alerta `HIGH_VOLUME_NORTH_SOUTH_OUTBOUND` configurada para dispararse ante flujos salientes superiores a 500 KB en una sola ventana. Se evidenció un flujo de 744 KB hacia `173.194.195.95:443` registrado en [`evidence/module-c/20261018T050010Z/network-anomaly-analysis.json`](../evidence/module-c/20261018T050010Z/network-anomaly-analysis.json).

---

## 3. Telemetría de Red y Seguridad en AWS

* **Despliegue y Delimitación Regional:** Mediante auditoría de gobernanza IAM/SCP se constató que la política institucional `p-zsz1ecbo` restringía la región `us-east-1`. El aprovisionamiento se realizó en `us-east-2` (Ohio), donde se desplegaron con éxito 19 recursos de infraestructura.
* **VPC Flow Logs en CloudWatch:** El recurso `aws_flow_log.main` (`fl-063021b836eebcb40`) envía registros continuos hacia el log group `/aws/vpc/otel-lab-flow-logs`.
* **Evidencias de Filtrado de Red (Security Group REJECT):**
  Se capturaron registros reales del log stream `eni-0402db9c75cd153d3-all` en [`evidence/module-c/aws-flow-logs-events.json`](../evidence/module-c/aws-flow-logs-events.json), evidenciando paquetes rechazados ante escaneos externos hacia el puerto SSH (22), HTTP (80) y puertos dinámicos.

---

## 4. Paneles de Seguridad en Grafana

Se importó en Grafana el dashboard [`observability/security-signals-gcp.json`](../observability/security-signals-gcp.json) (`uid: security-signals-gcp`), el cual proporciona:
* Monitoreo de intentos de autenticación fallida y códigos 401/403.
* Gráfico de errores de aplicación 5xx correlacionados en Loki.
* Panel de investigación de logs de Kubernetes para auditoría forense con `trace_id`.
