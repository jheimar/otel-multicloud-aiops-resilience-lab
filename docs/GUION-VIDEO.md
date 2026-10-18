# Guion Técnico para el Video de Demostración en Vivo (ENT-02)
**Laboratorio Integrador de Observabilidad, AIOps y Resiliencia en GCP y AWS**  
**Duración recomendada:** 6 a 8 minutos  
**Objetivo:** Demostrar en vivo ante el evaluador la arquitectura desplegada, la telemetría end-to-end (trazas, métricas, logs correlacionados), los experimentos de caos ejecutados, los VPC Flow Logs y el análisis de madurez.

---

## 1. Preparación Previa a la Grabación (Checklist)

Abre las siguientes pestañas en tu navegador antes de iniciar a grabar:
1. **Consola GCP:** GKE Workloads (`otel-lab` namespace) y Cloud Logging (`VPC Flow Logs`).
2. **Terminal:** Con conexión a kubectl lista (`kubectl get pods -n otel-lab`).
3. **Grafana:** Dashboards de la aplicación y métricas Prometheus (`http://localhost:3000` o port-forward).
4. **Jaeger UI:** Interfaz web de trazas (`http://localhost:16686` o port-forward).
5. **Repositorio GitHub:** Mostrando la carpeta `terraform/`, `services/`, `aiops/` y `docs/`.

*Comando para habilitar port-forwards locales si deseas mostrarlos en tu navegador:*
```bash
# Terminal 1: Jaeger
kubectl port-forward svc/jaeger -n otel-lab 16686:16686 &
# Terminal 2: Grafana
kubectl port-forward svc/grafana -n otel-lab 3000:3000 &
# Terminal 3: Service-A
kubectl port-forward svc/service-a -n otel-lab 8000:8000 &
```

---

## 2. Estructura Minuto a Minuto del Video

### **Minuto 0:00 - 1:00 | Introducción y Arquitectura Multicloud**
* **Qué mostrar en pantalla:** Diapositiva inicial o el archivo `docs/ARCHITECTURE.md` y el repositorio en GitHub.
* **Qué decir:**
  > "Buenas tardes/días. En este video presentamos la demostración del laboratorio integrador de Observabilidad end-to-end con AIOps y Resiliencia en Google Cloud Platform y AWS.
  > La arquitectura consta de tres microservicios en Python/FastAPI: Service A como orquestador de entrada, Service B para lógica de inventario, y Data Service para persistencia políglota en bases de datos PostgreSQL.
  > Toda la infraestructura fue modelada como código utilizando Terraform modular para GCP y AWS, con OpenTelemetry para la emisión de trazas, métricas y logs estructurados."

---

### **Minuto 1:00 - 2:30 | Demostración de Servicios y Traza End-to-End en Jaeger (Módulo A)**
* **Qué mostrar en pantalla:**
  1. Terminal con `kubectl get pods -n otel-lab` (mostrar los pods en estado `Running`).
  2. Hacer una petición HTTP en terminal al endpoint integrador:
     ```bash
     curl -s http://localhost:8000/order/ord-001/observed | jq .
     ```
  3. Cambiar al navegador a la interfaz de **Jaeger** (`http://localhost:16686`).
  4. Buscar el servicio `service-a`, seleccionar la traza reciente de 17 spans y expandir el árbol.
* **Qué decir:**
  > "Aquí observamos el clúster GKE `otel-chaos-gameday` en GCP con todos los componentes operativos.
  > Ejecutamos una solicitud end-to-end al endpoint `/order/ord-001/observed`. Vemos que nos retorna el pedido, el inventario de Service B y la consulta a base de datos de Data Service, compartiendo el mismo W3C Trace ID.
  > Al abrir Jaeger, vemos la traza distribuida completa con 17 spans: Service A llama a Service B vía HTTP con contexto propagado, ejecuta queries SQL con instrumentación semántica db.*, y se conecta a Data Service. Esto certifica el cumplimiento del Módulo A."

---

### **Minuto 2:30 - 3:45 | Métricas, Logs Correlacionados y Dashboard (Módulo A)**
* **Qué mostrar en pantalla:** Interfaz de **Grafana** o Prometheus.
* **Qué decir:**
  > "En el pilar de métricas, Prometheus recopila de forma continua métricas OTel estandarizadas: latencia P50, P95 y P99 (`http_request_duration_seconds`), conteo de peticiones y latencia de base de datos.
  > En cuanto a logs, están formateados en JSON estructurado e inyectan automáticamente el trace_id y span_id, lo que permite a los operadores saltar de un log de error directamente a la traza en Jaeger con un solo clic, logrando correlación contextual total."

