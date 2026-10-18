# Arquitectura de Referencia del Sistema de Observabilidad Multicloud
**Laboratorio Integrador: Observabilidad End-to-End, AIOps y Resiliencia en GCP y AWS**  
**Universidad de La Sabana — Maestría en Gestión y Operaciones Cloud / Observabilidad**  
**Repositorio:** `otel-multicloud-aiops-resilience-lab` · **Tag:** `v1.0` · **Versión:** Final

---

## 1. Visión General de la Arquitectura

El sistema implementa una plataforma distribuida de observabilidad sobre una topología híbrida multicloud desplegada en **Google Cloud Platform (GCP)** y **Amazon Web Services (AWS)**. El diseño desacopla las capas de cómputo, telemetría y persistencia, garantizando la correlación contextual total (logs, métricas y trazas distribuidas) bajo los estándares de la Cloud Native Computing Foundation (CNCF).

```text
                               +-------------------------------------------------------+
                               |              OPEN OBSERVABILITY PLATFORM              |
                               |                                                       |
  +------------------+         |   +-------------------+       +-------------------+   |
  |  HTTP Client /   |         |   |      Jaeger       |       |    Prometheus     |   |
  |  Game Day Tests  |         |   | (Distributed Tr)  |       | (Metrics Engine)  |   |
  +--------+---------+         |   +---------^---------+       +---------^---------+   |
           |                   |             |                             |           |
           v                   |             +-------------+---------------+           |
+--------------------------+   |                           |                           |
|       GKE CLUSTER        |   |                 +---------+---------+                 |
| (us-central1, otel-lab)  |   |                 |   OTel Collector  |                 |
|                          |   |                 |   (gRPC / OTLP)   |                 |
| +----------------------+ |   |                 +---------^---------+                 |
| |      Service A       | |   |                           |                           |
| |   (HTTP Orchestrator)| +---+---------------------------+                           |
| +----------+-----------+ |   |                           |                           |
|            | W3C Trace   |   |                 +---------+---------+                 |
|            v             |   |                 |       Loki        |                 |
| +----------------------+ |   |                 | (Structured Logs) |                 |
| |      Service B       | |   |                 +---------^---------+                 |
| |  (Inventory Engine)  | +---+---------------------------+                           |
| +----------+-----------+ |   |                                                       |
|            | W3C Trace   |   |   +-----------------------------------------------+   |
|            v             |   |   |              Grafana Dashboards               |   |
| +----------------------+ |   |   |  - Game Day OTEL (Throughput, P95, 5xx)       |   |
| |     Data Service     | |   |   |  - Señales de Seguridad y Logs Loki           |   |
| | (Multicloud Client)  | +---+---+-----------------------------------------------+   |
| +----+------------+----+ |   +-------------------------------------------------------+
|      |            |      |
+------|------------|------+
       |            |
       | TCP 5432   | TCP 5432 (Cross-Cloud)
       v            v
+--------------+  +----------------------------------------------------+
|  Cloud SQL   |  |                     AWS RDS                        |
|  PostgreSQL  |  |           PostgreSQL 15 (us-east-2)                |
|  (GCP Cloud) |  |   otel-rds-postgres.cp4a4is2qnjx.us-east-2...      |
|  34.56.188.  |  |   VPC Flow Logs -> CloudWatch Logs -> REJECT drops |
+--------------+  +----------------------------------------------------+
```

---

## 2. Microservicios y Propagación de Contexto (Módulo A)

La arquitectura de microservicios está desarrollada en Python (FastAPI) e instrumentada de forma nativa con el **SDK de OpenTelemetry v1.25+**:

1. **Service A (`service-a` en puerto 8000):**
   - Actúa como API Gateway orquestador.
   - Recibe la petición entrante, crea el *Root Span* y genera el contexto de traza distribuida bajo el estándar **W3C TraceContext** (`traceparent: 00-{trace_id}-{span_id}-01`).
   - Consulta metadatos de órdenes mediante `Psycopg2Instrumentor` (`fetch.order.db`).
   - Propaga los encabezados HTTP W3C hacia `service-b` y hacia `data-service`.

2. **Service B (`service-b` en puerto 8001):**
   - Servicio de inventario y disponibilidad de producto.
   - Extrae el encabezado `traceparent` del request entrante y crea spans hijos (`inventory.cache.hit` o `inventory.cache.miss`).
   - Enriquecido con atributos de negocio para rastreo granular.

3. **Data Service (`data-service` en puerto 8002):**
   - Servicio políglota de persistencia multicloud.
   - Provee las rutas `/data/gcp` y `/data/aws`, conectando directamente a las bases gestionadas en ambas nubes.
   - Emite métricas personalizadas `data_requests_total` y `data_db_duration_seconds`.
   - Incorpora inyección controlada de fallos probabilísticos (`FAULT_RATE=0.10`) y latencias sintéticas para pruebas de resiliencia.

