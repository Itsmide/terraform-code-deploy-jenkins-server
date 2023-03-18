
provider "aws" {
    region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_security_group" "lb_sg" {
  name        = var.aws_security_group_name
  description = "Allow SSH, HTTP, HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Inbound traffic for ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Inbound traffic for HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Inbound traffic for HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Inbound traffic for jenkins"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.ec2_sg_tags-name
  }
}

resource "aws_subnet" "public_subnet1" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
      Name = "Public Subnet1"
    }
}

resource "aws_subnet" "private_subnet1" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1c"
  
    tags = {
      Name = "Private Subnet1"
    }
}

resource "aws_subnet" "public_subnet2" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
  
    tags = {
      Name = "Public Subnet2"
    }
}

resource "aws_subnet" "private_subnet2" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.3.0/24"
    availability_zone = "us-east-1d"
  
    tags = {
      Name = "Private Subnet2"
    }
}

resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.main.id
  
    tags = {
      Name = "Internet Gateway"
    }
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id
  
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.internet_gateway.id
    }
  
    route {
      ipv6_cidr_block = "::/0"
      gateway_id      = aws_internet_gateway.internet_gateway.id
    }
  
    tags = {
      Name = "Public Route Table"
    }
}

resource "aws_route_table_association" "public_1_rt_a" {
    subnet_id      = aws_subnet.public_subnet1.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_rt_a" {
    subnet_id      = aws_subnet.public_subnet2.id
    route_table_id = aws_route_table.public_rt.id
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "jenkins-key-pair" {
  key_name = var.key_pair_name
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "jenkins-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = var.Private_key_filename
}

resource "aws_instance" "Jekins-server" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.jenkins-key-pair.key_name
  security_groups    = [aws_security_group.lb_sg.id]
  subnet_id          = aws_subnet.public_subnet1.id
  user_data          = file("jenkins-server-script.sh")

  tags = {
    Name = var.Server1_name
  }
}

resource "local_file" "altschool-file" {
  filename = var.EC2_IP_Address
  content = <<-EOT
    [webserver1]
    ${aws_instance.Jekins-server.public_ip}

  EOT
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
  
variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}
  
variable "aws_security_group_name" {
  type    = string
  default = "ec2-sg"
}
  
variable "ec2_sg_tags-name" {
  type    = string
  default = "terraform-ec2-sg"
}
  
variable "key_pair_name" {
  type    = string
  default = "jenkins-server"
}
  
variable "Private_key_filename" {
  type    = string
  default = "jenkins-server.pem"
}
  
variable "Server1_name" {
  type    = string
  default = "Server-Jenks"
}

variable "EC2_IP_Address" {
  type    = string
  default = "host-inventory"
}

output "Server_Jenkins" {     
  value = "${aws_instance.Jekins-server.public_ip}"
}



