resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "otel-aws-rds-subnet-group"
  subnet_ids = aws_subnet.public[*].id # Se usan publicas con public_ip para acceso directo desde GKE en el laboratorio

  tags = {
    Name = "otel-aws-rds-subnet-group"
  }
}

resource "aws_db_parameter_group" "pg15" {
  name   = "otel-aws-pg15-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }
}

# AWS RDS PostgreSQL Instance (Requisito Modulo A: Base gestionada en AWS)
resource "aws_db_instance" "postgres" {
  identifier             = var.db_instance_identifier
  engine                 = "postgres"
  engine_version         = "15.13"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name   = aws_db_parameter_group.pg15.name

  publicly_accessible = true
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "otel-aws-rds-postgres"
    Environment = "laboratory"
  }
}
