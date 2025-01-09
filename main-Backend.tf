data "aws_ami" "PS-ami-block" {

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}




resource "aws_vpc" "PS-vpc-block" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TF-Pratik-vpc"
  }
}


resource "aws_subnet" "PS-Subnet-block" {

  count                   = length(var.SubnetRange)
  vpc_id                  = aws_vpc.PS-vpc-block.id
  cidr_block              = element(var.SubnetRange, count.index)
  availability_zone       = element(var.AZRange, count.index)
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


resource "aws_internet_gateway" "PS-Gateway-block" {

  vpc_id = aws_vpc.PS-vpc-block.id
  tags = {
    Name = "TF-Pratik-gateway"
  }
}

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


resource "aws_route_table_association" "PS-T_asso-block" {

  count          = length(var.SubnetRange)
  subnet_id      = element(aws_subnet.PS-Subnet-block.*.id, count.index)
  route_table_id = aws_route_table.PS-route-block.id

}

resource "aws_security_group" "PS-SG-block" {

  vpc_id = aws_vpc.PS-vpc-block.id    #IMP

  name        = "Pratik-SG-By-TF"
  description = "Pratik-allow-sg-for-own-vpc"

  dynamic "ingress" {
    for_each = var.Allow-traffic
    iterator = port
    content {
      description = "allow inbound rule"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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




resource "aws_instance" "PS-EC2-Backend-block" {
  ami                    = data.aws_ami.PS-ami-block.id
  key_name               = "psTerraform-key"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.PS-SG-block.id]

  subnet_id                   = element(aws_subnet.PS-Subnet-block.*.id , count.index % 2)
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

variable "InstanceName" {
  type    = list(string)
  default = ["Backend-1", "Backend-2", "Backend-3"]
}


resource "null_resource" "PS-NULL-Backend-block" {
  count = 3

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("F:/psTerraform-key.pem")
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

resource "null_resource" "PS-Local-exec" {

  provisioner "local-exec" {

    when    = destroy
    command = "echo hi setup is destroying and it will destroyed....> destroyCall1.txt"
  }

}


resource "aws_instance" "PS-EC2-FrontEnd-Block" {

  ami = data.aws_ami.PS-ami-block.id
  instance_type = "t2.micro"
  key_name = "psTerraform-key"
  vpc_security_group_ids = [aws_security_group.PS-SG-block.id]
  
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

resource "null_resource" "PS-Null-Frontend-Block" {

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

resource "null_resource" "PS-Null-Ansible-Master-Block" {

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
    


resource "null_resource" "PS-Null-Ansible-Master-Block-SAVE-IP" {

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("F:/psTerraform-key.pem")
    host        = aws_instance.PS-EC2-Ansible-Master-Block.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Create a new file to store the backend instance IPs with user and password
      "echo 'Generating Backend IP list for Ansible Master' > Backend-public-ip",

      # Loop through all the backend EC2 instances and add their details to the file
      # Each line will be in the format: 'pratik <my-ec2-name> <public_ip> 1234'
      join("\n", [
        for ip in aws_instance.PS-EC2-Backend-block : 
          "echo 'pratik ${ip.tags.Name} ${ip.public_ip} 1234' >> Backend-public-ip"
      ])
    ]
  }

  depends_on = [
    aws_instance.PS-EC2-Backend-block
  ]
}    



resource "null_resource" "PS-Null-Ansible-Master-Block-Setup" {
    
    connection {
       type = "ssh"
       user = "ec2-user"
       private_key = file("F:/psTerraform-key.pem")
       host= aws_instance.PS-EC2-Ansible-Master-Block.public_ip
    }
     provisioner "file" {
       source      = "C:/Users/prati/terraform-2025/terraform-try5/ansible-setup.sh"  
       destination = "/home/psadmin/ansible-setup.sh"  
     }

     provisioner "remote-exec" {
        inline = [
          # script is executable
          "chmod +x /home/psadmin/ansible-setup.sh",

          # Run the script with sudo
          "sudo /home/psadmin/ansible-setup.sh"
        ]
     }

}


