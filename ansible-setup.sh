#!/bin/bash

echo "Updating the system..."
sudo yum update -y

echo "Installing Amazon Linux Extras and EPEL..."
sudo amazon-linux-extras install epel -y
 
echo "Installing Ansible..."
sudo yum install ansible -y

# Ansible Setup done message show 
echo "Ansible installation complete!"

echo "Hey git is installing"
sudo yum install git -y

# Creade DIR under psadmin user
mkdir /home/psadmin/Pratik-Git-lb

cd /home/psadmin/Pratik-Git-lb

# Git clone cmd for clone my Ansible LB REPO
git clone https://github.com/Pratikshinde55/Ansible-loadBalancer-webserver-configuration.git
