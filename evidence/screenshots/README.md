# Galería de Evidencias Visuales y Capturas Operacionales (Screenshots)
**Laboratorio Integrador: Sistema de Observabilidad End-to-End con AIOps y Resiliencia en GCP y AWS**  
**Catálogo de Evidencias Operacionales y Métricas de Validación**  
**Repositorio:** `otel-multicloud-aiops-resilience-lab` · **Tag:** `v1.0` · **Fecha:** Octubre 2026

Este directorio consolida las capturas de pantalla de alta resolución obtenidas directamente desde las consolas e interfaces gráficas del laboratorio desplegado en vivo, acreditando el cumplimiento de la rúbrica oficial.

---

## 1. Módulo A: Trazabilidad Distribuida End-to-End en Jaeger (17 Spans)
* **Archivo:** [`01_jaeger_distributed_trace_17_spans.png`](01_jaeger_distributed_trace_17_spans.png)
* **Criterio Evaluado:** *A-01, A-02, A-03, A-04, A-07 (Arquitectura Observable Completa - 1.25 pts)*
* **Descripción Técnica:** Captura de la interfaz oficial de Jaeger UI (`http://localhost:16686`) inspeccionando la traza distribuida `37816e898ccb783a2a71f1349fac1da5` con 17 spans de profundidad 5. Demuestra la propagación síncrona de contexto W3C (`traceparent`) a través de la cadena de microservicios:
  1. `service-a`: Gateway HTTP `GET /order/{order_id}/observed`
  2. `service-a` &rarr; `fetch.order.db` &rarr; `SELECT`: consulta de orden en base de datos.
  3. `service-a` &rarr; `service-b`: llamada HTTP con inyección automática de contexto hacia `GET /inventory/{product_id}` (`inventory.cache.hit`).
  4. `service-a` &rarr; `data-service`: llamada HTTP hacia `GET /data/{backend}` conectando con Cloud SQL PostgreSQL (`34.56.188.238:5432/appdb`) bajo atributos semánticos `db.*`.

![Jaeger 17 Spans Trace](01_jaeger_distributed_trace_17_spans.png)

---

## 2. Módulo A y D: Panel de Métricas Operacionales en Grafana (Game Day)
* **Archivo:** [`02_grafana_gameday_dashboard.png`](02_grafana_gameday_dashboard.png)
* **Criterio Evaluado:** *A-05, A-06, D-01 (Métricas de Capacidad y Resiliencia)*
* **Descripción Técnica:** Captura del dashboard oficial *Game Day - OTEL* en Grafana (`http://localhost:3000/d/gameday/game-day-otel`) alimentado por Prometheus. Exhibe:
  - **Throughput (RPS):** `sum(rate(http_requests_total[2m]))`
  - **Latencia P95:** `histogram_quantile(0.95, sum by(le)(rate(http_request_duration_seconds_bucket[2m])))`
  - **Respuestas 5xx:** Detección de picos durante inyección de fallos HTTP.
  - **Disponibilidad de Scraping:** `avg(up) = 1` continuo sobre los servicios.

![Grafana Game Day Dashboard](02_grafana_gameday_dashboard.png)

---

## 3. Módulo C: Panel de Señales de Seguridad y Logs en Loki
* **Archivo:** [`03_grafana_security_signals_loki_dashboard.png`](03_grafana_security_signals_loki_dashboard.png)
* **Criterio Evaluado:** *C-01, C-02, C-03 (Observabilidad de Red y Seguridad - 1.00 pts)*
* **Descripción Técnica:** Captura del dashboard de seguridad (`security-signals-gcp`) en Grafana correlacionando los flujos de log en Loki de las últimas 24 horas. Muestra los eventos de investigación de pods de Kubernetes y la gráfica temporal de errores de aplicación disparados durante las pruebas controladas.

![Grafana Security Signals Dashboard](03_grafana_security_signals_loki_dashboard.png)

---

## 4. Módulo A: Estado de Scrape Targets en Prometheus
* **Archivo:** [`04_prometheus_targets_up.png`](04_prometheus_targets_up.png)
* **Criterio Evaluado:** *A-05 (Monitoreo de Infraestructura y Colector OTel)*
* **Descripción Técnica:** Captura de la consola de Prometheus (`http://localhost:9090/targets`) evidenciando que el colector central OpenTelemetry (`http://otel-collector:8889/metrics`) se encuentra en estado `UP` con intervalo de recolección activo cada 15 segundos.

![Prometheus Targets UP](04_prometheus_targets_up.png)

---

## 5. Módulo B y D: Histograma de Peticiones y Errores en Prometheus UI
* **Archivo:** [`05_prometheus_http_requests_graph.png`](05_prometheus_http_requests_graph.png)
* **Criterio Evaluado:** *B-01, D-02 (Monitoreo de SLIs y Presupuesto de Error)*
* **Descripción Técnica:** Gráfica de series de tiempo en Prometheus evaluando la métrica `http_requests_total` separada por clase de código (`status="2xx"` y `status="5xx"`), registrando el volumen de peticiones exitosas y el impacto medido del experimento de inyección de errores HTTP.

![Prometheus HTTP Requests Graph](05_prometheus_http_requests_graph.png)

---

## 6. Módulos A, B y C: Evidencias Operacionales en Vivo (Terminal Multicloud)
* **Archivo:** [`06_multicloud_live_operational_evidence.png`](06_multicloud_live_operational_evidence.png)
* **Criterio Evaluado:** *A-04, B-05, C-01 (Verificación Multicloud Completa)*
* **Descripción Técnica:** Consolidación de terminal con la salida de comandos en vivo:
  - **GCP Cloud SQL:** `gcloud sql instances describe otel-cloudsql-postgres` (`state: RUNNABLE`, IP `34.56.188.238`) y consulta `curl /data/gcp` con `HTTP 200 OK`.
  - **AWS RDS:** `aws rds describe-db-instances` (`state: available`, endpoint `otel-rds-postgres.cp4a4is2qnjx.us-east-2.rds.amazonaws.com`) y consulta `curl /data/aws` con `HTTP 200 OK`.
  - **AWS VPC Flow Logs:** Registros reales extraídos del log stream CloudWatch `eni-0402db9c75cd153d3-all` evidenciando acciones `REJECT` del Security Group ante escaneos de red no autorizados.
  - **AIOps Benchmark:** Salida del evaluador cuantitativo con el benchmark dual (70.0% canónico + 42.86% telemetría observada en vivo).

![Multicloud Operational Evidence](06_multicloud_live_operational_evidence.png)
