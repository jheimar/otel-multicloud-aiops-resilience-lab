#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/share/google-cloud-sdk/bin:$PATH"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
PROJECT="project-138a5e79-5342-4c60-94f"
NS="otel-lab"
BASE="us-central1-docker.pkg.dev/$PROJECT/otel-chaos-gameday"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/7] Validación preventiva: Kubernetes, secreto y Docker"
command -v gke-gcloud-auth-plugin >/dev/null
command -v docker >/dev/null
kubectl -n "$NS" get secret otel-lab-secret >/dev/null
kubectl -n "$NS" get deployment service-a service-b otel-collector >/dev/null
docker info >/dev/null
python3 -m unittest discover -s aiops -p 'test_*.py' -v
python3 -m py_compile services/data-service/main.py services/service-a/main.py

echo "[2/7] Construcción de las dos imágenes actualizadas"
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
docker build --platform linux/amd64 -t "$BASE/data-service:0.3.0" services/data-service
docker build --platform linux/amd64 -t "$BASE/service-a:integrador-0.3.0" services/service-a
echo "[3/7] Publicación de las imágenes"
docker push "$BASE/data-service:0.3.0"
docker push "$BASE/service-a:integrador-0.3.0"

echo "[4/7] Data Service: usar secret de PostgreSQL sandbox existente (NO Cloud SQL)"
kubectl apply -f kubernetes/data-service.yaml
kubectl -n "$NS" rollout status deployment/data-service --timeout=180s

echo "[5/7] Service A: extender flujo, preservar Deployment y variables existentes"
kubectl -n "$NS" set image deployment/service-a "service-a=$BASE/service-a:integrador-0.3.0"
kubectl -n "$NS" set env deployment/service-a DATA_SERVICE_URL="http://data-service.$NS.svc.cluster.local:8002"
kubectl -n "$NS" rollout status deployment/service-a --timeout=180s

echo "[6/7] Prueba de consulta SQL real sin imprimir secretos"
kubectl -n "$NS" exec deployment/data-service -- python -c 'import urllib.request; import json; x=json.load(urllib.request.urlopen("http://localhost:8002/data/gcp",timeout=10)); assert x["probe"]==1; print("DB_BACKEND_SANDBOX_OK", x["backend"], "TRACE", x["trace_id"])'

echo "[7/7] Inventario final"
kubectl -n "$NS" get deploy service-a service-b data-service
kubectl -n "$NS" get svc data-service
echo "ENTREGA_TECNICA_2_OK (NO valida Cloud SQL, RDS, AIOps autónomo ni el Game Day)"
