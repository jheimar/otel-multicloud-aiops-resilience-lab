#!/usr/bin/env bash
# Observabilidad GCP — una única ejecución posterior a E1/E2.
# No construye imágenes, no repite caos ni despliega aplicaciones.
set -Eeuo pipefail
export PATH="/usr/local/share/google-cloud-sdk/bin:$PATH"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
PROJECT='project-138a5e79-5342-4c60-94f'
NAMESPACE='otel-lab'
REGION='us-central1'
SUBNET='default'
EXPECTED_REPO='otel-multicloud-aiops-resilience-lab'
cd "$HOME/repositorio/$EXPECTED_REPO"
[[ "$(basename "$(git rev-parse --show-toplevel)")" = "$EXPECTED_REPO" ]] || { echo 'ERROR: repositorio incorrecto'; exit 2; }
[[ "$(gcloud config get-value project 2>/dev/null)" = "$PROJECT" ]] || { echo 'ERROR: proyecto GCP inesperado. No se modifica la red.'; exit 2; }
[[ "$(kubectl config current-context)" == *'otel-chaos-gameday'* ]] || { echo 'ERROR: contexto Kubernetes no corresponde al sandbox.'; exit 2; }
kubectl -n "$NAMESPACE" get deploy service-a service-b data-service >/dev/null

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="evidence/module-c/$TS"
OBS="evidence/module-a/$TS"
mkdir -p "$OUT" "$OBS"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '\n[1/5] Verificando trazas, métricas y logs existentes (sin reinicios)\n'
# Ejecutar desde un pod ya existente para evitar port-forward y procesos auxiliares.
cat > "$TMP/check_telemetry.py" <<'PY'
import json,time,urllib.request,urllib.parse
from datetime import datetime,timezone

def get_json(url,timeout=8):
    with urllib.request.urlopen(url,timeout=timeout) as r: return json.load(r)

results={"timestamp_utc":datetime.now(timezone.utc).isoformat(),"source":"GKE real service endpoints","application":{},"tracing":{},"metrics":{},"logs":{}}
try:
    data=get_json('http://service-a.otel-lab.svc.cluster.local:8000/order/ord-001/observed')
    trace_id=data.get('trace_id','')
    results['application']={"status":"ok","trace_id":trace_id,"data_backend":data.get('data_service',{}).get('database'),"data_probe":data.get('data_service',{}).get('probe')}
except Exception as e:
    trace_id=''; results['application']={"status":"failed","error_class":type(e).__name__}
if len(trace_id)==32:
    for i in range(6):
        try:
            reply=get_json('http://jaeger.otel-lab.svc.cluster.local:16686/api/traces/'+trace_id)
            traces=reply.get('data',[])
            if traces:
                tr=traces[0]
                names=sorted({p.get('serviceName','unknown') for p in tr.get('processes',{}).values()})
                results['tracing']={"status":"found","trace_id":trace_id,"span_count":len(tr.get('spans',[])),"services":names}
                break
        except Exception as e:
            results['tracing']={"status":"query_error","error_class":type(e).__name__}
        time.sleep(5)
    else:
        results['tracing']={"status":"not_found_after_30s","trace_id":trace_id}
else:
    results['tracing']={"status":"not_tested","reason":"no valid trace_id"}
try:
    q=get_json('http://prometheus.otel-lab.svc.cluster.local:9090/api/v1/label/__name__/values')
    names=q.get('data',[])
    related=sorted([x for x in names if 'data_' in x or 'http_server_duration' in x or 'otelcol_' in x])
    results['metrics']={"status":"api_ok","named_series_found":related[:30],"candidate_count":len(related)}
except Exception as e:
    results['metrics']={"status":"unavailable","error_class":type(e).__name__}
try:
    with urllib.request.urlopen('http://loki.otel-lab.svc.cluster.local:3100/ready',timeout=5) as r:
        results['logs']={"status":"backend_ready" if r.status==200 else "backend_unhealthy","http_code":r.status}
except Exception as e:
    results['logs']={"status":"unavailable","error_class":type(e).__name__}
print(json.dumps(results,ensure_ascii=False,indent=2))
PY
if kubectl -n "$NAMESPACE" exec -i deployment/data-service -- python - < "$TMP/check_telemetry.py" > "$OBS/telemetry.json"; then
  python3 - "$OBS/telemetry.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); print('SERVICE_A:',x['application']['status'],'| JAEGER:',x['tracing']['status'],'| PROMETHEUS:',x['metrics']['status'],'| LOKI:',x['logs']['status'])
