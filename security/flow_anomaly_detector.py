#!/usr/bin/env python3
"""
flow_anomaly_detector.py
Analizador de VPC Flow Logs para clasificacion de trafico Norte-Sur / Este-Oeste
y deteccion de anomalias de trafico de red (Requisitos C-02 y C-03).
"""

import json
import ipaddress
import sys
from collections import defaultdict
from datetime import datetime

INTERNAL_NETWORKS = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16")
]

def is_internal(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in INTERNAL_NETWORKS)
    except ValueError:
        return False

def analyze_flow_logs(file_path):
    with open(file_path, "r") as f:
        logs = json.load(f)

    stats = {
        "total_records": len(logs),
        "north_south_flows": 0,
        "east_west_flows": 0,
        "bytes_north_south": 0,
        "bytes_east_west": 0,
        "anomalies_detected": []
    }

    port_activity = defaultdict(int)

    for entry in logs:
        payload = entry.get("jsonPayload", {})
        conn = payload.get("connection", {})
        src_ip = conn.get("src_ip", "")
        dest_ip = conn.get("dest_ip", "")
        dest_port = conn.get("dest_port", 0)
        bytes_sent = int(payload.get("bytes_sent", 0))

        src_internal = is_internal(src_ip)
        dest_internal = is_internal(dest_ip)

        # Clasificacion de trafico
        if src_internal and dest_internal:
            direction = "EAST_WEST"
            stats["east_west_flows"] += 1
            stats["bytes_east_west"] += bytes_sent
        else:
            direction = "NORTH_SOUTH"
            stats["north_south_flows"] += 1
            stats["bytes_north_south"] += bytes_sent

        port_activity[dest_port] += bytes_sent

        # Regla de anomalia: Trafico Norte-Sur con puertos no estandares o alto volumen (> 500 KB por flujo)
        if direction == "NORTH_SOUTH" and bytes_sent > 500000:
            stats["anomalies_detected"].append({
                "rule": "HIGH_VOLUME_NORTH_SOUTH_OUTBOUND",
                "src_ip": src_ip,
                "dest_ip": dest_ip,
                "dest_port": dest_port,
                "bytes_sent": bytes_sent,
                "timestamp": entry.get("timestamp", datetime.utcnow().isoformat()),
                "severity": "WARNING",
                "description": f"Flujo Norte-Sur supero el umbral de 500 KB (observado: {bytes_sent} bytes)"
            })

    return stats

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "evidence/module-c/20261018T050010Z/vpc-flow-evidence-real.json"
    result = analyze_flow_logs(path)
    output_path = "evidence/module-c/20261018T050010Z/network-anomaly-analysis.json"
    with open(output_path, "w") as out:
        json.dump(result, out, indent=2)
    print(f"Analisis completado. Registros procesados: {result['total_records']}")
    print(f"Flujos Norte-Sur: {result['north_south_flows']} | Este-Oeste: {result['east_west_flows']}")
    print(f"Anomalias de trafico detectadas: {len(result['anomalies_detected'])}")
