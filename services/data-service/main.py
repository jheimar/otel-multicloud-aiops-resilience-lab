"""Data Service: consultas PostgreSQL multicloud y fallos L7 controlados para sandbox."""
import json
import logging
import os
import random
import time
from contextlib import asynccontextmanager

import psycopg2
from fastapi import FastAPI, HTTPException
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.trace import Status, StatusCode

SERVICE = "data-service"
OTLP = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.otel-lab.svc.cluster.local:4317")
ENV = os.getenv("DEPLOYMENT_ENVIRONMENT", "sandbox")
FAULT_RATE = float(os.getenv("FAULT_RATE", "0"))
if not (0.0 <= FAULT_RATE <= 1.0):
    raise ValueError("FAULT_RATE must be between 0 and 1")
# Fallos únicamente para esta ruta y al habilitarse explícitamente.
FAULT_ENABLED = os.getenv("FAULT_ENABLED", "false").lower() == "true"

resource = Resource.create({"service.name": SERVICE, "service.version": "0.2.0", "deployment.environment": ENV, "cloud.provider": "gcp"})
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP, insecure=True)))
trace.set_tracer_provider(tracer_provider)
Psycopg2Instrumentor().instrument(tracer_provider=tracer_provider)
meter_provider = MeterProvider(resource=resource, metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter(endpoint=OTLP, insecure=True), export_interval_millis=5000)])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(SERVICE)
request_counter = meter.create_counter("data_requests_total", unit="1")
request_duration = meter.create_histogram("data_request_duration_seconds", unit="s")
db_duration = meter.create_histogram("data_db_duration_seconds", unit="s")

class JsonFormatter(logging.Formatter):
    def format(self, record):
        span = trace.get_current_span().get_span_context()
        return json.dumps({"time": self.formatTime(record), "level": record.levelname,
                           "service": SERVICE, "message": record.getMessage(),
                           "trace_id": f"{span.trace_id:032x}" if span.is_valid else None,
                           "span_id": f"{span.span_id:016x}" if span.is_valid else None})

logger = logging.getLogger(SERVICE)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)
logger.propagate = False

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    meter_provider.shutdown()
    tracer_provider.shutdown()

app = FastAPI(title="Data Service Multicloud", version="0.2.0", lifespan=lifespan)
FastAPIInstrumentor.instrument_app(app, tracer_provider=tracer_provider)

@app.get("/health")
def health():
    return {"status": "ok", "service": SERVICE, "environment": ENV}

@app.get("/ready")
def ready():
    # Readiness de proceso, no certifica conectividad con ambas BD.
    return {"ready": True}

@app.get("/data/{backend}")
def read_data(backend: str):
    """Consulta de prueba sin datos personales. backend = gcp | aws.

    DSN explícito en Secret Kubernetes, y nunca en la respuesta o logs.
    """
    start = time.monotonic()
    if backend not in ("gcp", "aws"):
        raise HTTPException(status_code=400, detail="backend must be gcp or aws")
    labels = {"backend": backend, "method": "GET", "route": "/data/{backend}"}
    try:
        if FAULT_ENABLED and random.random() < FAULT_RATE:
            logger.warning("Injected sandbox HTTP fault for backend=%s", backend)
            raise HTTPException(status_code=503, detail="controlled sandbox fault")

        dsn = os.getenv("GCP_DATABASE_URL" if backend == "gcp" else "AWS_DATABASE_URL")
        if not dsn:
            raise HTTPException(status_code=503, detail="backend not configured")

        with trace.get_tracer(SERVICE).start_as_current_span("data.read", attributes={
            "db.system.name": "postgresql", "db.operation.name": "SELECT", "db.namespace": backend,
            "cloud.provider": backend
        }) as span:
            db_start = time.monotonic()
            try:
                with psycopg2.connect(dsn, connect_timeout=3) as connection:
                    with connection.cursor() as cursor:
                        cursor.execute("SELECT current_database(), 1 AS probe_value")
                        row = cursor.fetchone()
            except psycopg2.Error:
                span.set_status(Status(StatusCode.ERROR, "database connection or query failed"))
                logger.error("Database query failed for backend=%s", backend)
                raise HTTPException(status_code=503, detail="database unavailable")
            finally:
                db_duration.record(time.monotonic() - db_start, {"backend": backend})
            logger.info("Database probe succeeded for backend=%s", backend)
            return {"backend": backend, "database": row[0], "probe": row[1],
                    "trace_id": f"{span.get_span_context().trace_id:032x}"}
    finally:
        # Registra muestras 2xx/5xx para detector; no conserva IDs individuales como labels.
        import sys
        code = 500 if sys.exc_info()[0] is not None else 200
        request_counter.add(1, {**labels, "status_class": f"{code // 100}xx"})
        request_duration.record(time.monotonic() - start, labels)
