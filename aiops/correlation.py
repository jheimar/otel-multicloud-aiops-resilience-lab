"""Detector estadístico para una ventana de tráfico; no se presenta como servicio cloud gestionado."""
from dataclasses import dataclass
from statistics import mean, pstdev
from typing import Iterable

@dataclass(frozen=True)
class Window:
    timestamp: str
    total: int
    errors: int
    p99_ms: float
    trace_id: str | None = None

    @property
    def error_rate(self) -> float:
        return self.errors / self.total if self.total else 0.0

def correlate(baseline: Iterable[Window], current: Window, p99_slo_ms: float = 200.0) -> dict:
    historical = [x.error_rate for x in baseline if x.total > 0]
    if len(historical) < 5:
        raise ValueError("baseline requires at least 5 non-empty windows")
    mu = mean(historical)
    sigma = pstdev(historical)
    threshold = mu + 2 * sigma
    error_anomaly = current.error_rate > threshold
    latency_breach = current.p99_ms > p99_slo_ms
    return {
        "timestamp": current.timestamp,
        "error_rate": current.error_rate,
        "baseline_mean": mu,
        "baseline_stddev": sigma,
        "error_threshold": threshold,
        "p99_ms": current.p99_ms,
        "p99_slo_ms": p99_slo_ms,
        "correlated_alert": bool(error_anomaly and latency_breach),
        "latency_only_alert": bool(latency_breach),
        "trace_id": current.trace_id,
        "reason": "error_rate>mean+2sigma AND p99>SLO" if error_anomaly and latency_breach else None,
    }
