"""Generates synthetic, explicitly labelled, non-personal laboratory HTTP traffic.
Runs INSIDE a selected Kubernetes application container via `kubectl exec -i`.
Emits one JSON object per window for streamed local correlation.
"""
import argparse
import datetime as dt
import json
import math
import secrets
import time
import urllib.error
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--url', required=True)
parser.add_argument('--windows', type=int, default=6)
parser.add_argument('--per-window', type=int, default=25)
parser.add_argument('--delay', type=float, default=0.035)
parser.add_argument('--scenario', required=True)
a = parser.parse_args()
if not (1 <= a.windows <= 50 and 1 <= a.per_window <= 1000):
    raise SystemExit('Invalid sample size')

for w in range(a.windows):
    observations = []
    errors = 0
    error_trace_id = None
    slow_trace_id = None
    slowest_ms = -1.0
    for _ in range(a.per_window):
        trace_id = secrets.token_hex(16)
        span_id = secrets.token_hex(8)
        request = urllib.request.Request(a.url, headers={'traceparent': f'00-{trace_id}-{span_id}-01'})
        start = time.monotonic()
        try:
            with urllib.request.urlopen(request, timeout=9) as response:
                status = response.status
                response.read()
        except urllib.error.HTTPError as ex:
            status = ex.code
            ex.read()
        except Exception:
            status = 599  # synthetic transport failure class
        duration_ms = (time.monotonic() - start) * 1000
        observations.append(duration_ms)
        if duration_ms > slowest_ms:
            slowest_ms = duration_ms
            slow_trace_id = trace_id
        if status >= 500:
            errors += 1
            if error_trace_id is None:
                error_trace_id = trace_id
        time.sleep(a.delay)
    observations.sort()
    p99 = observations[max(0, math.ceil(len(observations) * 0.99) - 1)]
    print(json.dumps({
        'timestamp': dt.datetime.now(dt.timezone.utc).isoformat(),
        'scenario': a.scenario, 'window': w+1, 'total': len(observations),
        'errors': errors, 'p99_ms': round(p99, 2),
        'trace_id': error_trace_id or slow_trace_id,
    }), flush=True)
