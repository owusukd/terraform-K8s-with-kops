### Provision an EC2 instance for KOps
### Make sure you already have an existing user key-pair on aws 

## Terraform block
terraform {
  required_version = "~> 1.5.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

## Provider block
provider "aws" {
  profile = "default"     // AWS credential on local desktop terminal $HOME/.aws/credentials
  region = var.aws_region
}

## Input variables
variable "aws_region" {
  description = "AWS Region"
  type = string
  default = "us-east-1"
}

variable "instance_type" {
  description = "EC2 Instance type"
  type = string
  default = "t3.small"
}

variable "ami_id" {
  description = "CentOS 7 (x86_64) - HVM AMI ID"
  type = string
  default = "ami-002070d43b0a4f171"
}

## Creating Security Group
# ssh Trafic from my desktop to the instance
resource "aws_security_group" "kops-sg-ssh" {
  name = "kops-sg-ssh-${terraform.workspace}"
  description = "SSH Connection"
  # rules
  ingress {
    description = "Allow port 22"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/32"]       // run the following to get your Public IP and replace 0.0.0.0 with it:
                                       // dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com
  }
  egress {
    description = "Allow all ip and port outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Creating Instance
resource "aws_instance" "kops-server" {
  ami = var.ami_id
  instance_type = var.instance_type
  key_name = "kops-key"               // the name of the existing key-pair on aws
  vpc_security_group_ids = [aws_security_group.kops-sg-ssh.id]
  tags = {
    "Name" = "kops-server"
  }

  # Connection Block for Provisioners to connect to EC2 Instance
  connection {
    type = "ssh"
    host = self.public_ip
    user = "centos"
    password = ""
    private_key = file("~/Desktop/DevOps_Training/Projects/kops-key.pem") // path to aws key pair attached to the instance
  }

  # Copy kops-user-data file to $HOME
  provisioner "file" {
    source = "./kops-user-data"
    destination = "/home/centos/kops-user-data"
    on_failure = continue
  }
}

## Output variable
output "kops_ec2_instance_publicip" {
  description = "Kops-server EC2 Instance Public IP"
  value = aws_instance.kops-server.public_ip
}

