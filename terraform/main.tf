################################################################
# Key-pair
################################################################
# Keypair of the ssh keygen made with variable route
resource "aws_key_pair" "access_key" {
  key_name   = "devops_03_kp"
  public_key = "${file(var.public_key)}"
}

################################################################
# VPC
################################################################
# VPC for instance's routing, gateway, and association
resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.0.0.0/16" 
  enable_dns_hostnames = true          
  enable_dns_support   = true          
  instance_tenancy     = "default"
  enable_classiclink   = "false"
  tags = {
    Name = "${var.name}-vpc" 
  }
}

# Subnet
resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true 

  tags = {
    Name = "${var.name}-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "${var.name}-internet_gateway"
    }
}

# Route
resource "aws_route" "default-route" {
    route_table_id         = "${aws_route_table.rt.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = "${aws_internet_gateway.gw.id}"
    depends_on             = [
        aws_route_table.rt,
        aws_internet_gateway.gw
    ]
}

# Route association
resource "aws_route_table_association" "rt_as" {
    subnet_id = "${aws_subnet.my_subnet.id}"
    route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "${var.name}-route_table"
  }
}

################################################################
# EC2
################################################################

resource "aws_instance" "jenkins-ci" {
  ami           = "${var.ami}"
  instance_type = "${var.instance}"
  key_name      = "${aws_key_pair.access_key.key_name}"
  subnet_id     = "${aws_subnet.my_subnet.id}"
  private_ip    = "10.0.1.13"
  depends_on = [aws_internet_gateway.gw]

  # Security group signing
  vpc_security_group_ids = [
    "${aws_security_group.web.id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.egress-tls.id}",
    "${aws_security_group.ping-ICMP.id}",
	  "${aws_security_group.web_server.id}"
  ]

  # Volume sizes
  ebs_block_device {
    device_name           = "/dev/sdg"
    volume_size           = 500
    volume_type           = "io1"
    iops                  = 2000
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "jenkins-ci-ec2"
  }
}

################################################################
# Security-groups
################################################################
# Allow the server to receive requests on port 8080
resource "aws_security_group" "web" {
  name        = "${var.name}-default-web"
  description = "Security group for web that allows web traffic from internet"
  vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-web-default-vpc"
  }
}

# Allow the server to take ssh requests on port 22
resource "aws_security_group" "ssh" {
  name        = "${var.name}-default-ssh"
  description = "Security group for nat instances that allows SSH and VPN traffic from internet"
  vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ssh-default-vpc"
  }
}

# Allow the server to send on all ports
resource "aws_security_group" "egress-tls" {
  name        = "${var.name}-default-egress-tls"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id      = "${aws_vpc.my-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-egress-tls-default-vpc"
  }
}

# Allow the server to be ping
resource "aws_security_group" "ping-ICMP" {
  name        = "${var.name}-default-ping-"
  description = "Default security group that allows to ping the instance"
  vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.name}-ping-ICMP-default-vpc"
  }
}

# Allow the server to receive requests on port 8080
resource "aws_security_group" "web_server" {
  name        = "${var.name}-default-web_server"
  description = "Default security group that allows to use port 8080"
  vpc_id      = "${aws_vpc.my-vpc.id}"
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-web_server-default-vpc"
  }
}

################################################################
# Provisioners
################################################################
# Resource to test if ec2 is reachable
resource "null_resource" "ec2-ready-test" {
  provisioner "remote-exec" {
    connection {
      host = aws_instance.jenkins-ci.public_dns
      user = "ubuntu"
      private_key = "${file(var.private_key)}"
    }

    inline = ["echo 'connected!'"]
  }
}

# Delays the resource "script-exec" from executing before the server is reachable
resource "time_sleep" "wait_30_seconds_a" {
  depends_on = [null_resource.ec2-ready-test,]

  create_duration = "30s"
}

# IP of aws instance copied to a file ip.txt in local system
resource "local_file" "ip" {
    content  = aws_instance.jenkins-ci.public_ip
    filename = "../install-jenkins/ip.txt"
}

# Copies script file that issues downloads on remote server so ansible can be used on said server
resource "null_resource" "script-copy" {
  provisioner "file" {
    source = "../shell-scripts/prerequisites.sh"
    destination = "/home/ubuntu/prerequisites.sh"
   
    connection {
      timeout     = "5m"
      type        = "ssh"
      private_key = "${file(var.private_key)}"
      user        = "${var.ansible_user}"
      host        = aws_instance.jenkins-ci.public_dns
    }
  }
}

# Executes commands upon "wait_30_seconds_a" completion, which executes the script
resource "null_resource" "script-exec" {
  depends_on = [time_sleep.wait_30_seconds_a,]

  provisioner "remote-exec" {
    inline = [
      "chmod +x prerequisites.sh",
      "./prerequisites.sh"
    ]
    connection {
      timeout     = "5m"
      type        = "ssh"
      private_key = "${file(var.private_key)}"
      user        = "${var.ansible_user}"
      host        = aws_instance.jenkins-ci.public_dns
    } 
  }
}

# Delays the resource "ansible-exec" from executing before the resource "script-exec is completed"
resource "time_sleep" "wait_30_seconds_b" {
  depends_on = [null_resource.script-exec,]

  create_duration = "30s"
}

# Executes command on remote server upon "wait_30_seconds_a" completion, which will configure the remote server with jenkins
resource "null_resource" "ansible-exec" {
  depends_on = [time_sleep.wait_30_seconds_b,]

  provisioner "local-exec" {
    working_dir = "../install-jenkins"
    command = "ansible-playbook install-jenkins.yml -i ip.txt --private-key ~/.ssh/devops_03_kp.pem"
  }
}