PY
else
  echo '{"status":"kubectl_exec_failed","claim":"No se verificó la telemetría"}' > "$OBS/telemetry.json"
  echo 'ADVERTENCIA: no se pudo consultar telemetría. La ejecución continuará con GCP.'
fi

printf '\n[2/5] GCP VPC Flow Logs en la subred utilizada por GKE\n'
# Activación limitada: muestreo secundario al 10%, agregación 1 minuto; posible costo de Cloud Logging.
FLOW_STATUS='permission_or_configuration_error'
if gcloud compute networks subnets describe "$SUBNET" --region "$REGION" --project "$PROJECT" --format=json > "$TMP/subnet.json" 2> "$TMP/subnet_error.txt"; then
  WAS_ENABLED="$(python3 - "$TMP/subnet.json" <<'PY'
import json,sys
print('yes' if json.load(open(sys.argv[1])).get('enableFlowLogs',False) else 'no')
PY
)"
  if [[ "$WAS_ENABLED" == 'yes' ]]; then
    FLOW_STATUS='already_enabled'
    echo 'VPC Flow Logs ya estaba habilitado; no se altera su configuración.'
  elif gcloud compute networks subnets update "$SUBNET" --region "$REGION" --project "$PROJECT" --enable-flow-logs --logging-aggregation-interval=interval-1-min --logging-flow-sampling=0.1 --logging-metadata=exclude-all --quiet > "$TMP/flow_update.txt" 2> "$TMP/flow_error.txt"; then
    FLOW_STATUS='enabled_by_script'
    echo 'VPC Flow Logs habilitado; el procesamiento en Cloud Logging puede tardar varios minutos.'
  else
    echo 'VPC Flow Logs: permiso denegado u otro error. Se registrará la limitación.'
  fi
else
  echo 'No fue posible inspeccionar la subred GCP. Se registrará la limitación.'
fi
printf '{"subnetwork":"default","region":"us-central1","project":"%s","flow_logs_status":"%s","aggregation_interval_if_new":"1m","secondary_sample_if_new":0.1,"caveat":"GKE namespace no equivale a subred exclusiva. Los logs pueden representar otros workloads. Cloud Logging puede generar cargos."}\n' "$PROJECT" "$FLOW_STATUS" > "$OUT/flowlogs-config.json"

printf '\n[3/5] Consultando flujos reales (si la ingesta ya terminó)\n'
if gcloud logging read 'log_id("compute.googleapis.com/vpc_flows")' --project="$PROJECT" --freshness=30m --limit=100 --format=json > "$TMP/flows.json" 2> "$TMP/flows_error.txt"; then
  python3 - "$TMP/flows.json" "$OUT/vpc-flow-evidence.json" <<'PY'
