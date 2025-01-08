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

resource "aws_vpc" "PS-vpc-block" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Pratik-vpc"
  }
}


resource "aws_subnet" "PS-Subnet-block" {

  count = length(var.SubnetRange)
  vpc_id = aws_vpc.PS-vpc-block.id
  cidr_block = element(var.SubnetRange , count.index)
  availability_zone = element(var.AZRange , count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "Pratik-Subnet"
  }
  depends_on = [
    aws_vpc.PS-vpc-block
  ]
}

variable "SubnetRange" {
    type = list(string)
    default = [ "10.0.1.0/24" , "10.0.2.0/24"]
}

variable "AZRange" {
   type = list(any)
   default = ["ap-south-1a" , "ap-south-1b"]
}


resource "aws_internet_gateway" "PS-Gateway-block" {
   
   vpc_id = aws_vpc.PS-vpc-block.id
   tags = {
     Name = "Pratik-gateway"
   }
}

resource "aws_route_table" "PS-route-block" {

  vpc_id = aws_vpc.PS-vpc-block.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.PS-Gateway-block.id
  }
  tags = {
    Name = "Pratik-route"
  }
}


resource "aws_route_table_association" "PS-T_asso-block" {
 
  count = length(var.SubnetRange)
  subnet_id = element(aws_subnet.PS-Subnet-block.*.id , count.index)
  route_table_id = aws_route_table.PS-route-block.id
  
}

resource "aws_security_group" "PS-SG-block" {
 
  vpc_id = aws_vpc.PS-vpc-block.id     #IMP 
  
  name = "Pratik-SG-By-Terra"
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
     aws_vpc.PS-vpc-block ,
     aws_subnet.PS-Subnet-block ,
     aws_route_table_association.PS-T_asso-block
  ]
}

variable "Allow-traffic"{
   type = list(number)
   default = [ 80 , 22 , 8080 , 443]
}

resource "aws_instance" "PS-ec2-block" {
  ami = data.aws_ami.PS-ami-block.id
  key_name = "psTerraform-key"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.PS-SG-block.id]
  subnet_id = element(aws_subnet.PS-Subnet-block.*.id , 0)
  associate_public_ip_address = true 
  
  tags = {
    Name = "Pratik-ec2"
  }

  depends_on = [
     aws_vpc.PS-vpc-block ,
     aws_subnet.PS-Subnet-block ,
     aws_security_group.PS-SG-block
  ]
}

resource "null_resource" "PS-NULL-block" {
   
   connection {
     type = "ssh"
     user = "ec2-user"
     private_key = file("F:/psTerraform-key.pem")
     host = aws_instance.PS-ec2-block.public_ip
   } 
   provisioner "remote-exec" {
     inline = [

       # Create the pratik user 
      "sudo useradd pratik",

      # Set the password for the user
      "echo 'pratik:5577' | sudo chpasswd",

      # Grant root privileges for pratik user and nopass ask while using
      "echo 'pratik ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers",
      
      # Remove the line "PasswordAuthentication no" if it exists(This line is already present so we remove it)
      "sudo sed -i '/^PasswordAuthentication no/d' /etc/ssh/sshd_config",

      # Modify SSH config to allow root login and password authentication (This is for Ansible master-slave architecture)
      "sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config",

      # Restart SSH service to apply changes
      "sudo systemctl restart sshd"
    ]
   }
 }

resource "null_resource" "PS-Local-exec" {
   
    provisioner "local-exec"{
      when = destroy
      command = "echo hi setup is destroying and it will destroyed....> destroyCall1.txt"
    }
}
