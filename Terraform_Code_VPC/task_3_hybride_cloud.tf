provider "aws" {
    region = "ap-southeast-2"
    shared_credentials_file = "$HOME/.aws/credentials"
}

# VPC creation
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  tags = {
    Name = "Task_3"
  }
}

# Public Subnet Creation
resource "aws_subnet" "public_subnet" {
  depends_on = [
    aws_vpc.main
  ]
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "Task_3_pub"
  }
}

# Private Subnet Creation
resource "aws_subnet" "private_subnet" {
  depends_on = [
    aws_vpc.main
  ]
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Task_3_pri"
  }
}

# Internet Gateway to reach to the Internet
resource "aws_internet_gateway" "int_gw" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public_subnet,
  ]
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Task_3"
  }
}

# Routing Table so the resources in public subnet know the proper route to internet
resource "aws_route_table" "ig_route_table" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public_subnet,
    aws_internet_gateway.int_gw,
  ]
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int_gw.id
  }

  tags = {
    Name = "task_3_route_table_public_subnet"
  }
}

# Associate Public subnet and with route table, so that resources in public subnet can go out to the internet
resource "aws_route_table_association" "route_table_subnet_association" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public_subnet,
    aws_internet_gateway.int_gw,
    aws_route_table.ig_route_table,
  ]
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.ig_route_table.id
}

# Creating private key
resource "tls_private_key" "this" {
    depends_on = [
        aws_route_table_association.route_table_subnet_association,
    ]
    algorithm = "RSA"
    rsa_bits = 2048
}

# downloading the private key in local system
resource "local_file" "private_key" {
  depends_on = [
    tls_private_key.this,
  ]
  content = tls_private_key.this.private_key_pem
  filename = "deployer_key1.pem"
  file_permission = 0777
}

# getting the public key to attach to resource
resource "aws_key_pair" "key_gen" {
    depends_on = [
        tls_private_key.this
    ]
    key_name = "deployer_key1"
    public_key = tls_private_key.this.public_key_openssh
}

# Security Group for Wordpress to allow port 22, 80
resource "aws_security_group" "wordpress" {
  depends_on = [
    aws_vpc.main,
    tls_private_key.this,
    aws_key_pair.key_gen,
  ]
  name = "wordpress"
  description = "Allow ssh and https request"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow to go to internet"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Task_3"
  }
}

# mysql security group
resource "aws_security_group" "mysql_sg" {
  depends_on = [
    aws_vpc.main,
    tls_private_key.this,
    aws_key_pair.key_gen,
  ]
  name = "mysql_sg"
  description = "Allow wordpress connection"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "task_3"
  }
}

# ingress rule for mysql security group, ssh allow
resource "aws_security_group_rule" "mysql_ingress_rule_ssh" {
  depends_on = [
    aws_security_group.mysql_sg,
    aws_security_group.wordpress,
  ]
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = [aws_vpc.main.cidr_block]
  security_group_id = aws_security_group.mysql_sg.id
}

# ingress rule for mysql security group, allow mysql request-respose
resource "aws_security_group_rule" "mysql_ingress_rule_sql" {
  depends_on = [
    aws_security_group.mysql_sg,
    aws_security_group.wordpress,
  ]
  type = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id = aws_security_group.mysql_sg.id
  source_security_group_id = aws_security_group.wordpress.id
}

# egress rule for mysql security group
resource "aws_security_group_rule" "mysql_egress_rule" {
  depends_on = [
    aws_security_group.mysql_sg,
    aws_security_group.wordpress,
  ]
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mysql_sg.id
}

# mysql instance creation
resource "aws_instance" "mysql_instance" {
  depends_on = [
    aws_subnet.private_subnet,
    aws_key_pair.key_gen,
    aws_security_group.mysql_sg,
    aws_security_group_rule.mysql_ingress_rule_ssh,
    aws_security_group_rule.mysql_ingress_rule_sql,
    aws_security_group_rule.mysql_egress_rule,
  ]

  ami = "ami-0810abbfb78d37cdf"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_gen.key_name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  subnet_id = aws_subnet.private_subnet.id

  tags = {
    Name = "task_3_mysql_instance"
  }
}

# output "mysql_instance_def" {
#   value = aws_instance.mysql_instance
# }

# Wordpress Instance creation
resource "aws_instance" "wordpress_instance" {
  depends_on = [
    aws_subnet.public_subnet,
    aws_key_pair.key_gen,
    aws_security_group.wordpress,
    aws_instance.mysql_instance,
  ]
  
  ami = "ami-0810abbfb78d37cdf"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_gen.key_name
  vpc_security_group_ids = [aws_security_group.wordpress.id]
  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "task_3_wordpress_instance"
  }
}

# output "wordpress_instance_def" {
#   value = aws_instance.wordpress_instance
# }

# settings to be done in wordpress instance to launch wordpress using docker
resource "null_resource" "instance_config" {
    depends_on = [
        aws_instance.wordpress_instance,
    ]

    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = tls_private_key.this.private_key_pem
        host = aws_instance.wordpress_instance.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "sudo su << EOF",
            "echo '[docker]' >> /etc/yum.repos.d/docker.repo",
            "echo 'baseurl=https://download.docker.com/linux/centos/7/x86_64/stable/' >> /etc/yum.repos.d/docker.repo",
            "echo 'gpgcheck=0' >> /etc/yum.repos.d/docker.repo",
            "EOF",
            "sudo yum install -y docker-ce --nobest",
            "sudo systemctl start docker",
            "sudo docker container run -dit --expose 80 -p 80:80 --name wp wordpress:php7.2-apache",
        ]
    }
}