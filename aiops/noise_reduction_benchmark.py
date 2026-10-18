#!/usr/bin/env python3
"""
noise_reduction_benchmark.py
Modulo B: Evaluacion cuantitativa de Reduccion de Ruido de Alertas.
Compara la estrategia de umbral estatico (OR) vs Deteccion Correlacionada AIOps (AND).
"""

import json
from aiops.correlation import Window, correlate

def run_benchmark():
    # 1. Definicion de la linea base historica (10 ventanas estables)
    baseline = [
        Window(f"2026-10-18T10:00:{i:02d}Z", total=100, errors=1, p99_ms=45.0)
        for i in range(10)
    ]

    # 2. Serie temporal de ventanas de produccion simuladas con jitter y degradaciones reales
    test_windows = [
        # Fase A: Trafico normal (3 ventanas) -> Ninguno deberia alertar
        Window("2026-10-18T10:10:00Z", total=100, errors=1, p99_ms=48.0, trace_id="trace-norm-01"),
        Window("2026-10-18T10:11:00Z", total=100, errors=0, p99_ms=52.0, trace_id="trace-norm-02"),
        Window("2026-10-18T10:12:00Z", total=100, errors=1, p99_ms=50.0, trace_id="trace-norm-03"),

        # Fase B: Jitter transitorio de red / Garbage Collection (5 ventanas)
        # Latencia alta (P99 > 200ms SLO) pero SIN errores -> Ruido operacional
        Window("2026-10-18T10:13:00Z", total=100, errors=0, p99_ms=230.0, trace_id="trace-jitter-01"),
        Window("2026-10-18T10:14:00Z", total=100, errors=1, p99_ms=245.0, trace_id="trace-jitter-02"),
        Window("2026-10-18T10:15:00Z", total=100, errors=0, p99_ms=260.0, trace_id="trace-jitter-03"),
        Window("2026-10-18T10:16:00Z", total=100, errors=1, p99_ms=225.0, trace_id="trace-jitter-04"),
        Window("2026-10-18T10:17:00Z", total=100, errors=0, p99_ms=210.0, trace_id="trace-jitter-05"),

        # Fase C: Errores aislados de cliente 4xx/500 puntual dentro de presupuesto (2 ventanas)
        # Error leve (2%), latencia normal (60ms) -> Ruido estatico si umbral error > 1.5%
        Window("2026-10-18T10:18:00Z", total=100, errors=2, p99_ms=65.0, trace_id="trace-err-01"),
        Window("2026-10-18T10:19:00Z", total=100, errors=2, p99_ms=70.0, trace_id="trace-err-02"),

        # Fase D: Incidente real conjunto / Degradacion severa (3 ventanas)
        # Tasa de error elevada (12-15%) Y Latencia P99 > 200ms -> ALERTA CRITICA REAL
        Window("2026-10-18T10:20:00Z", total=100, errors=14, p99_ms=340.0, trace_id="trace-incident-01"),
        Window("2026-10-18T10:21:00Z", total=100, errors=15, p99_ms=380.0, trace_id="trace-incident-02"),
        Window("2026-10-18T10:22:00Z", total=100, errors=12, p99_ms=310.0, trace_id="trace-incident-03"),

        # Fase E: Recuperacion (2 ventanas)
        Window("2026-10-18T10:23:00Z", total=100, errors=1, p99_ms=55.0, trace_id="trace-rec-01"),
        Window("2026-10-18T10:24:00Z", total=100, errors=0, p99_ms=48.0, trace_id="trace-rec-02"),
    ]

    p99_slo = 200.0
    static_error_threshold = 0.015 # 1.5%

    results = []
    static_alerts_count = 0
    aiops_alerts_count = 0

    for w in test_windows:
        res = correlate(baseline, w, p99_slo_ms=p99_slo)
        
        # Estrategia estatica tradicional (OR): dispara si latencia > SLO o error > 1.5%
        static_alert = bool(w.p99_ms > p99_slo or w.error_rate > static_error_threshold)
        # Estrategia AIOps correlacionada (AND)
        aiops_alert = res["correlated_alert"]

        if static_alert:
            static_alerts_count += 1
        if aiops_alert:
            aiops_alerts_count += 1

        results.append({
            "timestamp": w.timestamp,
            "trace_id": w.trace_id,
            "error_rate": w.error_rate,
            "p99_ms": w.p99_ms,
            "static_alert": static_alert,
            "aiops_correlated_alert": aiops_alert,
            "classification": "TRUE_INCIDENT" if (w.error_rate > 0.05 and w.p99_ms > p99_slo) else ("NOISE" if static_alert and not aiops_alert else "NORMAL")
        })

    noise_reduction_pct = ((static_alerts_count - aiops_alerts_count) / static_alerts_count) * 100.0 if static_alerts_count else 0.0

    summary = {
        "evaluation_period": "2026-10-18T10:10:00Z - 2026-10-18T10:24:00Z",
        "total_windows_evaluated": len(test_windows),
        "static_threshold_alerts": static_alerts_count,
        "aiops_correlated_alerts": aiops_alerts_count,
        "false_positives_filtered": static_alerts_count - aiops_alerts_count,
        "noise_reduction_percentage": round(noise_reduction_pct, 2),
        "windows_detail": results
    }

    return summary

if __name__ == "__main__":
    benchmark = run_benchmark()
    output_path = "evidence/module-b/noise-reduction-evidence.json"
    import os
    os.makedirs("evidence/module-b", exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(benchmark, f, indent=2)

    print("=== RESULTADOS BENCHMARK REDUCCION DE RUIDO AIOps ===")
    print(f"Total ventanas evaluadas: {benchmark['total_windows_evaluated']}")
    print(f"Alertas con regla estatica (OR): {benchmark['static_threshold_alerts']}")
    print(f"Alertas con correlacion AIOps (AND): {benchmark['aiops_correlated_alerts']}")
    print(f"Alertas de ruido filtradas: {benchmark['false_positives_filtered']}")
    print(f"Reduccion de ruido demostrada: {benchmark['noise_reduction_percentage']}%")
    print(f"Evidencia guardada en: {output_path}")
