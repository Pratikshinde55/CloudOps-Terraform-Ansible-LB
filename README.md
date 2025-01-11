# End-to-End Cloud Automation with Terraform, Ansible, LB, and GitHub
Cloud Infrastructure Automation with Terraform and Ansible
![End-to-End Cloud Automation with Terraform, Ansible, LB, and GitHub](https://github.com/user-attachments/assets/d4bd950a-2afc-462b-8d32-011d4cc2d768)

## OverView-Setup: 
In this project I use Terraform as Infrastucture as code tool, By using Terraform i create Entire Infrastucrture on AWS Cloud 

## Tools/Technology use:
  This Entire project is fully automatic only set RoundRobin backend IPs is maunal(90% Automation & 10% Manual)
1. Terraform (Create Ansible Master-Slave Architecture for LB)
2. AWS Cloud(EC2, VPC, Subnet, Internate_gateway, Route_table, Security_Group)
3. Shell Scripting (Download Ansible, Clone my LB GitHub repo)
4. GitHub(Kept Ansible-playbook for LB & BackEnd)
5. Ansible(using Terraform dynamically create Inventory, set Ansible config file)
6. Load Balancer(haproxy LB is used as FrontEnd)
7. Apache webserver(Httpd webserver used as BackEnd for LB)
