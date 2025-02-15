resource "aws_vpc" "awsvpc" {
  cidr_block           = "117.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags = {
    Name = "user17vpc"
  }
}

resource "aws_internet_gateway" "awsipg" {
  vpc_id = "${aws_vpc.awsvpc.id}"
  tags = {
    Name = "user17igw"
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id            = "${aws_vpc.awsvpc.id}"
  availability_zone = "ap-northeast-1a"
  cidr_block        = "117.0.1.0/24"
  tags = {
    Name = "user17subnet1"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id            = "${aws_vpc.awsvpc.id}"
  availability_zone = "ap-northeast-1c"
  cidr_block        = "117.0.2.0/24"
  tags = {
    Name = "user17subnet2"
  }
}

resource "aws_eip" "awseip1" {
  vpc = false
  tags = {
    Name = "user17eip1"
  }
}

resource "aws_eip" "awseip2" {
  vpc = false
  tags = {
    Name = "user17eip2"
  }
}

resource "aws_nat_gateway" "natgate_1a" {
  allocation_id = "${aws_eip.awseip1.id}"
  subnet_id     = "${aws_subnet.public_1a.id}"
  tags = {
    Name = "user17ngw"
  }
}

resource "aws_nat_gateway" "natgate_1b" {
  allocation_id = "${aws_eip.awseip2.id}"
  subnet_id     = "${aws_subnet.public_1b.id}"
  tags = {
    Name = "user17ngw"
  }
}


resource "aws_route_table" "awsrtp" {
  vpc_id = "${aws_vpc.awsvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.awsipg.id}"
  }
  tags = {
    Name = "user17route"
  }
}

resource "aws_route_table_association" "awsrtp1a" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.awsrtp.id}"
}

resource "aws_route_table_association" "awsrtp1b" {
  subnet_id      = "${aws_subnet.public_1b.id}"
  route_table_id = "${aws_route_table.awsrtp.id}"
}

resource "aws_default_security_group" "awssecurity" {
  vpc_id = "${aws_vpc.awsvpc.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "user17sg"
  }
} 

resource "aws_default_network_acl" "awsnetworkacl" {
  default_network_acl_id = "${aws_vpc.awsvpc.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  subnet_ids = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1b.id}",
  ]
}

variable "amazon_linux" {
  # Amazon Linux 2 AMI (HVM), SSD Volume Type - ami-0c3fd0f5d33134a76 (64��Ʈ x86)
  default = "ami-0c3fd0f5d33134a76"
}

resource "aws_security_group" "webserverSecurutyGroup" {
  name        = "user17webserverSecurutyGroup"
  description = "open ssh port for webserverSecurutyGroup"

  vpc_id = "${aws_vpc.awsvpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web1" {
  ami               = "${var.amazon_linux}"
  availability_zone = "ap-northeast-1a"
  instance_type     = "t2.micro"
  key_name = "user17-key"
  vpc_security_group_ids = [
    "${aws_security_group.webserverSecurutyGroup.id}",
    "${aws_default_security_group.awssecurity.id}",
  ]

  subnet_id                   = "${aws_subnet.public_1a.id}"
  associate_public_ip_address = true
  tags = {
    Name = "user17web1"
  }
}

resource "aws_instance" "web2" {
  ami               = "${var.amazon_linux}"
  availability_zone = "ap-northeast-1c"
  instance_type     = "t2.micro"
  key_name = "user17-key"	
  vpc_security_group_ids = [
    "${aws_security_group.webserverSecurutyGroup.id}",
    "${aws_default_security_group.awssecurity.id}",
  ]
				
  subnet_id                   = "${aws_subnet.public_1b.id}"
  associate_public_ip_address = true
  tags = {
    Name = "user17web2"
  }
}
	
resource "aws_alb" "frontend" {
  name            = "albuser17"
  internal        = false
  security_groups = ["${aws_security_group.webserverSecurutyGroup.id}"]
  subnets         = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1b.id}"
  ]
  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "frontendalb" {
  name     = "frontendtargetgroupuser17"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.awsvpc.id}"

  health_check {
    interval            = 30
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3				
  }
}

resource "aws_alb_target_group_attachment" "frontend1" {
  target_group_arn = "${aws_alb_target_group.frontendalb.arn}"
  target_id        = "${aws_instance.web1.id}"
  port             = 80
}

resource "aws_alb_target_group_attachment" "frontend2" {
  target_group_arn = "${aws_alb_target_group.frontendalb.arn}"
  target_id        = "${aws_instance.web2.id}"
  port             = 80
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.frontendalb.arn}"
    type             = "forward"
  }
}