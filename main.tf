terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.50"
    }
  }

  backend "s3" {
    bucket = "tf-razvan"
    key    = "terraform.state"
    region = "eu-central-1"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = "eu-central-1"
  secret_key = var.secret_key
  access_key = var.access_key
}

resource "aws_vpc" "demo-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "demo-vpc"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.demo-vpc.id
  cidr_block              = "10.0.10.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_security_group" "ssh-test" {
  tags = {
    Name = "ssh-test"
  }
  vpc_id = aws_vpc.demo-vpc.id
  ingress {
    description      = "SSH from VPC"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
  }
  ingress {
    description      = "HTTP from VPC"
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
}

resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.demo-vpc.id
  tags = {
    Name = "demo-vpc-IGW"
  }
}

resource "aws_instance" "app_server" {
  ami                         = "ami-02fe204d17e0189fb"
  instance_type               = "t2.micro"
  key_name                    = "razvan"
  security_groups             = [aws_security_group.ssh-test.id]
  subnet_id                   = aws_subnet.public-subnet.id
  associate_public_ip_address = true

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo yum update -y
  sudo yum install httpd.x86_64 -y
  sudo systemctl start httpd
  sudo systemctl enable httpd
  echo "*** Completed Installing apache2"
  EOF

  tags = {
    Name = "ExampleAppServerInstance"
  }
  volume_tags = {
    Name = "app_server"
  }
}

resource "aws_eip" "ip-test-env" {
  instance = aws_instance.app_server.id
  vpc      = true
}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.demo-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }
  tags = {
    Name = "test-env-route-table"
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.route-table-test-env.id
}