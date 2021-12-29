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
  key_name   = "deployer-key"
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
resource "aws_security_group" "student-sg" {
  name = "Hello-World-SG"
  description = "Student security group"

  tags = {
    Name = "Hello-World-SG"
    Environment = terraform.workspace
  }
}

resource "aws_security_group_rule" "create-sgr-ssh" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-inbound" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "ingress"
}
resource "aws_security_group_rule" "create-sgr-inbound" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-outbound" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks         = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "egress"
}

resource "aws_instance" "web" {
  count         = 1 
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = ["Hello-World-SG"]
  tags = {
    Name = "Web${count.index}"
  }
}
resource "null_resource" "control-node" {
    depends_on = [aws_instance.web]
  
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.private-key.private_key_pem
      host        = aws_instance.web.*.public_dns[0]
    }
    provisioner "local-exec" {
      command = "echo '${tls_private_key.private-key.private_key_pem}' > ~/.ssh/student.pem && chmod 600 ~/.ssh/student.pem "
    }
    provisioner "remote-exec" {
      inline = [
        "sudo apt-get update -y",
        "sudo apt-get install ansible -y",
        "echo '[kubecluster]' > ~/hosts",
        "echo '52.15.217.64' >> ~/hosts",
        "echo '3.141.100.131' >> ~/hosts",
        "echo '18.220.16.75' >> ~/hosts",
        "echo '[kubemaster]' >> ~/hosts",
        "echo '52.15.217.64' >> ~/hosts",
        "echo '[kubenodes]' >> ~/hosts",
        "echo '3.141.100.131' >> ~/hosts",
        "echo '18.220.16.75' >> ~/hosts",
        "echo '${tls_private_key.private-key.private_key_pem}' > ~/.ssh/student.pem && chmod 600 ~/.ssh/student.pem",
        "sudo sed -i '71s/.*/host_key_checking = False/' /etc/ansible/ansible.cfg",
        "sudo apt-get install openjdk-11 -y",
        "sudo apt install maven -y",
        "wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -",
        "sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'",
        "sudo apt update",
        "sudo apt install jenkins -y",
        "sudo systemctl start jenkins"
      ]
    }

    
}
        