---

### **Minuto 3:45 - 5:15 | AIOps: Detección Estadística y Reducción de Ruido (Módulo B)**
* **Qué mostrar en pantalla:** El script `aiops/noise_reduction_benchmark.py` y el JSON generado `evidence/module-b/noise-reduction-evidence.json`.
* **Qué decir:**
  > "En el Módulo B implementamos un detector estadístico AIOps basado en la regla de correlación: tasa de error superior a la media más dos desviaciones estándar poblacionales, AND latencia P99 superior al SLO de 200 milisegundos.
  > Para validar la reducción de ruido frente a umbrales estáticos convencionales, ejecutamos un benchmark con 15 ventanas temporales simulando tráfico normal, jitter de red transitorio y degradaciones severas.
  > El umbral estático tradicional generó 10 alertas (incluyendo 7 falsos positivos por picos transitorios de latencia). En contraste, nuestro correlador AIOps filtró todo el jitter y generó únicamente 3 alertas legítimas de incidente real, demostrando una **reducción de ruido del 70.0 %** con trace_id enriquecido para diagnóstico inmediato."

---

### **Minuto 5:15 - 6:30 | VPC Flow Logs y Seguridad (Módulo C)**
* **Qué mostrar en pantalla:** Consola de GCP Cloud Logging con el filtro de VPC Flow Logs (`compute.googleapis.com/vpc_flows`) y el archivo `evidence/module-c/20261018T050010Z/network-anomaly-analysis.json`.
* **Qué decir:**
  > "En el Módulo C, habilitamos VPC Flow Logs en la red de GCP, ingiriendo eventos reales de red con direcciones IP de origen, destino, puertos y volumen de bytes.
  > Mediante nuestro analizador de tráfico clasificamos los flujos en Norte-Sur y Este-Oeste, y configuramos una regla de detección de anomalías para identificar flujos salientes de alto volumen (> 500 KB).
  > Respecto a AWS, documentamos técnicamente la existencia de una Service Control Policy (SCP) institucional que bloqueó llamadas a EC2/RDS, manteniendo la IaC 100 % escrita y validada con Terraform."

---

### **Minuto 6:30 - 7:30 | Chaos Engineering: E1, E2 y MTTD (Módulo D)**
* **Qué mostrar en pantalla:** Archivos de evidencia en `evidence/module-d/` (tablas de E1 y E2).
* **Qué decir:**
  > "En el Módulo D ejecutamos dos experimentos de Chaos Engineering:
  > En el Experimento E1 inyectamos 200 ms de latencia mediante NetworkChaos hacia Service B. El sistema registró un MTTD de tan solo 10.52 segundos frente al objetivo de negocio de menos de 120 segundos.
  > En el Experimento E2 inyectamos un 10 % de fallos HTTP 5xx en Data Service (observando 12 % en 200 solicitudes). El MTTD fue de 4.68 segundos, disparando las alertas correlacionadas y demostrando la recuperación total tras retirar el fallo."

---

### **Minuto 7:30 - 8:30 | Blueprint de Madurez, Roadmap y Cierre (Módulo E)**
* **Qué mostrar en pantalla:** El documento `docs/BLUEPRINT-MADUREZ.md` y la estructura final del repositorio.
* **Qué decir:**
  > "Para finalizar, en el Módulo E consolidamos el Blueprint de Madurez evaluando 8 dominios de observabilidad. Nuestro sistema alcanzó un nivel promedio de 3.8 sobre 5.0, destacándose en resiliencia e instrumentación OTel.
  > Planteamos una hoja de ruta a 3 meses: Mes 1 para resolver gobierno AWS y estabilización de IaC; Mes 2 para AIOps en tiempo real y service mesh L7; y Mes 3 para Game Days continuos y FinOps.
  > Toda la infraestructura como código, manifiestos, scripts y evidencias se encuentran versionados en el repositorio público de GitHub bajo el tag v1.0. Muchas gracias."

---

## 3. Consejos para la Grabación
- Habla con ritmo pausado y tono seguro.
- Ten los comandos copiados en un bloc de notas para pegarlos sin demoras.
- Si una ventana tarda un segundo en cargar, aprovecha para explicar el concepto teórico detrás (W3C context propagation, reducción de ruido, etc.).
- Recuerda que la rúbrica premia la honestidad técnica: explicar con precisión las restricciones de SCP y la reducción de ruido del 70% demuestra madurez de ingeniería.
