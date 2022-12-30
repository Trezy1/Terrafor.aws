
provider "aws" {
  region = "us-east-1"
  Shared_credentials_file = 

}
# line 4 I have downloaded CLI and refrenced the path of the access key. Left it blank for now.



# 1- create vpc 

resource "aws_vpc" "abdi-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "production"
  }
}
# 2- create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.abdi-vpc.id


}
# 3 - create custome route table 

resource "aws_route_table" "abdi-route-table" {
  vpc_id = aws_vpc.abdi-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id              = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "abdi"
  }
}
# 4- create a subnet 

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.abdi-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "abdi-subnet"
  }
}
# 5 - associate subnet with route table 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.abdi-route-table.id
}

# 6 -create security group to allow port 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web-traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.abdi-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

   ingress {
    description      = "SSH"
    from_port        = 2
    to_port          = 2
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7 - create a network interface with an ip in the subet that was created in step 4

resource "aws_network_interface" "web-server-abdi" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  }
# 8 - assign an elestic ip to the network interface created in step 7 

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-abdi.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# 9 - create ubuntu server and install/enable apacge2

resource "aws_instance" "web-server-instance" {
  ami = "ami-0574da719dca65348"
  instance_type ="t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-abdi.id
  }
  user_data = <<-EOF
               #1/bin/bash
               sudo apt update -y
               sudo apt install apache2 -y
               sudo systemctl start apache2
               sudo bash -c "echo your very first webs server > /var/www/html/index.html"
               EOF
    tags = {
        name = "web-server"
       } 
}



