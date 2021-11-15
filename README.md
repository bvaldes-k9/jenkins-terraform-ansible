# Jenkins Setup with Terraform and Ansible

This project deploys a Jenkins server on AWS, configure's the server with all required dependencies and outputs using Terraform and Ansible.
!Notice you'll likely need to change the instance type depending your jenkins pipelines, projects, etc.
## Requirements

- AWS IAM User with Administrator Access permission and promgrammatic access.
- AWS Key-pair
- AWS CLI
- Terraform
- Ansible
        -Python3
        -python3-pip
- I'll be using VS code you can use your personal prefence of code editor or IDE.
- I'll be setting up this project in an Ubuntu OS so please be wary of changes the commands to your packet manager if using different OS.
- I'll also be implementing the vs code in my OS to edit my code.

# Installation

## Terraform
https://learn.hashicorp.com/tutorials/terraform/install-cli
• Ensure that your system is up to date, and you have the gnupg, software-properties-common, and curl packages installed. You will use these packages to verify HashiCorp's GPG signature, and install HashiCorp's Debian package repository.

`
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
`

• Add the HashiCorp GPG key.
`
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
`

• Add the official HashiCorp Linux repository.
`
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
`

• Update to add the repository, and install the Terraform CLI.
`
sudo apt-get update && sudo apt-get install terraform
`

## AWS
• Prerequisetes
`sudo apt install unzip`

AWS setup
• Then download AWS
`
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"`
`unzip awscliv2.zip`
`sudo ./aws/install`

• Remember to remove the zip afterwards with 
`rm -r zip-file-name`

• Remember to update if doesn’t let you download package/install
`sudo apt-get update`

## Ansible
• To install Ansible controller on your local Linux properly we'll require a few prerequisites
- Python3
- Python-pip

### Python3
• Depending on your distro of Linux your likely to have Python already installed.
• Check version with the following cmd:
- `python3 --version`

• If you don't have it install you can install Python3 with the following:
- Update your local Repositories.
    - `sudo apt update`
- Then upgrade packages installed on your local machine.
    - `sudo apt -y upgrade` 
- Its possible that you may see a python version now so try this one more time.
    - `python3 --version`
- If still no success we can now apply the python3 install cmd.
    - `sudo apt install python3` 

### Python3-pip
• Once Python3 is installed you can install pip with the following
- `sudo apt-get -y install python3-pip`

### Ansible-Install
• Now that we have our dependencies we can install ansible
- `sudo apt install ansible`

# Procedure

## AWS Configurations

• After creating your user that has programmatic access to with permissions to services you will be deploying on AWS, you grab the public and private keys that you got after creating the user and insert the name of the user you created in the following. 
- `aws configure --profile devops_03`
• You'll then be asked for your public key, private key, and region(example region is us-west-1).

•SSH key setup
### SSH key-pair

The SSH key-pair will be used by Terraform to connect to AWS EC2 instance with this credential and issue provisioner commands for Ansible too.

```
$ ssh-keygen -t rsa -b 2048 -f ~/.ssh/MyKeyPair.pem -q -P ''
$ chmod 600 ~/.ssh/MyKeyPair.pem
$ ssh-keygen -y -f ~/.ssh/MyKeyPair.pem > ~/.ssh/MyKeyPair.pub
```
• First line

