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


##  1.Data Source: aws_ami
**most_recent = true** -> This retrive latest ami in AWS.

**owners = ["amazon"]** -> AMIs owned by Amazon.

    data "aws_ami" "PS-ami-block" {
      most_recent = true
      owners = ["amazon"]
      filter {
        name = "name"
        values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
      }
      filter {
        name = "root-device-type"
        values = ["ebs"]
      }
      filter {
        name = "virtualization-type"
        values = ["hvm"]
     }
    }

 ## 2.  Resource: aws_vpc
 **cidr_block:** Defines the IP range for the VPC.

    resource "aws_vpc" "PS-vpc-block" {
      cidr_block = "10.0.0.0/16"
      tags = {
        Name = "TF-Pratik-vpc"
      }
    }

 ## 3. Resource: aws_subnet
**count:** --> The count meta-argument allows the creation of multiple resources based on a list or number. Here, it creates a subnet for each
CIDR range in var.SubnetRange.

**vpc_id:** Links the subnet to the previously created VPC.

**cidr_block:** The CIDR block for the subnet, dynamically assigned from the SubnetRange variable.The IP address range for each subnet
is dynamically set by the element function

**availability_zone:** Defines the availability zone for the subnet, chosen from the AZRange variable. This assigns the subnet to a specific 
Availability Zone (AZ) using the element function again.

**map_public_ip_on_launch:** Ensures that instances launched in this subnet will automatically receive a public IP.

    resource "aws_subnet" "PS-Subnet-block" {
    
      count = length(var.SubnetRange)
      vpc_id = aws_vpc.PS-vpc-block.id
      cidr_block = element(var.SubnetRange, count.index)
      availability_zone = element(var.AZRange, count.index)
      map_public_ip_on_launch = true
      tags = {
        Name = "TF-Pratik-Subnet"
      }
      depends_on = [
        aws_vpc.PS-vpc-block
      ]
    }

## 4. Variable Definitions: SubnetRange and AZRange
variable block:  This make flexibility to add subet's cidr_block & AZs.

    variable "SubnetRange" {
      type = list(string)
      default = ["10.0.1.0/24", "10.0.2.0/24"]
    }
    variable "AZRange" {
      type    = list(any)
      default = ["ap-south-1a", "ap-south-1b"]
    }

## 5. Resource: aws_internet_gateway
**aws_internet_gateway:** Defines an internet gateway to allow communication between instances in the VPC and the outside world (internet).

**vpc_id:** Associate the internet gateway with the created VPC.

    resource "aws_internet_gateway" "PS-Gateway-block" {
      vpc_id = aws_vpc.PS-vpc-block.id
      tags = {
        Name = "TF-Pratik-gateway"
      }
    }
     
## 6. Resource: aws_route_table
**aws_route_table:** Defines a route table for the VPC.

**route:** A route that forwards traffic destined for all IP addresses (0.0.0.0/0) to the internet gateway.

    resource "aws_route_table" "PS-route-block" {
      vpc_id = aws_vpc.PS-vpc-block.id
      route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.PS-Gateway-block.id
      }
      tags = {
        Name = "TF-Pratik-route-table-For-VPC"
      }
    }
 
## 7. Resource: aws_route_table_association
**aws_route_table_association:** Associates the route table with the subnets.

**count:** Again used to create associations for each subnet.

**subnet_id:** Links each subnet to the route table.

**route_table_id:** Associates the route table.

    resource "aws_route_table_association" "PS-T_asso-block" {
    
      count = length(var.SubnetRange)
      subnet_id = element(aws_subnet.PS-Subnet-block.*.id, count.index)
      route_table_id = aws_route_table.PS-route-block.id
    }

## 8.  Security Group Resource: aws_security_group
**aws_security_group:** Creates a security group within the VPC.

**ingress and egress:** Define the inbound and outbound rules for traffic.

