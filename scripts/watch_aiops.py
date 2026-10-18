"""Evaluates telemetry windows DURING an experiment; saves observed evidence.
A local one-off experimental correlator, not a continuously deployed AIOps service.
"""
import argparse
import datetime as dt
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'aiops'))
from correlation import Window, correlate

p = argparse.ArgumentParser()
p.add_argument('--baseline', required=True)
p.add_argument('--out', required=True)
p.add_argument('--start-utc', required=True)
p.add_argument('--scenario', required=True)
p.add_argument('--slo-ms', type=float, default=200)
a = p.parse_args()

start = dt.datetime.fromisoformat(a.start_utc.replace('Z', '+00:00'))
with open(a.baseline, encoding='utf-8') as file:
    base_data = [json.loads(line) for line in file if line.strip().startswith('{')]
base = [Window(x['timestamp'], x['total'], x['errors'], x['p99_ms'], x.get('trace_id')) for x in base_data]
if len(base) < 5:
    raise SystemExit('Insufficient baseline windows')

outfile = pathlib.Path(a.out)
outfile.parent.mkdir(parents=True, exist_ok=True)
static_alerts = correlated_alerts = latency_alerts = 0
first_mttd = None
lines = 0
requests_total = 0
errors_total = 0
max_p99_ms = 0.0
with outfile.open('w', encoding='utf-8') as out:
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            point = json.loads(line)
        except json.JSONDecodeError:
            print('Skipped non-JSON sample:', line[:200], file=sys.stderr)
            continue
        lines += 1
        requests_total += point["total"]
        errors_total += point["errors"]
        max_p99_ms = max(max_p99_ms, point["p99_ms"])
        current = Window(point['timestamp'], point['total'], point['errors'], point['p99_ms'], point.get('trace_id'))
        result = correlate(base, current, a.slo_ms)
        # Static comparator: an OR-rule (rate > 0 OR p99 > threshold).
        is_static = current.error_rate > 0 or result['latency_only_alert']
        static_alerts += int(is_static)
        correlated_alerts += int(result['correlated_alert'])
        latency_alerts += int(result['latency_only_alert'])
        detection_type = 'correlated' if result['correlated_alert'] else ('latency_only' if result['latency_only_alert'] else None)
        if detection_type and first_mttd is None:
            detected = dt.datetime.now(dt.timezone.utc)
            first_mttd = round((detected - start).total_seconds(), 2)
        record = {**point, **result, 'detector': 'local_experimental',
                  'detection_type': detection_type,
                  'observed_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
        out.write(json.dumps(record, ensure_ascii=False) + '\n')
        out.flush()
        print(f"{a.scenario} window={lines} errors={point['errors']}/{point['total']} "
              f"p99={point['p99_ms']}ms detected={detection_type or 'no'}", flush=True)

summary = {
    'scenario': a.scenario, 'experiment_start_utc': a.start_utc,
    'windows_observed': lines,
    'requests_observed': requests_total,
    'http_5xx_observed': errors_total,
    'error_rate_observed': round(errors_total / requests_total, 4) if requests_total else None,
    'max_window_p99_ms': max_p99_ms,
    'illustrative_availability_slo': 0.99,
    'illustrative_error_budget_use_ratio': round(errors_total / (0.01 * requests_total), 2) if requests_total else None,
    'mttd_seconds': first_mttd,
    'target_mttd_seconds': 120,
    'mttd_target_met': first_mttd is not None and first_mttd < 120,
    'static_or_alert_windows': static_alerts,
    'correlated_and_alert_windows': correlated_alerts,
    'latency_only_alert_windows': latency_alerts,
    'method_limitation': 'short synthetic traffic, empirical p99 and local experimental detector; not Cloud Monitoring anomaly service; static OR comparator only',
}
summary_path = outfile.with_name(outfile.stem+'-summary.json')
summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('EVIDENCE_SUMMARY', summary_path, json.dumps(summary, ensure_ascii=False), flush=True)
