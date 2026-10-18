#!/usr/bin/env bash
# Recuperación incremental desde el paso 3. No compila imágenes, no crea recursos cloud.
set -Eeuo pipefail
export PATH="/usr/local/share/google-cloud-sdk/bin:$PATH"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
ROOT="$HOME/repositorio/otel-multicloud-aiops-resilience-lab"
NS=otel-lab
TARGET_IMAGE='us-central1-docker.pkg.dev/project-138a5e79-5342-4c60-94f/otel-chaos-gameday/service-a:integrador-0.3.0'
cd "$ROOT"
EXP_DIR="evidence/module-d/$(date -u +%Y%m%dT%H%M%SZ)"
A_DIR="evidence/module-a/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$A_DIR"
FAULT_ACTIVE=0
CHAOS_ACTIVE=0
cleanup() {
  local code=$?
  trap - EXIT
  if (( CHAOS_ACTIVE )); then
    echo '[LIMPIEZA] Retirando NetworkChaos únicamente del integrador.'
    kubectl -n "$NS" delete networkchaos integrador-service-b-latency --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
  if (( FAULT_ACTIVE )); then
    echo '[LIMPIEZA] Desactivando inyección de errores HTTP.'
    kubectl -n "$NS" set env deployment/data-service FAULT_ENABLED=false FAULT_DELAY_MS=0 >/dev/null 2>&1 || true
  fi
  if ((code)); then
    echo "DETENIDO ($code). No reconstruyas imágenes ni repitas las fases exitosas. Archivo de evidencia parcial: $A_DIR" >&2
  fi
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '\n[1/4] Recuperación de Service A sin reconstruir imágenes\n'
command -v gke-gcloud-auth-plugin >/dev/null || { echo 'Falta plugin en PATH; no se modifica nada.'; exit 1; }
case "$(kubectl config current-context)" in *otel-chaos-gameday*) ;; *) echo 'ERROR: Contexto Kubernetes incorrecto'; exit 1 ;; esac
IMAGE="$(kubectl -n "$NS" get deployment/service-a -o jsonpath='{.spec.template.spec.containers[0].image}')"
if [[ "$IMAGE" != "$TARGET_IMAGE" ]]; then
  echo "ERROR: Service A no está usando la imagen esperada: $IMAGE"; exit 1
fi
kubectl -n "$NS" get deployments service-a service-b data-service
kubectl -n "$NS" rollout status deployment/service-a --timeout=60s

# Se prueba por el Service DNS, no haciendo exec dentro del pod que está en rotación.
PROBE_PY=$(cat <<'PY'
import json, urllib.request, urllib.error
base='http://service-a.otel-lab.svc.cluster.local:8000'
for path in ('/health','/order/ord-001/observed'):
    try:
        with urllib.request.urlopen(base+path,timeout=16) as r:
            body=r.read().decode()
            if r.status != 200: raise RuntimeError('HTTP '+str(r.status))
            value=json.loads(body)
            if path.endswith('/observed'):
                assert value['data_service']['probe']==1, value
                assert len(value.get('trace_id',''))==32, value
                print('INTEGRACION_OK', 'TRACE_ID', value['trace_id'], 'DB', value['data_service']['database'])
            else:
                print('HEALTH_OK', value['service'])
    except urllib.error.HTTPError as err:
        print('ERROR_ENDPOINT',path,'HTTP',err.code,err.read(250).decode(),flush=True)
        raise
PY
)
PASO=0
for intento in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if kubectl -n "$NS" exec deployment/data-service -- python -c "$PROBE_PY" > "$A_DIR/integracion.txt" 2> "$A_DIR/error-probe.txt"; then
    PASO=1
    cat "$A_DIR/integracion.txt"
    break
  fi
  echo "Intento $intento/12: esperando HTTP real de Service A (5 s)..."
  sleep 5
done
if (( ! PASO )); then
  echo 'Service A no responde: sin activar caos y sin forzar reinicios.'
  cat "$A_DIR/integracion.txt" 2>/dev/null || true
  tail -12 "$A_DIR/error-probe.txt" 2>/dev/null || true
  kubectl -n "$NS" get pods -l app=service-a -o wide || true
  kubectl -n "$NS" get endpoints service-a -o wide || true
  kubectl -n "$NS" logs deployment/service-a --tail=65 --all-containers=true || true
  exit 2
fi
rm -f "$A_DIR/error-probe.txt"

printf '\n[2/4] Guardando integración en Git ANTES de ejecutar caos\n'
python3 -m unittest discover -s aiops -p 'test_*.py' -q
python3 -m py_compile services/service-a/main.py services/data-service/main.py
# Validar que el manifiesto no mantiene la clave DATABASE_URL incorrecta
python3 - <<'PY'
from pathlib import Path
text=Path('kubernetes/data-service.yaml').read_text()
assert 'key: database-url' in text, 'El manifiesto no incluye la clave existente database-url'
assert 'secretKeyRef' in text
print('SECRET_REFERENCE_OK (solo nombre de clave)')
PY
for f in kubernetes/data-service.yaml services/service-a/main.py services/data-service/main.py aiops/correlation.py aiops/test_correlation.py scripts/traffic_windows.py scripts/watch_aiops.py chaos/e1-integrador-latencia.yaml docs/FASE-INTEGRADA.md; do
  [[ -f "$f" ]] || { echo "Falta: $f; se conserva la evidencia parcial"; exit 3; }
