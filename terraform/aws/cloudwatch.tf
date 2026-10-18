# SNS Topic para notificaciones de alertas de observabilidad y AIOps
resource "aws_sns_topic" "alerts" {
  name = "otel-aws-aiops-alerts"

  tags = {
    Name        = "otel-aws-aiops-alerts"
    Environment = "laboratory"
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Alarm para degradacion de Latencia / CPU en RDS (Requisito Modulo B en AWS)
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "AIOps-Lab-AWS: RDS High CPU (> 80%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta operacional de degradacion en la base de datos AWS RDS PostgreSQL"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory" {
  alarm_name          = "AIOps-Lab-AWS: Low Freeable Memory (< 100MB)"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 104857600 # 100 MB
  alarm_description   = "Alerta de memoria libre baja en la instancia RDS PostgreSQL"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
}
