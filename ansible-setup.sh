#!/bin/bash

# Update the system
echo "Updating the system..."
sudo yum update -y

# Install EPEL repository
echo "Installing Amazon Linux Extras and EPEL..."
sudo amazon-linux-extras install epel -y

# Install Ansible 
echo "Installing Ansible..."
sudo yum install ansible -y

# Ansible Setup done message show 
echo "Ansible installation complete!"

#install git
echo "Hey git is installing"
sudo yum install git -y

# Creade DIR under psadmin user
mkdir /home/psadmin/Pratik-lB-git

#Change to DIR
cd /home/psadmin/Pratik-lB-git

# Git clone cmd for clone my Ansible LB REPO
git clone https://github.com/Pratikshinde55/Ansible-loadBalancer-webserver-configuration.git