- `-t` type of key to be generated invoked without any arguments, ssh-keygen will generate an RSA key, 
- `-b` is bits, 
- `-f` output_keyfile, 
- `-q` Silence ssh-keygen, 
- `-p` Passphrase, 
- `''` string text used by `-p` to insert passphrase, can also leave blank.
- You can learn more about ssh-keygen flags [here](https://man.openbsd.org/ssh-keygen.1)

•Second line
- `$ chmod 600` makes keys read-writable by you

•Third line
- `-y` allows the following options be accepted
- `-f` input/output_keyfile

•Remember the location of your new public(.pub) and private key(.pem) as we'll be refering them in our `variables.tf` soon.

## Project Directory
• Create a project directory 
- `$ mkdir jenkins-terraform-ansible`

• then create a sub folders for terraform, shell scripts, ansible files.
- `$ mkdir terraform shell-scripts install-jenkins`
- terraform for our .tf files. 
- shell-scripts to store our scripts. 
- install-jenkins is where we will have our ansible files including a dynamic host IP file.

•BEWARE
- Note for users planning to upload this project to github ensure to use the gitignore correctly to not push credentials or secrets to the public. please follow the recommendations [here](https://github.com/github/gitignore/blob/master/Terraform.gitignore)


### terraform folder
• We'll be using the resources and modules from [terraform registry for aws modules](https://registry.terraform.io/providers/hashicorp/aws/latest)

• We start with creating several files for our project applying the modules from terraform to them.
- `main.tf`
- `outputs.tf`
- `provider.tf`
- `terraform.tf`
- `variable.tf`

main
`main.tf`
```terraform
# Keypair
# Keypair of the ssh keygen made with variable route
resource "aws_key_pair" "access_key" {
  key_name   = "devops_03_kp"
  public_key = "${file(var.public_key)}"
}
```
• `key_name` I named it after the key pair from aws for easier tracking when reference to ec2.
```
# VPC
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
```
• `availability_zone` is slightly different to the variable we have for our region. You may change this to your use case of what AZ your planning to deploy in.

• The `aws_security_group` have been seperated into individual ids instead of one large id, for more specific assigning in case you were to add more instances and only want specific ports associated.

• For `Provisioner's` incase you changed your EC2 resource name ensure to update it here where you see jenkins-ci and to also update all `host =` with the updated resource name.
```
# Provisioners
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
```
• Here is where the ip of the instance is saved into a dynamic file for ansible to use to connect and configure.
```
# IP of aws instance copied to a file ip.txt in local system
resource "local_file" "ip" {
    content  = aws_instance.jenkins-ci.public_ip
    filename = "../install-jenkins/ip.txt"
}
```
• Here for the `ansible-playbook` we reference our key location as a variable ensure to include changes with your key's name and location here too. 
```
# Executes command on remote server upon "wait_30_seconds_a" completion, which will configure the remote server with jenkins
resource "null_resource" "ansible-exec" {
  depends_on = [time_sleep.wait_30_seconds_b,]

  provisioner "local-exec" {
    working_dir = "../install-jenkins"
    command = "ansible-playbook install-jenkins.yml -i ip.txt --private-key ~/.ssh/devops_03_kp.pem"
  }
}
```

Outputs
`outputs.tf`
```
# URL output Jenkins
output "url-jenkins" {
  value = "http://${aws_instance.jenkins-ci.public_ip}:8080"
}
```
• Here we reference the `EC2` resource name jenkins-ci and when terraform completes it's deployment you will have a link that will take you directly to the jenkins admin login page. Remember you can change the securitygroup for all policies to only allow connections from you or company VPN for a more secure configuration.


Provider
`provider.tf`
```
# AWS Provider Variables
provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}
```


Terraform
`terraform.tf`
```
# Terraform-version
terraform{
    required_version =">= 1.0.10"
}
```
• This is simply for troubleshooting as it helps know what version of terraform the repo was working on.


Variables
`variable.tf`
```
# Profile for aws api access
variable "profile" {
  default = "devops_03"
}
```
• The above we input the iam we made with admin access and had logged in locally with aws cli
```
# Region where services are being deployed
variable "region" {
  default = "us-east-2"
}
```
• Remember to change this based on where you'd like to deploy on.
```
# Variable naming convention suited for project needs
variable "name" {
  default = "bryan-jenkins-ci"
}
```
• The above you can change to what you'd like your services to be tagged as for easier tracking.
```
# Instance size of server and resources variable
variable "instance" {
  default = "t2.micro"
}
```
• For proof of testing I used t2.micro but feel free to change instance based on demand of your jenkins.
```
# AMI variable for aws instance
variable "ami" {
  default = "ami-0629230e074c580f2"
}
```
• This ami is for ubuntu in the region remember to change this if your working in a different region.
```
# Directory to public key location 
variable "public_key" {
  default = "~/.ssh/devops_03_kp.pub"
}

# Directory to private key location 
variable "private_key" {
  default = "~/.ssh/devops_03_kp.pem"
}
```
• The above two are your newly created keys from the ssh key-gen.
```
# Default username of remote server your trying to configure
variable "ansible_user" {
  default = "ubuntu"
}
```
• The above can be changed based on your distro, just remember if your changing the distribution you'll need to update the script and ansible-playbook too.

### shell-scripts folder
`prerequisites.sh`
```
sudo apt-get update
sudo apt-get -y install python3-pip
sudo apt-get -y install ansible
```
• This script is copied, made executable, and then executed in the remote server by provisioners in `main.tf`. This preps the server with all the needs, so ansible-playbook can be executed on the remote server and jenkins can be installed.


### install-jenkins
• Here we have our ansible playbook and config with host ip in 3 files `ansible.cfg`, `install-jenkins.yml`, and `ip.txt`.

`ansible.cfg`
```
[defaults]
inventory = ../jenkins-remote-server/install-jenkins/ip.txt
host_key_checking = False
[privilage_escalation]
become_ask_pass=false
```
• Here you have to include the project directory of where the `ip.txt` will be located, by default the terraform provisioner creates/deletes it in the install-jenkins folder.

`install-jenkins.yml`
```
- hosts: all
  become: true
  remote_user: ubuntu
  become_method: sudo
  tasks:

    - name: Install Java Requirements
      apt:
        update_cache: yes
        name: default-jdk
      become: yes

    - name: Install Jenkins
      shell: | 
        wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
        sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
        sudo apt-get update -y
        sudo apt-get install jenkins -y

    - name: Run Jenkins
      shell: /etc/init.d/jenkins start
      become: yes
```
• If you're using a different distro you'll have to update the playbook as well as the links for the specific jenkins download for your specific distro.

`ip.txt`
• This dynamic file is specifically just to gather the public-ip of the remote server so ansible can apply it in order to configure said server.



# Deploy Jenkins using Terraform and Ansible

• So our Terraform directory should be looking like the following.
- install-jenkins
    - `ansible.cfg`
    - `install-jenkins.yml`
    - `ip.txt`(will only appear post completion of terraform apply and be deleted on terraform destroy)

- shell-scripts
    - `prerequisites.sh`

- terraform
    - `main.tf`
    - `outputs.tf`
    - `provider.tf`
    - `terraform.tf`
    - `variables.tf`

• With this completed we can finally begin our deployment.

•At the terminal ensure your at directory above terraform and lets initialize our files. This will download all dependencies terraform will need to make the deployment.

- Start the initialization with:
    - `$ terraform init`

• After all dependecies download we can issue the planning command which will list out the deployment and all services that will be created. 

- Start the terraform plan with:
    - `$ terraform plan`

• Finally after reviewing the plan resolution you can deploy the services
- To deploy the terraform with:
    - `$ terraform apply`

• You will be asked to put yes or no. type out `yes`

• You can also issue the cmd `$ terraform apply -auto-approve` which will deploy the services with out the confirmation input of typing out yes.

• It will take an approx. 5 min to complete this deployment.
Upon completion you can click on the output of terraform in your terminal and paste it into your broswer which will take you to the admin page.

• To get your initial Admin Password you'll have to ssh to the remote server, here's how:
- SSH:
    - `$ ssh -i "~/key directory/private-key.pem" ubuntu@ec2-<insert-ip-here,-keep-dashes>.us-east-2.compute.amazonaws.com`
    - Ex. `$ ssh -i "~/.ssh/devops_03_kp.pem" ubuntu@ec2-3-17-176-71.us-east-2.compute.amazonaws.com`
    - You will be asked if your sure you want to connect, input `yes`

- Once connected to your server you can print out the initial-admin-password file:
    - `$ cd /`
    - `$ sudo -i`
    - `$ cat /var/lib/jenkins/secrets/initialAdminPassword`

• Now you can copy that password over to the login page on your broswer and setup your jenkins pipelines, projects, and more. 


# Cleaning Up

• Now that we’ve tested our code and we’re all done we can clean up our lab so we can be charged the minimal.

• Terraform clean up
- Terraform command:
    - `$ terraform destroy`
    - You will be asked to confirm type `yes` or `$ terraform destroy -auto-approve`

- It will take several minutes for `terraform destroy` to complete. Ensure to review the AWS console to make sure no services are left running. Such as 
    - Internet Gateway
    - VPC 
    - SG 
    - EC2 
    - Volumes


# License

MIT
