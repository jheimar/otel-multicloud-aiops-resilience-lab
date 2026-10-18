resource "aws_security_group" "rds_sg" {
  name        = "otel-aws-rds-sg"
  description = "Permitir trafico PostgreSQL hacia RDS desde GKE y servicios autorizados"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL port from authorized GKE subnet and VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "otel-aws-rds-sg"
  }
}
