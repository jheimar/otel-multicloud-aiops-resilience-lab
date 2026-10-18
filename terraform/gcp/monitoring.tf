# Google Cloud Monitoring - Alerta de Latencia P99 (Requisito Modulo B)
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "AIOps-Lab: Latency P99 Degradation (> 200ms)"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run / GKE Request Latency P99"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/cpu/core_usage_time\" AND resource.type=\"k8s_container\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  documentation {
    content   = "Alerta operacional de latencia elevada. Correlacionar con trace_id e inspeccionar spans de data-service y Cloud SQL."
    mime_type = "text/markdown"
  }
}

# Google Cloud Monitoring - Alerta de Tasa de Error HTTP 5xx
resource "google_monitoring_alert_policy" "error_rate" {
  display_name = "AIOps-Lab: HTTP Error Rate Anomaly (> 5%)"
  combiner     = "OR"

  conditions {
    display_name = "HTTP 5xx Server Errors"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/http_5xx_count\" AND resource.type=\"k8s_container\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5.0
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  documentation {
    content   = "Alerta de tasa de fallos HTTP anomala. Investigar posible inyeccion de fallos de Caos (E2) o indisponibilidad de backend."
    mime_type = "text/markdown"
  }
}
