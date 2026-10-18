#!/usr/bin/env bash
set -Eeuo pipefail
export PATH="/usr/local/share/google-cloud-sdk/bin:$PATH"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
ROOT="$HOME/repositorio/otel-multicloud-aiops-resilience-lab"
NS=otel-lab
BASE="us-central1-docker.pkg.dev/project-138a5e79-5342-4c60-94f/otel-chaos-gameday"
cd "$ROOT"
FAULT_ARMED=0
E1_ARMED=0
cleanup() {
  local saved=$?
  trap - EXIT
  if (( E1_ARMED )); then
    echo 'Limpieza: retirando únicamente el experimento E1 del integrador'
    kubectl -n "$NS" delete networkchaos integrador-service-b-latency --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
  if (( FAULT_ARMED )); then
    echo 'Limpieza: desactivando fallos HTTP del integrador'
    kubectl -n "$NS" set env deployment/data-service FAULT_ENABLED=false >/dev/null 2>&1 || true
    kubectl -n "$NS" rollout status deployment/data-service --timeout=180s >/dev/null 2>&1 || true
  fi
  if (( saved )); then echo "EJECUCIÓN DETENIDA: código $saved. No reconstruir Docker; revisar el error mostrado." >&2; fi
  exit "$saved"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '\n[1/6] Precondiciones sin repetir compilación ni push Docker\n'
command -v gke-gcloud-auth-plugin >/dev/null || { echo 'No está el plugin GKE en PATH'; exit 1; }
[[ "$(kubectl config current-context)" == *otel-chaos-gameday* ]] || { echo 'Contexto Kubernetes equivocado'; exit 1; }
[[ -f aiops/correlation.py && -f services/service-a/main.py && -f kubernetes/data-service.yaml ]] || { echo 'Faltan archivos del paquete previo'; exit 1; }
python3 -m unittest discover -s aiops -p 'test_*.py' -q
kubectl -n "$NS" rollout status deployment/data-service --timeout=30s
kubectl -n "$NS" exec deployment/data-service -- python -c 'import json,urllib.request; v=json.load(urllib.request.urlopen("http://127.0.0.1:8002/data/gcp", timeout=12)); assert v["probe"]==1; print("DATA_SERVICE_DB_OK", v["backend"], "TRACE_ID", v["trace_id"])'

printf '\n[2/6] Corregir en Git la referencia real del Secret (sin leer su valor)\n'
REF="$(kubectl -n "$NS" get deployment/service-a -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); env=d["spec"]["template"]["spec"]["containers"][0].get("env",[]); hits=[x["valueFrom"]["secretKeyRef"] for x in env if x.get("name")=="DATABASE_URL" and "secretKeyRef" in x.get("valueFrom",{})]; assert len(hits)==1; print(hits[0]["name"]+"|"+hits[0]["key"])')"
SECRET="${REF%%|*}"; KEY="${REF#*|}"
SECRET_NAME="$SECRET" SECRET_KEY="$KEY" python3 - <<'PY'
import os,pathlib,re
p=pathlib.Path('kubernetes/data-service.yaml')
s=p.read_text()
pattern=r'(secretKeyRef:\s*\{name:\s*)[^,}]+(,\s*key:\s*)[^}]+(\})'
new,count=re.subn(pattern,lambda m:m[1]+os.environ['SECRET_NAME']+m[2]+os.environ['SECRET_KEY']+m[3],s)
if count!=1: raise SystemExit('Referencia de Secret en manifiesto no identificada de forma unívoca')
p.write_text(new)
print('Manifiesto corregido. Clave (nombre, no secreto):',os.environ['SECRET_KEY'])
PY

printf '\n[3/6] Integración real Service A → B y Data Service → PostgreSQL\n'
CURRENT="$(kubectl -n "$NS" get deployment/service-a -o jsonpath='{.spec.template.spec.containers[0].image}')"
TARGET="$BASE/service-a:integrador-0.3.0"
if [[ "$CURRENT" != "$TARGET" ]]; then
  kubectl -n "$NS" set image deployment/service-a "service-a=$TARGET"
fi
kubectl -n "$NS" set env deployment/service-a DATA_SERVICE_URL="http://data-service.$NS.svc.cluster.local:8002"
kubectl -n "$NS" rollout status deployment/service-a --timeout=180s || { echo 'Rollout Service A falló; Kubernetes mantiene la versión anterior si está disponible'; exit 1; }
kubectl -n "$NS" exec deployment/service-a -- python -c 'import json,urllib.request; r=urllib.request.urlopen("http://127.0.0.1:8000/order/ord-001/observed",timeout=18); d=json.load(r); assert r.status==200 and d["data_service"]["probe"]==1; print("INTEGRACION_COMPLETA_OK", "TRACE_ID", d["trace_id"], "BACKEND", d["data_service"]["backend"])'

EVIDENCE="evidence/module-d/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
printf '\n[4/6] Línea base real de ambos servicios\n'
kubectl -n "$NS" exec -i deployment/data-service -- python - --url http://127.0.0.1:8002/data/gcp --scenario e2_baseline --windows 6 --per-window 25 < scripts/traffic_windows.py > "$EVIDENCE/e2-baseline.jsonl"
kubectl -n "$NS" exec -i deployment/service-a -- python - --url http://127.0.0.1:8000/order/ord-001 --scenario e1_baseline --windows 6 --per-window 25 < scripts/traffic_windows.py > "$EVIDENCE/e1-baseline.jsonl"
E2_STATUS=pending
E1_STATUS=pending

printf '\n[5/6] E2: 10%% HTTP 503 + 250ms, detector correlacionado en vivo\n'
FAULT_ARMED=1
kubectl -n "$NS" set env deployment/data-service FAULT_ENABLED=true FAULT_RATE=0.10 FAULT_DELAY_MS=250
kubectl -n "$NS" rollout status deployment/data-service --timeout=180s
T0="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
kubectl -n "$NS" exec -i deployment/data-service -- python - --url http://127.0.0.1:8002/data/gcp --scenario e2_http_errors --windows 8 --per-window 25 < scripts/traffic_windows.py | python3 scripts/watch_aiops.py --baseline "$EVIDENCE/e2-baseline.jsonl" --out "$EVIDENCE/e2-alertas.jsonl" --start-utc "$T0" --scenario E2
E2_STATUS=executed
kubectl -n "$NS" set env deployment/data-service FAULT_ENABLED=false
kubectl -n "$NS" rollout status deployment/data-service --timeout=180s
FAULT_ARMED=0

printf '\n[6/6] E1: 200 ms hacia Service B, alertas de latencia y recuperación\n'
if kubectl get crd networkchaos.chaos-mesh.org >/dev/null 2>&1; then
  if kubectl -n "$NS" get networkchaos integrador-service-b-latency >/dev/null 2>&1; then
    echo 'E1 omitido: existe un experimento con el mismo nombre, no se reemplaza automáticamente.'
    E1_STATUS=skipped_collision
  else
    kubectl apply -f chaos/e1-integrador-latencia.yaml
    E1_ARMED=1
    T0="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    kubectl -n "$NS" exec -i deployment/service-a -- python - --url http://127.0.0.1:8000/order/ord-001 --scenario e1_network_delay --windows 6 --per-window 25 < scripts/traffic_windows.py | python3 scripts/watch_aiops.py --baseline "$EVIDENCE/e1-baseline.jsonl" --out "$EVIDENCE/e1-alertas.jsonl" --start-utc "$T0" --scenario E1
    kubectl -n "$NS" delete networkchaos integrador-service-b-latency --ignore-not-found --wait=false >/dev/null
    E1_ARMED=0
    E1_STATUS=executed
  fi
else
  echo 'E1 omitido: CRD de NetworkChaos no disponible o sin acceso.'
  E1_STATUS=skipped_crd
fi

python3 - "$EVIDENCE" "$E1_STATUS" "$E2_STATUS" <<'PY'
import json,pathlib,sys
folder=pathlib.Path(sys.argv[1]); e1,e2=sys.argv[2:]
(folder/'RESULTADOS.md').write_text(
 '# Evidencias técnicas — laboratorio integrador\n\n'
 f'- E1 NetworkChaos: **{e1}**.\n'
 f'- E2 10% fallos HTTP: **{e2}**.\n'
 '- La latencia p99 de ventanas cortas es una estimación empírica.\n'
 '- MTTD medido por el detector local experimental, no por Cloud Monitoring.\n'
 '- PostgreSQL utilizado: sandbox GKE, **no Cloud SQL ni AWS RDS**.\n'
 '- Validar cada trace_id en Jaeger antes de afirmar visibilidad visual.\n'
 '- Las alertas `latency_only` de E1 NO equivalen a la regla correlacionada AND.\n',encoding='utf-8')
for file in sorted(folder.glob('*summary.json')):
    print('RESULTADO',file.name,json.dumps(json.loads(file.read_text()),ensure_ascii=False))
PY

echo 'Versionando código y evidencias verificadas en el ÚNICO repositorio'
git add kubernetes/data-service.yaml services/service-a/main.py services/data-service/main.py aiops/correlation.py aiops/test_correlation.py scripts/execute_integrated_phase.sh docs/FASE-INTEGRADA.md scripts/continuar_integrador.sh scripts/traffic_windows.py scripts/watch_aiops.py chaos/e1-integrador-latencia.yaml "$EVIDENCE"
git diff --cached --check
if ! git diff --cached --quiet; then
  git commit -m 'feat: integrate services and validate local AIOps with chaos evidence'
fi
git push origin main
printf '\n=== AVANCE INTEGRADOR CONFIRMADO ===\n'
git log -1 --oneline
printf 'Evidencias: %s\n' "$EVIDENCE"
printf 'E1=%s E2=%s\n' "$E1_STATUS" "$E2_STATUS"
