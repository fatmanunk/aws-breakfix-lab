# ALB SG - public ingress on 80/443
resource "aws_security_group" "alb" {
  name        = "breakfix-alb-sg"
  description = "ALB - public web ingress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "breakfix-alb-sg" }
}

# App SG - ingress ONLY from ALB SG
resource "aws_security_group" "app" {
  name        = "breakfix-app-sg"
  description = "App instances - traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "breakfix-app-sg" }
}

# DB SG - ingress ONLY from App SG (used later for DynamoDB VPC endpoint / future RDS)
resource "aws_security_group" "db" {
  name        = "breakfix-db-sg"
  description = "DB tier - traffic only from app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "DB port from app only"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "breakfix-db-sg" }
}
