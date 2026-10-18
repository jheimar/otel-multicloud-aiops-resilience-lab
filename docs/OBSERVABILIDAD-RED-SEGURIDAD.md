# Observabilidad de red y seguridad — GCP

## Alcance

El módulo C de la actividad exige VPC Flow Logs en **GCP y AWS**, un servicio de seguridad (Security Command Center o Security Hub), alertas de tráfico anómalo y un dashboard de señales de seguridad: autenticación fallida, tráfico norte-sur y este-oeste y CVEs activos.

Por el momento el entorno AWS se encuentra restringido por una **Service Control Policy explícita** que bloquea `rds:DescribeDBInstances` y `ec2:DescribeVpcs`. La identidad IAM por sí sola no concede esos permisos. No se atribuirá evidencia funcional a AWS hasta contar con autorización organizacional.

## Implementación GCP: red

En el proyecto de sandbox se usa GKE sobre la subred `default` en `us-central1`. La automatización `scripts/fase4_observabilidad_gcp.sh` verifica la subred; si Flow Logs no estaba habilitado y la identidad tiene permisos, lo activa con agregación de 1 minuto, muestreo secundario 0,1 y sin metadatos, para limitar volumen y riesgo de exposición. La actualización **puede generar costos de Cloud Logging** y afecta a la subred, no únicamente al namespace.

La presencia de una configuración activa y la existencia de entradas en Cloud Logging son **dos validaciones distintas**. Los resultados concretos se escriben en `evidence/module-c/<timestamp>/flowlogs-config.json` y `vpc-flow-evidence.json`. Una consulta sin resultados puede indicar retraso, muestreo, ausencia de tráfico capturado o falta de permisos: nunca interpretar `0` como ausencia demostrada de comunicaciones.

## Implementación GCP: seguridad

La misma automatización consulta hallazgos de Security Command Center por proyecto. Si el servicio no está habilitado o faltan permisos, registra `unavailable_or_access_denied`. No crea hallazgos artificiales ni concluye ausencia de vulnerabilidades cuando la respuesta está vacía.

## Señales de seguridad previstas

| Señal | Fuente de datos | Criterio de aceptación |
|---|---|---|
| Autenticaciones fallidas | Logs de aplicación/autenticación | Eventos 401/403 con servicio, timestamp y frecuencia |
| Norte-sur y este-oeste | VPC Flow Logs GCP y AWS | Flujos etiquetados por origen/destino y dirección verificable |
| CVE activos | SCC/Security Hub o escaneo de imágenes | Inventario verificable con severidad y recurso afectado |
| Tráfico anómalo | Línea base de Flow Logs y alerta operativa | Evento real con tiempo de detección |

El dashboard de Grafana incluido es una **plantilla local** para logs disponibles; no ingiere automáticamente Flow Logs ni SCC. Por tanto, no puede presentarse como dashboard de seguridad completo hasta integrar esas fuentes y verificar paneles.

## Referencias de implementación

- [GCP: configuración de VPC Flow Logs](https://cloud.google.com/vpc/docs/using-flow-logs)
- [GCP: listado de hallazgos de Security Command Center](https://cloud.google.com/security-command-center/docs/how-to-api-list-findings)
