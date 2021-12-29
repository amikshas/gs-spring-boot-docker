provider "aws" {
  region                  = "us-east-2"
  access_key              = var.access_key
  secret_key              = var.secret_key  
}

resource "tls_private_key" "private-key" {
  algorithm   = "RSA"
  rsa_bits    = 2048
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key-kube"
  public_key = tls_private_key.private-key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true
 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "student-sg-sba" {
  name = "Hello-World-SG-SBA"
  description = "Student security group"

  tags = {
    Name = "Hello-World-SG-SBA"
    Environment = terraform.workspace
  }
}

resource "aws_security_group_rule" "create-sgr-ssh" {
  security_group_id = aws_security_group.student-sg-sba.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-inbound" {
  security_group_id = aws_security_group.student-sg-sba.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-outbound" {
  security_group_id = aws_security_group.student-sg-sba.id
  cidr_blocks         = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "egress"
}

resource "aws_instance" "kubecluster" {
  count         = 3 
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.2xlarge"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = ["Hello-World-SG-SBA"]
  tags = {
    Name = "Node${count.index}"
  }
}

resource "null_resource" "control-node" {
    depends_on = [aws_instance.kubecluster]
    count = length(aws_instance.kubecluster.*.public_dns)     

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.private-key.private_key_pem
      host        = aws_instance.kubecluster.*.public_dns[count.index]
    }
    provisioner "local-exec" {
      command = "echo '${tls_private_key.private-key.private_key_pem}' > ~/.ssh/studentsba.pem && chmod 600 ~/.ssh/studentsba.pem"
    }
    provisioner "remote-exec" {
      inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https",
      "sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo echo \"deb http://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo apt-get install -y kubelet=1.15.4-00 kubeadm=1.15.4-00 kubectl=1.15.4-00"
     ]
    }
    
}  