**dynamic block** Here used for dyanmic allow port no with variable var.Allow-traffic, 

    resource "aws_security_group" "PS-SG-block" {
      vpc_id = aws_vpc.PS-vpc-block.id
  
      dynamic "ingress" {
        for_each = var.Allow-traffic
        iterator = port
        content {
          description = "allow inbound rule"
          from_port = port.value
          to_port = port.value
          protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
      egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
      depends_on = [
        aws_vpc.PS-vpc-block,
        aws_subnet.PS-Subnet-block,
        aws_route_table_association.PS-T_asso-block
      ]
    }
   
## 9. EC2 Instances: aws_instance
**count = 3:** Launches 3 instances (one for each count index).

**subnet_id:** Assigns each EC2 instance to a subnet using a round-robin assignment via the modulo operator (count.index % 2).

**count.index % 2**: This is for Round Robin algorithms its go to subnet1 then subnet2 then subnet1 like this stucture.

**associate_public_ip_address = true** --> This argument used in EC2 instance launched in a VPC subnet should automatically be assigned a 
public IP address upon creation.

    resource "aws_instance" "PS-EC2-Backend-block" {
      ami = data.aws_ami.PS-ami-block.id
      key_name = "psTerraform-key"
      instance_type = "t2.micro"
      vpc_security_group_ids = [aws_security_group.PS-SG-block.id]
      subnet_id = element(aws_subnet.PS-Subnet-block.*.id , count.index % 2)
      associate_public_ip_address = true
      count = 3
      tags = {
        Name = "Pratik-TF-${var.InstanceName[count.index]}"
      }
      depends_on = [
        aws_vpc.PS-vpc-block,
        aws_subnet.PS-Subnet-block,
        aws_security_group.PS-SG-block
      ]
    }

## 10. null_resource: PS-NULL-Backend-ssh-block
Here, the **count** is set to the number of backend EC2 instances, aws_instance.PS-EC2-Backend-block.
So, if 3 backend instances are created, count will be 3, and Terraform will run this null_resource block 3 times.

**host = aws_instance.PS-EC2-Backend-block[count.index].public_ip:** The public IP address of the backend EC2 instance. 
count.index ensures that the null_resource connects to the correct instance.

**sudo useradd pratik:** Creates a new user named pratik on the EC2 instance with sudo (superuser) privileges.

**echo 'pratik:1234' | sudo chpasswd:** Sets the password for the newly created user pratik to 1234. The chpasswd command is used to change the password.

**echo 'pratik ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers:** This grants pratik user root privileges without requiring a password by 
modifying the /etc/sudoers file. This is useful for automation because it allows the pratik user to run commands as root without needing to enter a password.

**sudo sed -i '/^PasswordAuthentication no/d' /etc/ssh/sshd_config:** This command modifies the SSH server configuration (/etc/ssh/sshd_config)
by removing any line that disables password authentication. 
This is important because it ensures the system will accept password authentication for SSH, which could otherwise be disabled by default.

**sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config:** This command allows root login via SSH by changing the
PermitRootLogin setting to yes.

**sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config:**
This enables password authentication for SSH, ensuring that users can log in using a password (in this case, the password for pratik)

**sudo systemctl restart sshd:** This restarts the SSH service to apply the changes made to the SSH configuration.

    resource "null_resource" "PS-NULL-Backend-ssh-block" {
      # length for BackEnd resource
      count = length(aws_instance.PS-EC2-Backend-block)

      connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        # Here use count.index because i creates 3 EC2 for BackEnd
        host = aws_instance.PS-EC2-Backend-block[count.index].public_ip
      }
      provisioner "remote-exec" {
        inline = [
          # Create the pratik user
          "sudo useradd pratik",

          # Set the password for the user
          "echo 'pratik:1234' | sudo chpasswd",

          # Grant root privileges without a password for pratik
          "echo 'pratik ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers",

          # Remove the line "PasswordAuthentication no" if it exists
          "sudo sed -i '/^PasswordAuthentication no/d' /etc/ssh/sshd_config",

           # Modify SSH config to allow root login and password authentication
           "sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config",
           "sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config",

           # Restart SSH service to apply changes
           "sudo systemctl restart sshd"
         ]
      }
    } 

## 11. Resource:aws_instance for PS-EC2-FrontEnd-Block
**subnet_id:** Specifies the subnet in which to launch the EC2 instance.

**aws_subnet.PS-Subnet-block.*.id** is a list of subnet IDs, retrieved dynamically from aws_subnet.PS-Subnet-block.

**element(... , 0):** This function selects the first subnet ID (EX, 0 index) from the list of available subnets.
In a multi-subnet setup, this ensures the instance is placed in the first available subnet in the list.

**associate_public_ip_address:** By setting this to true, it ensures that the EC2 instance is assigned a public IP address upon creation.

    resource "aws_instance" "PS-EC2-FrontEnd-Block" {
      ami = data.aws_ami.PS-ami-block.id
      instance_type = "t2.micro"
      key_name = "psTerraform-key"
      vpc_security_group_ids = [aws_security_group.PS-SG-block.id]
      # element because multi subnet & '0' means launch in 1st available zone
      subnet_id = element(aws_subnet.PS-Subnet-block.*.id , 0)
      associate_public_ip_address = true 
  
      tags = {
        Name = "Pratik-TF-FrontEnd-LoadBalancer"
      }
      depends_on = [
        aws_subnet.PS-Subnet-block ,
        aws_vpc.PS-vpc-block ,
        aws_security_group.PS-SG-block
      ]
    }

## 12. Resource: null_resource for PS-Null-Frontend-ssh-Block
The null_resource block provided is used to configure SSH access on the Frontend EC2 instance after it has been created. 
This block ensures that the necessary SSH configurations are applied to the instance.

    
    resource "null_resource" "PS-Null-Frontend-ssh-Block" {
      connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host = aws_instance.PS-EC2-FrontEnd-Block.public_ip
      }
      provisioner "remote-exec" {
        inline = [
          "sudo useradd pratik" ,
          "echo 'pratik:1234' | sudo chpasswd" ,
          "echo 'pratik ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers" ,
          "sudo sed -i '/^PasswordAuthentication no/d' /etc/ssh/sshd_config",
          "sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config",
          "sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" ,
          "sudo systemctl restart sshd" 
        ]
      }
    }

## 13. Resource: aws_instance for PS-EC2-Ansible-Master-Block
This EC2 instance can be used as the Ansible Master Node.

    resource "aws_instance" "PS-EC2-Ansible-Master-Block" {
      ami = data.aws_ami.PS-ami-block.id
      instance_type = "t2.micro"
      key_name = "psTerraform-key"
      vpc_security_group_ids = [aws_security_group.PS-SG-block.id]
  
      subnet_id = element(aws_subnet.PS-Subnet-block.*.id , 0)
      associate_public_ip_address = true

      tags = {
       Name = "Pratik-TF-Ansible-Master"
      }
    }

## 14. 
