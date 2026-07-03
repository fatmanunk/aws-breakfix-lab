# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "app" {
  count                  = 2
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    echo "<h1>breakfix instance ${count.index + 1} - $(hostname)</h1>" > /usr/share/nginx/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = { Name = "breakfix-app-${count.index + 1}" }
}
