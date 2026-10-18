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

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
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

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }
}
