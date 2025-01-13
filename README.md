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

My WorkSpace for this project:
![Workspace](https://github.com/user-attachments/assets/02faefa9-95bc-4d30-86c9-f0d10d253d04)

  terraform apply --auto-approve

![terraform-apply](https://github.com/user-attachments/assets/cb88e6b5-5382-4eea-850c-edbd2034372a)

## On AWS Console our Infrastructure as code create:
- All Instances are created
![Instances](https://github.com/user-attachments/assets/6e5a8552-6a0a-4b30-9ff3-6980b8246067)

- VPC creation
![VPC](https://github.com/user-attachments/assets/22f2b77f-13e8-4620-9356-292ef70043cb)

- Subnet (Multi)
![Subnet](https://github.com/user-attachments/assets/718f6f8d-56af-4604-98e6-c27ee844a54e)

- Route Tabel
![Route-table](https://github.com/user-attachments/assets/e55b682a-b002-44c7-b31c-ea711a8e1828)

- Internate Gateway
![Gateway](https://github.com/user-attachments/assets/69149357-8c54-428f-aac6-5baf45cca4ef)

## On Ansible-Master EC2 Instance on AWS:

- My local laptop ansible-setup.sh file is on ansible master node and also Public_Ip's of BackEnds & FrontEnd EC2 Instances Put on matser node.
![File-on-ansible](https://github.com/user-attachments/assets/2f2e745f-e047-413d-9cc2-13eb5381bb16)

- when switched to psadmin user we found my GitHub Repo:
![user-switch](https://github.com/user-attachments/assets/2cbdad95-7dd0-486c-b207-7b19f6650e48)

- Inside my repo all things come that is Playbook-webserver.yml, Playbook-LoadBalancer.yml, pratik.cfg.j2
![pratik-repo](https://github.com/user-attachments/assets/7df7fa00-d99e-4f9a-ae91-cd28b336d6e3)

**Just need to update jinja template where add Public_IPs of BackEnd(Only one manual Step)** BackEnd-public-ip file have all public Ips of backends

     sudo vim pratik.cfg.j2

![pratik.cfg.j2](https://github.com/user-attachments/assets/309a9252-6943-42c1-9d3e-01aa9f22ebbe)

- Ansible a downloaded by terraform using ansible-setup.sh file & also Git Install and clone my entire repo.
![ansible--version](https://github.com/user-attachments/assets/2374cbba-2113-4c5c-a089-b68f9e458fbc)

- Dynamic Inventory Set By Automation:(/etc/ansible/hosts)
![Inventory](https://github.com/user-attachments/assets/8f3d9c72-a4a7-4eb1-884f-6357791e0016)

- Ansible Config file set by Automation using Terraform remote-exec provisioner(/etc/ansible/ansible.cfg)
![ansible-cfg](https://github.com/user-attachments/assets/bf4fb9af-9f93-4664-94f7-eb6831f983e0)
![ansible-cfg-2](https://github.com/user-attachments/assets/66095492-88ad-4ca1-b89a-4a43748cd6a9)

**Now Only Need to Run Playbooks Our Entire Configuration of LoadBalncer & WebServer is creates:**

     ansible-playbook Playbook-webserver.yml
    
![webserver-playbook](https://github.com/user-attachments/assets/44e02c7f-7c68-4a5f-a9f1-ef2bb31670aa)

      ansible-playbook Playbook-LoadBalancer.yml

![LB-playbook](https://github.com/user-attachments/assets/50849a15-b716-4f49-b865-21dc25cbd180)

- On Browser we can access our WebServer by using FrontEnd-EC2 Public_IP which is also download on ansible master on file ForntEnd-public-ip.
![Browser-1](https://github.com/user-attachments/assets/1e45e363-1692-4d45-a79e-54eaaa80fc80)
![Browser-2](https://github.com/user-attachments/assets/84767a9a-00c2-47d8-b305-688bf9f0d138)
![Browser-3](https://github.com/user-attachments/assets/6dfe1006-d7ff-4213-b22c-c85a4f17cf9b)

## Terraform-Code-Explaination(main.tf)[HCL]

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

## 14. Resource: null_resource for PS-Null-Ansible-Master-ssh-Block
This null_resource is use to configuration of SSH on Ansible-Master node.

    resource "null_resource" "PS-Null-Ansible-Master-ssh-Block" {
      connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
      }
      provisioner "remote-exec" {
        inline = [  
          "sudo useradd psadmin" ,
          "echo 'psadmin:1234' | sudo chpasswd" ,
          "echo 'psadmin ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers" ,
          "sudo sed -i '/^PasswordAuthentication no/d' /etc/ssh/sshd_config",
          "sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config",
          "sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" ,
          "sudo systemctl restart sshd" 
        ] 
      }
    }

## 15. Resource: null_resource for PS-Null-Ansible-Master-Block-SAVE-BackEndIP
This null_resource dynamically store Public_IP's of all Backends EC2 in ansible master node at location /home/ec2-user with file named as "BackEnd-public-ip".

      join("\n", [
         for instance in aws_instance.PS-EC2-Backend-block : 
           "echo 'pratik ${instance.tags["Name"]} ${instance.public_ip} 1234' >> BackEnd-public-ip"
      ])

This uses a for loop to iterate through all the EC2 instances defined in the aws_instance.PS-EC2-Backend-block resource, 
which represents multiple EC2 backend instances.

For each instance, it appends the string 'pratik ${instance.tags["Name"]} ${instance.public_ip} 1234' to the BackEnd-public-ip file.

**${instance.tags["Name"]}:** Retrieves the Name tag of the backend instance.

**${instance.public_ip}:** Retrieves the public IP address of the backend instance.

**join("\n", [...])** function is used to join all the individual commands into a single list of commands, separated by newlines.

    resource "null_resource" "PS-Null-Ansible-Master-Block-SAVE-BackEndIP" {
      connection {
        type        = "ssh"
        user        = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host        = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
      }
      provisioner "remote-exec" {
        inline = [
          # Create a new file to store the backend instance IPs with user and password
          "echo 'Generating BackEnd IP list for Ansible Master' > BackEnd-public-ip"
      
          join("\n", [
            for instance in aws_instance.PS-EC2-Backend-block : 
              #"echo 'pratik ${ip.tags.Name} ${ip.public_ip} 1234' >> BackEnd-public-ip"
             "echo 'pratik ${instance.tags["Name"]} ${instance.public_ip} 1234' >> BackEnd-public-ip"
          ])
        ]
      }
      depends_on = [
        aws_instance.PS-EC2-Backend-block , 
        aws_instance.PS-EC2-Ansible-Master-Block 
      ]
    }
  
## 16. Resource: null_resource for PS-Null-Ansible-Master-Block-SAVE-FrontEndIP
This null_resource dynamically store Public_IP of FrontEnd EC2 in ansible master node at location /home/ec2-user with file named as "FrontEnd-public-ip".

    join("\n", [
      for instance in tolist([aws_instance.PS-EC2-FrontEnd-Block]) :
       "echo 'pratik ${instance.tags["Name"]} ${instance.public_ip} 1234' >> FrontEnd-public-ip"
    ])

**for instance in tolist([aws_instance.PS-EC2-FrontEnd-Block]):** This is a loop that iterates over the aws_instance.PS-EC2-FrontEnd-Block. 

The **tolist([...])** converts the list of EC2 instances into a list that can be looped through.

**pratik:** A static username.

**${instance.tags["Name"]}:** The Name tag of the frontend EC2 instance (EX, "Pratik-TF-FrontEnd").

**${instance.public_ip}:** The public IP address of the frontend EC2 instance.

**1234:** A static password (example).

**Fileformat** pratik <frontend_instance_name> <frontend_instance_public_ip> 1234

    resource "null_resource" "PS-Null-Ansible-Master-Block-SAVE-FrontEndIP" {
      connection {
        type        = "ssh"
        user        = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host        = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
      }
      provisioner "remote-exec" {
        inline = [
          # Create a new file to store the backend instance IPs with user and password
          "echo 'Generating FrontEnd IP list for Ansible Master' > FrontEnd-public-ip",
  
          join("\n", [
            for instance in tolist([aws_instance.PS-EC2-FrontEnd-Block]) :
              # for instance in aws_instance.PS-EC2-FrontEnd-Block :
              "echo 'pratik ${instance.tags["Name"]} ${instance.public_ip} 1234' >> FrontEnd-public-ip"
          ])
        ]
      } 
      depends_on = [
        aws_instance.PS-EC2-Ansible-Master-Block , 
        aws_instance.PS-EC2-FrontEnd-Block
       ]
    }

    output "FrontEnd_public_ip" {
      value = aws_instance.PS-EC2-FrontEnd-Block.public_ip
    }  

## 17. Resource: null_resource for PS-Null-Ansible-Installation-Block
This null_resource copy ansible-setup.sh script file on Ansible-MAster EC2 & execute.

**provisioner "file" Block**

    provisioner "file" {
      source      = "C:/Users/prati/terraform-2025/terraform-try5/ansible-setup.sh"
      destination = "/home/ec2-user/ansible-setup.sh"
    }

provisioner "file": This provisioner uploads files from your local machine to the remote EC2 instance. 
It is used to transfer the ansible-setup.sh script to the EC2 instance.

source: This specifies the local path of the ansible-setup.sh script.

destination: This specifies the remote path where the file will be uploaded on the EC2 instance.
In my case, it will be copied to /home/ec2-user/ansible-setup.sh on the EC2 instance.

**provisioner "remote-exec" Block**

    provisioner "remote-exec" {
      inline = [
        # script is executable
        "chmod +x /home/ec2-user/ansible-setup.sh",

        # Run the script with sudo
        "sudo /home/ec2-user/ansible-setup.sh"
       ]
    }

chmod +x /home/ec2-user/ansible-setup.sh: This command makes the ansible-setup.sh script executable on the EC2 instance by changing its permissions.

sudo /home/ec2-user/ansible-setup.sh: This command runs the ansible-setup.sh script with sudo.

    resource "null_resource" "PS-Null-Ansible-Installation-Block" {
      connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host= aws_instance.PS-EC2-Ansible-Master-Block.public_ip
      }
      provisioner "file" {
        source      = "C:/Users/prati/terraform-2025/terraform-try5/ansible-setup.sh"  
        destination = "/home/ec2-user/ansible-setup.sh"  
      }
      provisioner "remote-exec" {
        inline = [
          "chmod +x /home/ec2-user/ansible-setup.sh",
          "sudo /home/ec2-user/ansible-setup.sh"
        ]
      }
    } 

## 18. Resource: null_resource for PS-Null-Ansible-Master-SetAnsible-Config
This null_resource use for settings ansible config file

**sudo sed -i 's/^#become=True/become=True/' /etc/ansible/ansible.cfg** -->>  This command uncomment the become=True line and enables privilege
escalation, allowing Ansible to use sudo to elevate permissions during playbook runs.

**sudo sed -i 's/^#become_ask_pass=False/become_ask_pass=False/' /etc/ansible/ansible.cfg:** -->> This command enables password-based privilege 
escalation, ensuring that sudo does not ask for a password when escalating privileges. The False ensures the prompt to ask for the password is disabled.

**sudo sed -i 's/^#become_method=sudo/become_method=sudo/' /etc/ansible/ansible.cfg:**  -->> his command sets the become_method to sudo. 
It tells Ansible to use sudo as the method to escalate privileges when needed.

**sudo sed -i 's/^#become_user=root/become_user=root/' /etc/ansible/ansible.cfg:** -->> This command sets the user that Ansible will become when 
escalating privileges. Here, it ensures that Ansible will use the root user.

**sudo sed -i 's/^#host_key_checking = False/host_key_checking = False/' /etc/ansible/ansible.cfg** -->> This command disables host key checking when 
Ansible connects to remote hosts via SSH. This is useful in automated environments where host keys might change, and it's undesirable to manually 
approve each new key.

    resource "null_resource" "PS-Null-Ansible-Master-SetAnsible-Config" {
      connection {
        type        = "ssh"
        user        = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host        = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
      }
      provisioner "remote-exec" {
        inline = [
          # Uncomment privilege escalation lines
          "sudo sed -i 's/^#become=True/become=True/' /etc/ansible/ansible.cfg",
          "sudo sed -i 's/^#become_ask_pass=False/become_ask_pass=False/' /etc/ansible/ansible.cfg",
          "sudo sed -i 's/^#become_method=sudo/become_method=sudo/' /etc/ansible/ansible.cfg",
          "sudo sed -i 's/^#become_user=root/become_user=root/' /etc/ansible/ansible.cfg",
          "sudo sed -i 's/^#host_key_checking = False/host_key_checking = False/' /etc/ansible/ansible.cfg" 
        ]
      }
      depends_on = [
        aws_instance.PS-EC2-Ansible-Master-Block ,
        null_resource.PS-Null-Ansible-Installation-Block
       ]
    }

## 19. Resource: null_resource for PS-Null-Ansible-Master-Block-Inventory-setup
This null_resource set Inventory dynamically in ansible master.

**echo '[web]' | sudo tee -a /etc/ansible/hosts > /dev/null:**  This command adds the [web] group to the Ansible inventory file (/etc/ansible/hosts).
The **tee** command appends the string [web] to the /etc/ansible/hosts file (without outputting it to the console due to the > /dev/null).

**join("\n", [...]):**  This block dynamically adds all the backend EC2 instances to the [web] group in the Ansible inventory file.

The for instance in aws_instance.PS-EC2-Backend-block loop goes through each backend EC2 instance (PS-EC2-Backend-block) and 
appends the corresponding public IP address along with Ansible-specific connection details (ansible_user, ansible_password, and ansible_connection).

**echo '[lb]' | sudo tee -a /etc/ansible/hosts > /dev/null:** This command adds the [lb] group to the Ansible inventory file (/etc/ansible/hosts).

**echo '${aws_instance.PS-EC2-FrontEnd-Block.public_ip} ansible_user=pratik ansible_password=1234 ansible_connection=ssh' | 
sudo tee -a /etc/ansible/hosts > /dev/null:**  This command adds the frontend EC2 instance (PS-EC2-FrontEnd-Block) to the [lb] group in the Ansible inventory file.

**These commands configure the Ansible inventory file by adding two groups:**

[web]: Contains all backend EC2 instances.
[lb]: Contains the frontend EC2 instance

    resource "null_resource" "PS-Null-Ansible-Master-Block-Inventory-setup" {
      connection {
        type        = "ssh"
        user        = "ec2-user"
        private_key = file("F:/psTerraform-key.pem")
        host        = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
      }
      provisioner "remote-exec" {
        inline = [
          "echo '[web]' | sudo tee -a /etc/ansible/hosts > /dev/null",
   
           join("\n", [
             for instance in aws_instance.PS-EC2-Backend-block :
             "echo '${instance.public_ip} ansible_user=pratik ansible_password=1234 ansible_connection=ssh' | sudo tee -a /etc/ansible/hosts > /dev/null"
           ]),
          "echo '[lb]' | sudo tee -a /etc/ansible/hosts > /dev/null",
   
          "echo '${aws_instance.PS-EC2-FrontEnd-Block.public_ip} ansible_user=pratik ansible_password=1234 ansible_connection=ssh' | sudo tee -a 
           /etc/ansible/hosts > /dev/null"
          ]
        }
   
       depends_on = [
         aws_instance.PS-EC2-Backend-block,
         aws_instance.PS-EC2-FrontEnd-Block,
         aws_instance.PS-EC2-Ansible-Master-Block , 
         null_resource.PS-Null-Ansible-Installation-Block
       ]
    }

## 20. Destroy & Information about Author:

**when = destroy:** This specifies that the command should only run when the resource is destroyed.

**command = "echo ALL set-up/Infrastucture or servers destroyed....> All_Destroy.txt":** The command to be executed. It writes a message to a 
file named All_Destroy.txt indicating that the setup, infrastructure, or servers have been destroyed. The output is redirected to the file.

    resource "null_resource" "PS-Local-exec-Destroy-block" {
      provisioner "local-exec" {
        when    = destroy
        command = "echo ALL set-up/Infrastucture or servers destroyed....> All_Destroy.txt"
      }
    }
    variable "PSMap" {
      type = map
      default = {
        AuthorName = "Pratik_Shinde" ,
        IaC = "Terraform" ,
        Provider_use = "AWS_Cloud" ,
        Project_Name = "End-to-End Cloud Automation with Terraform, Ansible, and GitHub"  
      }
    }

    output "Information_about_Project" {
      value = var.PSMap
    }
   
   
