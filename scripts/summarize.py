#!/usr/bin/env python3
import csv,json,statistics,sys,pathlib
p=pathlib.Path(sys.argv[1]);summary={}
for stage in ('baseline','chaos','recovery'):
    fn=p/f'{stage}.csv';rows=[]
    for line in fn.read_text(errors='replace').splitlines():
        try:
            status,lat=line.strip().split(',')[:2];rows.append((int(status),float(lat)))
        except (ValueError,IndexError): pass
    if not rows:
        summary[stage]={'n':0,'warning':'No parseable samples'};continue
    latency=sorted(x[1] for x in rows)
    pct=lambda q:latency[min(len(latency)-1,max(0,round((len(latency)-1)*q)))]
    summary[stage]={'n':len(rows),'availability_pct':round(100*sum(200<=s<500 for s,_ in rows)/len(rows),2),'http_5xx_pct':round(100*sum(s>=500 for s,_ in rows)/len(rows),2),'avg_ms':round(statistics.mean(latency)*1000,2),'p95_ms':round(pct(.95)*1000,2),'p99_ms':round(pct(.99)*1000,2)}
(p/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
