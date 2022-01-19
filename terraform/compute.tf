provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  backend "s3" {
    bucket = "eks-terraform-state-statging"
    key    = "eks/terraform2.tfstate"
    region = "us-west-2"
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }
  filter {
    name = "owner-alias"
    values = [
      "amazon",
    ]
  }
}



resource "aws_instance" "jenkins2-instance" {
  ami             = "${data.aws_ami.amazon-linux-2.id}"
  instance_type   = "t2.medium"
  key_name        = "${var.keyname}"
  #vpc_id          = "${aws_vpc.development-vpc.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_allow_ssh_jenkins.id}"]
  subnet_id          = "${aws_subnet.public-subnet-1.id}"
  #name            = "${var.name}"
  user_data = "${file("install_jenkins.sh")}"

  associate_public_ip_address = true
  tags = {
    Name = "Jenkins2-Instance"
  }
}

resource "aws_security_group" "sg_allow_ssh_jenkins" {
  name        = "allow_ssh_jenkins"
  description = "Allow SSH and Jenkins inbound traffic"
  vpc_id      = "${aws_vpc.development-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

output "jenkins_ip_address" {
  value = "${aws_instance.jenkins2-instance.public_dns}"
}



module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                    = "my-cluster-demo"
  cluster_version                 = "1.21"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }


  vpc_id     = "vpc-166cda71"
  subnet_ids = ["subnet-c62e468f","subnet-7caba63a","subnet-2f017948"]

#########################
  eks_managed_node_groups = {
    green = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      subnet         = "subnet-2f017948"
      labels = {
        Environment = "test"
        GithubRepo  = "terraform-aws-eks"
        GithubOrg   = "terraform-aws-modules"
      }
    }
  }
}
