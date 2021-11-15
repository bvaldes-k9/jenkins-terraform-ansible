# Profile for aws api access
variable "profile" {
  default = "devops_03"
}

# Region where services are being deployed
variable "region" {
  default = "us-east-2"
}

# Variable naming convention suited for project needs
variable "name" {
  default = "bryan-jenkins-ci"
}

# Instance size of server and resources variable
variable "instance" {
  default = "t2.micro"
}

# AMI variable for aws instance
variable "ami" {
  default = "ami-0629230e074c580f2"
}

# Directory to public key location 
variable "public_key" {
  default = "~/.ssh/devops_03_kp.pub"
}

# Directory to private key location 
variable "private_key" {
  default = "~/.ssh/devops_03_kp.pem"
}

# Default username of remote server your trying to configure
variable "ansible_user" {
  default = "ubuntu"
}