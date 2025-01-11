# End-to-End Cloud Automation with Terraform, Ansible, LB, and GitHub
Cloud Infrastructure Automation with Terraform and Ansible

## OverView-Setup: 
In this project I use Terraform as Infrastucture as code tool, By using Terraform i create Entire Infrastucrture on AWS Cloud 

## Tools/Technology use:
  This Entire project is fully automatic only set RoundRobin backend IPs is maunal(90% Automation & 10% Amnual)
1. Terraform (Create Ansible Master-Slave Architecture for LB)
2. AWS Cloud(EC2, VPC, Subnet, Internate_gateway, Route_table, Security_Group)
3. Shell Scripting (Download Ansible, Clone my LB GitHub repo)
4. Ansible(using Terraform dynamically create Inventory, set Ansible config file)
5. Load Balancer(haproxy LB is used as FrontEnd)
6. Apache webserver(Httpd webserver used as BackEnd for LB)