import json,sys
from collections import Counter
rows=json.load(open(sys.argv[1])); periods=[x.get('timestamp') for x in rows if x.get('timestamp')]
output={'source':'GCP Cloud Logging - sampled VPC Flow Logs','collection':'actual_query','entries_returned':len(rows),'oldest_utc':min(periods) if periods else None,'newest_utc':max(periods) if periods else None,'caveat':'Las entradas no demuestran necesariamente tráfico exclusivo del experimento; no se publican direcciones IP.'}
open(sys.argv[2],'w').write(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
print('FLOW_LOG_ENTRIES:',len(rows),'(0 = falta ingesta o flujo observable; NO equivale a ausencia de tráfico)')
PY
else
  echo '{"source":"GCP Cloud Logging","collection":"query_failed_or_denied","entries_returned":null}' > "$OUT/vpc-flow-evidence.json"
  echo 'Flow Logs: lectura pendiente por permiso o ingesta.'
fi

printf '\n[4/5] Security Command Center: consulta de hallazgos, sin crear hallazgos ficticios\n'
if gcloud scc findings list "projects/$PROJECT" --location=global --limit=100 --format=json > "$TMP/scc.json" 2> "$TMP/scc_error.txt"; then
  python3 - "$TMP/scc.json" "$OUT/security-findings.json" <<'PY'
import json,sys
from collections import Counter
rows=json.load(open(sys.argv[1])); findings=[r.get('finding',r) for r in rows]
severity=Counter(str(f.get('severity','UNKNOWN')) for f in findings)
states=Counter(str(f.get('state','UNKNOWN')) for f in findings)
out={'source':'Google Security Command Center','query_status':'ok','returned_findings':len(findings),'by_severity':dict(severity),'by_state':dict(states),'caveat':'0 registros no equivale a 0 vulnerabilidades; revisar cobertura y permisos del servicio.'}
open(sys.argv[2],'w').write(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print('SCC_FINDINGS:',len(findings))
PY
else
  echo '{"source":"Google Security Command Center","query_status":"unavailable_or_access_denied","returned_findings":null,"caveat":"No se atribuye cobertura SCC ni ausencia de CVE."}' > "$OUT/security-findings.json"
  echo 'SCC no disponible o acceso insuficiente; se conserva la brecha documentada.'
fi

printf '\n[5/5] Inventario de controles, evidencias y publicación de esta fase\n'
if kubectl -n "$NAMESPACE" get networkchaos integrador-service-b-latency >/dev/null 2>&1; then
  CHAOS_STATE='still_present'
  echo 'ADVERTENCIA: sigue existiendo NetworkChaos del integrador. Revisarlo antes de otra prueba.'
else
  CHAOS_STATE='not_present'
fi
if [[ "$(kubectl -n "$NAMESPACE" get deploy data-service -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="FAULT_ENABLED")].value}' 2>/dev/null)" == 'true' ]]; then
  FAULT_STATE='enabled'
  echo 'ADVERTENCIA: FAULT_ENABLED sigue activo; no ejecutamos nuevo caos.'
else
  FAULT_STATE='disabled'
fi
printf '{"networkchaos_integrador":"%s","data_service_fault":"%s"}\n' "$CHAOS_STATE" "$FAULT_STATE" > "$OUT/chaos-controls.json"
python3 - "$OUT" "$OBS" <<'PY'
import sys,json,pathlib
c=pathlib.Path(sys.argv[1]); a=pathlib.Path(sys.argv[2])
flow=json.loads((c/'flowlogs-config.json').read_text()); log=json.loads((c/'vpc-flow-evidence.json').read_text()); sec=json.loads((c/'security-findings.json').read_text()); tele=json.loads((a/'telemetry.json').read_text()); ctl=json.loads((c/'chaos-controls.json').read_text())
s=f'''# Cierre técnico incremental — Observabilidad GCP

La evidencia de esta fase es **una consulta real**, no una simulación. No equivale a validación de AWS ni a cumplimiento total de la rúbrica.

| Capacidad | Resultado observado |
|---|---|
| Integración de Service A | {tele.get('application',{}).get('status',tele.get('status','sin dato'))} |
| Traza consultada en Jaeger | {tele.get('tracing',{}).get('status','sin dato')} |
| API Prometheus | {tele.get('metrics',{}).get('status','sin dato')} |
| Loki /ready | {tele.get('logs',{}).get('status','sin dato')} |
| VPC Flow Logs subred default | {flow['flow_logs_status']} |
| Registros Flow Logs recuperados | {log.get('entries_returned')} |
| Security Command Center | {sec['query_status']} |
| Número de hallazgos (si accesible) | {sec.get('returned_findings')} |
| NetworkChaos E1 | {ctl['networkchaos_integrador']} |
| Data Service inyección de fallos | {ctl['data_service_fault']} |

**Limitaciones:** solo GCP. AWS RDS/VPC está bloqueado por SCP. No hay evidencia operativa de Cloud SQL, Cloud Service Mesh ni alerta gestionada de anomalías. Consultar un backend no demuestra por sí solo que todos sus datos estén correlacionados. Un panel vacío no equivale a cero errores. VPC Flow Logs se basa en muestreo y puede tener retraso de ingesta.

Los archivos JSON de este directorio conservan los resultados específicos; el contenido resumido evita publicar secretos y direcciones IP de la VPC.
'''
(c/'RESUMEN.md').write_text(s)
PY

git add README.md observability/grafana-security-signals.json docs/OBSERVABILIDAD-RED-SEGURIDAD.md scripts/fase4_observabilidad_gcp.sh "$OUT" "$OBS"
git diff --cached --check
if ! git diff --cached --quiet; then git commit -m 'feat: verify GCP telemetry network flow logs and security evidence'; fi
git push origin main
printf '\n=== FASE4_GCP_EVIDENCIAS_PUBLICADAS ===\n'
printf 'CARPETA_SEGURIDAD=%s\nCARPETA_OTEL=%s\n' "$OUT" "$OBS"
printf 'FLOW_LOGS=%s SCC=%s JAEGER=%s\n' "$FLOW_STATUS" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["query_status"])' "$OUT/security-findings.json")" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("tracing",{}).get("status","unknown"))' "$OBS/telemetry.json")"
git log -1 --oneline