done
git add kubernetes/data-service.yaml services/service-a/main.py services/data-service/main.py aiops/correlation.py aiops/test_correlation.py scripts/traffic_windows.py scripts/watch_aiops.py chaos/e1-integrador-latencia.yaml docs/FASE-INTEGRADA.md scripts/continuar_integrador_corregido.sh "$A_DIR"
git diff --cached --check
if ! git diff --cached --quiet; then git commit -m 'feat: validate GKE data integration and AIOps detection code'; fi
git push origin main
printf 'INTEGRACION_PUBLICADA\n'

printf '\n[3/4] Experimento E2: fallos HTTP controlados y detector local\n'
mkdir -p "$EXP_DIR"
kubectl -n "$NS" exec -i deployment/data-service -- python - --url http://127.0.0.1:8002/data/gcp --scenario e2_baseline --windows 6 --per-window 25 < scripts/traffic_windows.py > "$EXP_DIR/e2-baseline.jsonl"
kubectl -n "$NS" exec -i deployment/service-a -- python - --url http://service-a.otel-lab.svc.cluster.local:8000/order/ord-001 --scenario e1_baseline --windows 6 --per-window 25 < scripts/traffic_windows.py > "$EXP_DIR/e1-baseline.jsonl"
FAULT_ACTIVE=1
kubectl -n "$NS" set env deployment/data-service FAULT_ENABLED=true FAULT_RATE=0.10 FAULT_DELAY_MS=250
kubectl -n "$NS" rollout status deployment/data-service --timeout=180s
START_E2="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
kubectl -n "$NS" exec -i deployment/data-service -- python - --url http://127.0.0.1:8002/data/gcp --scenario e2_http_errors --windows 8 --per-window 25 < scripts/traffic_windows.py | python3 scripts/watch_aiops.py --baseline "$EXP_DIR/e2-baseline.jsonl" --out "$EXP_DIR/e2-alertas.jsonl" --start-utc "$START_E2" --scenario E2
kubectl -n "$NS" set env deployment/data-service FAULT_ENABLED=false FAULT_DELAY_MS=0
kubectl -n "$NS" rollout status deployment/data-service --timeout=180s
FAULT_ACTIVE=0
printf 'E2_TERMINADO_SIN_FALLOS_ACTIVOS\n'

git add "$EXP_DIR" && git diff --cached --check
if ! git diff --cached --quiet; then git commit -m 'test: capture sandbox HTTP fault and experimental AIOps evidence'; fi
git push origin main
printf 'E2_EVIDENCIA_PUBLICADA\n'

printf '\n[4/4] Experimento E1: latencia 200ms con caducidad y limpieza\n'
E1_STATUS='skipped'
if kubectl get crd networkchaos.chaos-mesh.org >/dev/null 2>&1; then
  if kubectl -n "$NS" get networkchaos integrador-service-b-latency >/dev/null 2>&1; then
    echo 'E1 omitido: ya existe experimento con este nombre; no sobrescribir.'
    E1_STATUS='skipped_existing_experiment'
  else
    kubectl apply -f chaos/e1-integrador-latencia.yaml
    CHAOS_ACTIVE=1
    START_E1="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    kubectl -n "$NS" exec -i deployment/service-a -- python - --url http://service-a.otel-lab.svc.cluster.local:8000/order/ord-001 --scenario e1_network_delay --windows 6 --per-window 25 < scripts/traffic_windows.py | python3 scripts/watch_aiops.py --baseline "$EXP_DIR/e1-baseline.jsonl" --out "$EXP_DIR/e1-alertas.jsonl" --start-utc "$START_E1" --scenario E1
    kubectl -n "$NS" delete networkchaos integrador-service-b-latency --ignore-not-found --wait=false >/dev/null
    CHAOS_ACTIVE=0
    E1_STATUS='executed'
  fi
else
  echo 'E1 omitido: CRD NetworkChaos no disponible.'
  E1_STATUS='skipped_missing_crd'
fi
python3 - "$EXP_DIR" "$E1_STATUS" <<'PY'
from pathlib import Path
import sys,json
p=Path(sys.argv[1]); e1=sys.argv[2]
notes=(f'# Evidencia incremental del laboratorio integrador\n\n- E1: {e1}.\n- E2: ejecutado y fallos desactivados.\n'
       '- Detección: correlador **local experimental**, no servicio gestionado de Cloud Monitoring.\n'
       '- E1 genera alertas de latencia; no implica necesariamente la regla AND de errores + p99.\n'
       '- Base de datos: PostgreSQL sandbox en GKE, NO Cloud SQL ni RDS AWS.\n'
       '- La visibilidad en Jaeger y las capacidades de Security/Network aún requieren comprobación.\n')
(p/'RESULTADOS.md').write_text(notes,encoding='utf-8')
for x in sorted(p.glob('*summary.json')):
    result=json.loads(x.read_text())
    print('RESULTADO',x.name,'requests',result.get('requests_observed'),'5xx',result.get('http_5xx_observed'),
          'MTTD_seconds',result.get('mttd_seconds'),'correlated_alert_windows',result.get('correlated_and_alert_windows'))
PY

git add "$EXP_DIR"
git diff --cached --check
if ! git diff --cached --quiet; then git commit -m 'test: record network chaos with MTTD and SLO evidence'; fi
git push origin main
printf '\n=== AVANCE INTEGRADOR CONFIRMADO ===\n'
git log -1 --oneline
printf 'Evidencias: %s | %s\n' "$A_DIR" "$EXP_DIR"
printf 'E1=%s E2=executed\n' "$E1_STATUS"
