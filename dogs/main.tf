provider "aws" {
  region  = "us-east-1"
  profile = "default"
}
resource "aws_vpc" "catdog-vpc" {
  cidr_block           = "${var.ip_red}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.app_name}-vpc"
    }
}

resource "aws_internet_gateway" "aws-igw" {
  vpc_id = aws_vpc.catdog-vpc.id
  tags = {
    Name        = "${var.app_name}-igw"
  }

}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.catdog-vpc.id
  count             = length(var.private_subnets)
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.app_name}-privada-${count.index + 1}"
    }
}

resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.catdog-vpc.id
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.public_subnets)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-publica-${count.index + 1}"
    }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.catdog-vpc.id

  tags = {
    Name        = "${var.app_name}-rutas-publicas"
  }
}

resource "aws_route" "publica" {
  route_table_id         = aws_route_table.publica.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.aws-igw.id
}

resource "aws_route_table_association" "publica" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.publica.*.id, count.index)
  route_table_id = aws_route_table.publica.id
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${var.app_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = {
    Name        = "${var.app_name}-iam-role"
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_ecs_cluster" "aws-ecs-cluster" {
  name = "${var.app_name}-cluster"
  tags = {
    Name        = "${var.app_name}-ecs"
  }
}

resource "aws_alb" "application_load_balancer" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.publica.*.id
  security_groups    = [aws_security_group.load_balancer_security_group.id]

  tags = {
    Name        = "${var.app_name}-alb"
    }
}
resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.catdog-vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name        = "${var.app_name}-sg"
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.app_name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.catdog-vpc.id

  tags = {
    Name        = "${var.app_name}-lb-tg"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id
  }
}
