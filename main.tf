### "aws_ami data source for retrieve AMI id for EC2" 
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

### "aws_vpc resource for create vpc for aws"
resource "aws_vpc" "PS-vpc-block" {

  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TF-Pratik-vpc"
  }
}

### "aws_subnet" is for create subnet, Here use Multi Subnet AZs
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


variable "SubnetRange" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}


variable "AZRange" {
  type    = list(any)
  default = ["ap-south-1a", "ap-south-1b"]
}


### "aws_internet_gateway" resource for my VPC
resource "aws_internet_gateway" "PS-Gateway-block" {

  vpc_id = aws_vpc.PS-vpc-block.id
  tags = {
    Name = "TF-Pratik-gateway"
  }
}


### aws_route_table resource
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


### In This Resource use Count because Multi Subnet i create
resource "aws_route_table_association" "PS-T_asso-block" {

  count          = length(var.SubnetRange)
  subnet_id      = element(aws_subnet.PS-Subnet-block.*.id, count.index)
  route_table_id = aws_route_table.PS-route-block.id

}


### This resource for create Dynamic SG for my VPC
resource "aws_security_group" "PS-SG-block" {

  vpc_id = aws_vpc.PS-vpc-block.id

  name = "Pratik-SG-By-TF"
  description = "Pratik-allow-sg-for-own-vpc"

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

variable "Allow-traffic" {
  type    = list(number)
  default = [80, 22, 8080, 443]
}

### "In This Resource Create BackEnds(3-Instances) with count meta argument" 
resource "aws_instance" "PS-EC2-Backend-block" {

  ami = data.aws_ami.PS-ami-block.id
  key_name = "psTerraform-key"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.PS-SG-block.id]
       # element is used because multiple subnets created .*.id
       # "count.index % 2" this enable Round Robin Alogorithm A -> B ->A ->B
  subnet_id = element(aws_subnet.PS-Subnet-block.*.id , count.index % 2)
  associate_public_ip_address = true

  count = 3

  tags = {
    #Name = "Pratik-TF-Backend-${count.index + 1}"
    Name = "Pratik-TF-${var.InstanceName[count.index]}"
  }

  depends_on = [
    aws_vpc.PS-vpc-block,
    aws_subnet.PS-Subnet-block,
    aws_security_group.PS-SG-block
  ]
}


variable "InstanceName" {
  type    = list(string)
  default = ["Backend-1", "Backend-2", "Backend-3"]
}
output "PS-Backend-IPs" {
  value = aws_instance.PS-EC2-Backend-block.*.public_ip
}


### This null_resource use for Backend SSH Sonfiguration
resource "null_resource" "PS-NULL-Backend-ssh-block" {

     # length for BackEnd resource
  count = length(aws_instance.PS-EC2-Backend-block)

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("F:/psTerraform-key.pem")
      # Here use count.index because i creates 3 EC2 for BackEnd
    host        = aws_instance.PS-EC2-Backend-block[count.index].public_ip
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


### This Resource create FrontEnd Instance for loadBlancer
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


### This null_resource use for FrontEnd SSH Configuration
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


### This Resource Launch a EC2 Instance for Ansible-Master
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


### This null_resource for Ansible Master SSH Configuration
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
      "sudo systemctl restart sshd" ,
    ] 
  }
}


### This null_resource for store dynamically Public_IP of Backend's in AnsibleMaster EC2
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
      "echo 'Generating BackEnd IP list for Ansible Master' > BackEnd-public-ip",

      # Loop through all the backend EC2 instances and add their details to the file
      # Each line will be in the format: 'pratik <public_ip> 1234'
      
      
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


### This null_resource for store FrontEnd Public_IP in Ansible Master EC2
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


### This null_resource copy ansible-setup.sh script file on Ansible & execute 
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
        # script is executable
        "chmod +x /home/ec2-user/ansible-setup.sh",

        # Run the script with sudo
        "sudo /home/ec2-user/ansible-setup.sh"
      ]
    }
}


### This null_resource use for settings ansible config file
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

      # Uncomment the host_key_checking line
      "sudo sed -i 's/^#host_key_checking=False/host_key_checking=False/' /etc/ansible/ansible.cfg"
    ]
  }

  depends_on = [
    aws_instance.PS-EC2-Ansible-Master-Block ,
    null_resource.PS-Null-Ansible-Installation-Block
  ]
}


### this null_resource set Inventory dynamically in ansible master

resource "null_resource" "PS-Null-Ansible-Master-Block-Inventory-setup" {

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("F:/psTerraform-key.pem")
    host        = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Add web group name in Inventory
      "echo '[web]' | sudo tee -a /etc/ansible/hosts > /dev/null",

      # Add backend EC2 instances to the 'web' group
      join("\n", [
        for instance in aws_instance.PS-EC2-Backend-block :
          "echo '${instance.public_ip} ansible_user=pratik ansible_password=1234 ansible_connection=ssh' | sudo tee -a /etc/ansible/hosts > /dev/null"
      ]),

      # Add the lb host Group Name
      "echo '[lb]' | sudo tee -a /etc/ansible/hosts > /dev/null",

      # Add the frontend EC2 instance to the 'lb' group
      "echo '${aws_instance.PS-EC2-FrontEnd-Block.public_ip} ansible_user=pratik ansible_password=1234 ansible_connection=ssh' | sudo tee -a /etc/ansible/hosts > /dev/null"
    ]
  }

  depends_on = [
    aws_instance.PS-EC2-Backend-block,
    aws_instance.PS-EC2-FrontEnd-Block,
    aws_instance.PS-EC2-Ansible-Master-Block , 
    null_resource.PS-Null-Ansible-Installation-Block
  ]
}


### This null_resource run only if terraform destroy cmd run
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