---

## 3. Persistencia Gestionada Multicloud (GCP y AWS)

En estricto apego al requisito de bases de datos gestionadas independientes de los contenedores:

* **Google Cloud SQL:**
  - Instancia: `otel-cloudsql-postgres` (PostgreSQL 15, tier `db-f1-micro`).
  - Endpoint: `34.56.188.238:5432` · Base de datos: `appdb` · Usuario: `oteluser`.
  - Red de acceso: Restringida a las IPs públicas de salida de los nodos GKE (`34.41.148.106/32` y `34.135.197.253/32`) y la IP administrativa autorizada.

* **Amazon Web Services RDS:**
  - Instancia: `otel-rds-postgres` (PostgreSQL 15.13, db.t3.micro).
  - Región: `us-east-2` (Ohio). Desplegado superando la delimitación regional de la SCP corporativa `p-zsz1ecbo`.
  - Endpoint: `otel-rds-postgres.cp4a4is2qnjx.us-east-2.rds.amazonaws.com:5432` · Base de datos: `appdb`.
  - Red de acceso: Subredes privadas de VPC `vpc-08ae89a92bf8dfef6`, con Security Group parametrizado y VPC Flow Logs activos hacia CloudWatch.

---

## 4. Pipeline de Telemetría Unificado

1. **Agente Central OpenTelemetry Collector (`otel-collector:4317`):**
   - Recibe trazas, métricas y logs estructurados vía gRPC OTLP.
   - Realiza batching, enriquecimiento de metadatos de Kubernetes y enrutamiento hacia los backends analíticos.
2. **Trazabilidad Distribuida (Jaeger):**
   - Almacena y visualiza el grafo de dependencias y el árbol de spans.
   - Evidencia capturada: Traza `37816e898ccb783a2a71f1349fac1da5` de 17 spans inter-servicios.
3. **Métricas y SLIs (Prometheus):**
   - Scraping activo cada 15 segundos sobre `/metrics` en el colector OTel y pods de la aplicación.
   - Almacena histogramas de duración de petición (`http_request_duration_seconds`) y contadores de solicitudes por código (`http_requests_total`).
4. **Logs Estructurados (Loki & Promtail):**
   - Ingestión de logs en formato JSON estructurado inyectando `trace_id` y `span_id` en cada línea para permitir correlación bidireccional traza &harr; log.
5. **Visualización Unificada (Grafana):**
   - Dashboards operativos *Game Day - OTEL* y *Señales de Seguridad*.

---

## 5. Detección Inteligente AIOps y Reducción de Ruido (Módulo B)

El motor de detección estadística (`aiops/correlation.py`) evalúa la conjunción de degradación:
$$\text{Alerta Correlacionada} = (\text{error\_rate} > \mu + 2\sigma) \land (\text{latency\_p99} > \text{SLO}_{200\text{ms}})$$

* **Benchmark Sintético Canónico (15 ventanas):** Demuestra una **reducción de ruido del 70.0 %** suprimiendo falsos positivos originados por picos de latencia transitoria o recolección de basura (GC).
* **Telemetría Observada en Vivo (14 ventanas de caos E1 y E2):** En E1 (latencia) suprime el 100 % de falsas alarmas, y en E2 (fallos 503) detecta el 100 % del incidente real, alcanzando un **42.86 % de reducción directa** en condiciones de producción.

---

## 6. Observabilidad de Red y Seguridad (Módulo C)

* **GCP VPC Flow Logs:** Habilitados sobre la subred GKE (5s intervalo, 50% muestreo). El analizador `security/flow_anomaly_detector.py` clasifica el tráfico en Norte-Sur (salidas a APIs de Google) y Este-Oeste (tráfico intra-clúster), detectando flujos anómalos de alto volumen (> 500 KB).
* **AWS VPC Flow Logs:** Habilitados sobre la VPC `vpc-08ae89a92bf8dfef6` con captura directa en CloudWatch Logs (`/aws/vpc/otel-lab-flow-logs`), registrando eventos `REJECT` del Security Group de RDS.

---

## 7. Resiliencia, Chaos Engineering y MTTD (Módulo D)

* **Experimento E1 (Latencia de Red):** Inyección de 200 ms con Chaos Mesh hacia `service-b`. **MTTD = 10.52 s** (SLO &le; 120 s).
* **Experimento E2 (Fallos HTTP 5xx L7):** Inyección de 10% de respuestas 503 en `data-service`. **MTTD = 4.68 s** y recuperación verificada tras rollback.
