terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.68.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }

  backend "s3" {
    bucket         = "kartheek12345678"  # Specify the S3 bucket for storing the state file
    key            = "kartheek"
    region         = "ap-south-1"
    dynamodb_table = "terraform_lock_table"  # Use DynamoDB for state locking
  }
}

provider "aws" {
  region = "ap-south-1"
}

locals {
  env = "assignment-a"
}

# VPC
resource "aws_vpc" "one" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${local.env}-vpc"
  }
}

# Subnet
resource "aws_subnet" "two" {
  vpc_id     = aws_vpc.one.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "${local.env}-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "three" {
  vpc_id = aws_vpc.one.id

  tags = {
    Name = "${local.env}-internetGW"
  }
}

# Route Table
resource "aws_route_table" "four" {
  vpc_id = aws_vpc.one.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.three.id
  }

  tags = {
    Name = "${local.env}-route-table"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "five" {
  subnet_id      = aws_subnet.two.id
  route_table_id = aws_route_table.four.id
}

# TLS Private Key
resource "tls_private_key" "five" {
  algorithm = "RSA"
}

# Local File to Store Private Key
resource "local_file" "private_key_pem" {
  content  = tls_private_key.five.private_key_pem
  filename = "${local.env}-assignment.pem"
}

# Import the Public Key as AWS Key Pair
resource "aws_key_pair" "assignment_key" {
  key_name   = "${local.env}-key"
  public_key = tls_private_key.five.public_key_openssh
}

resource "aws_instance" "six" {
  subnet_id          = aws_subnet.two.id
  ami                = "ami-078264b8ba71bc45e"
  instance_type      = "t2.micro"
  key_name           = aws_key_pair.assignment_key.key_name
  associate_public_ip_address = true
  
  

  user_data = <<-EOF
    #!/bin/bash
    yum install httpd git -y
    systemctl start httpd
    systemctl enable httpd
    cd /var/www/html
    git clone https://github.com/karishma1521success/swiggy-clone.git
    mv swiggy-clone/* .
    EOF

  tags = {
    Name = "${local.env}-server"
  }
}


# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "eight" {
  name           = "terraform_lock_table"
  billing_mode   = "PAY_PER_REQUEST" # Use on-demand billing mode
  hash_key       = "LockID"          # Define the primary key

  attribute {
    name = "LockID"
    type = "S"  # 'S' indicates a string attribute, used as the hash key
  }

}
