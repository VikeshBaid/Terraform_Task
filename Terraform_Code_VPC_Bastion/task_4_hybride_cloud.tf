provider "aws" {
    region = "ap-southeast-2"
    shared_credentials_file = "$HOME/.aws/credentials"
}

# creating VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"

    enable_dns_hostnames = true
    tags = {
        Name = "Task_4"
    }
}

# creating public subnet in VPC
resource "aws_subnet" "public_subnet" {
    depends_on = [
        aws_vpc.main
    ]
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"

    map_public_ip_on_launch = true
    
    tags = {
        Name = "Task_4_pub"
    }
}

# creating private subnet in VPC
resource "aws_subnet" "private_subnet" {
    depends_on = [
        aws_vpc.main
    ]
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    tags = {
        Name = "Task_4_pri"
    }
}

# creating internet gateway to connect public subnet to internet
resource "aws_internet_gateway" "int_gw" {
    depends_on = [
        aws_vpc.main,
        aws_subnet.public_subnet,
        aws_subnet.private_subnet,
    ]
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "Task_4"
    }
}

# creating routing table for internet gateway
resource "aws_route_table" "ig_route_table" {
    depends_on = [
        aws_internet_gateway.int_gw,
    ]
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.int_gw.id
    }

    tags = {
        Name = "task_4_route_table_public_subnet"
    }
}

# associating Public subnet and internet gateway
resource "aws_route_table_association" "route_table_subnet_association" {
    depends_on = [
        aws_internet_gateway.int_gw,
        aws_route_table.ig_route_table,
    ]

    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.ig_route_table.id
}

### New Code 

# Elastic IP for nat gateway
resource "aws_eip" "psip" {
    depends_on = [
        aws_route_table_association.route_table_subnet_association,
    ]
    vpc = true

    tags = {
        Name = "task_4_eip"
    }
}

# creating nat gateway to connect private subnet to internet
resource "aws_nat_gateway" "nat_gw" {
    depends_on = [
        aws_eip.psip,
        aws_route_table_association.route_table_subnet_association,
    ]
    allocation_id = aws_eip.psip.id
    subnet_id     = aws_subnet.public_subnet.id

    tags = {
        Name = "task_4_NAT"
    }
}

# routing table for nat gateway
resource "aws_route_table" "nat_route_table" {
    depends_on = [
        aws_nat_gateway.nat_gw,
    ]

    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.nat_gw.id
    }

    tags = {
        Name = "task_4_route_table_public_subnet_nat"
    }
}

# associating routing table with nat gateway
resource "aws_route_table_association" "route_table_pri_subnet_association" {
    depends_on = [
        aws_subnet.private_subnet,
        aws_route_table.nat_route_table,
    ]
    
    subnet_id      = aws_subnet.private_subnet.id
    route_table_id = aws_route_table.nat_route_table.id
}

# creating key pair
resource "tls_private_key" "this" {
    algorithm = "RSA"
    rsa_bits = 2048
}

# downloading private to system
resource "local_file" "private_key" {
  depends_on = [
    tls_private_key.this,
  ]
  content = tls_private_key.this.private_key_pem
  filename = "deployer_key1.pem"
  file_permission = 0777
}

# getting public key to attach it to instances
resource "aws_key_pair" "key_gen" {
    depends_on = [
        tls_private_key.this
    ]
    key_name = "deployer_key1"
    public_key = tls_private_key.this.public_key_openssh
}

# output "key" {
#     value = tls_private_key.this
# }
 
# security group for wordpress, allow ssh(22) and http(80)
resource "aws_security_group" "wordpress" {
    depends_on = [
        aws_vpc.main,
        aws_route_table_association.route_table_pri_subnet_association,
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
        Name = "Task_4"
    }
}

# security group mysql
resource "aws_security_group" "mysql_sg" {
    depends_on = [
        aws_vpc.main,
        aws_security_group.wordpress,
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

# mysql security group rule for mysql request-response
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

# security group for bastion host
resource "aws_security_group" "bastion_instance_sg" {
    depends_on = [
        aws_vpc.main,
        aws_security_group.mysql_sg,
        aws_security_group.wordpress,
        aws_security_group_rule.mysql_ingress_rule_ssh,
        aws_security_group_rule.mysql_ingress_rule_sql,
        aws_security_group_rule.mysql_egress_rule,
    ]

    name = "bastion"
    description = "Allow to connect to private subnet instance"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "ssh"
        from_port = 22
        to_port = 22
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
}

# security group ro connect bastion host with mysql instance
resource "aws_security_group" "bastion_mysql_connect_sg" {
    depends_on = [
        aws_security_group.bastion_instance_sg,
    ]
    name = "bastion_mysql_connect"
    description = "allow connection to mysql_instance"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "ssh"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.bastion_instance_sg.id]
    }

    ingress {
        description = "connect to application in another instance"
        from_port = 7
        to_port = 7
        protocol = "tcp"
        security_groups = [aws_security_group.bastion_instance_sg.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    } 
}

# creating mysql instance 
resource "aws_instance" "mysql_instance" {
    depends_on = [
        aws_subnet.private_subnet,
        aws_key_pair.key_gen,
        aws_security_group.mysql_sg,
        aws_security_group_rule.mysql_ingress_rule_ssh,
        aws_security_group_rule.mysql_ingress_rule_sql,
        aws_security_group_rule.mysql_egress_rule,
        aws_security_group.bastion_instance_sg,
        aws_security_group.bastion_mysql_connect_sg,
    ]

    ami = "ami-0810abbfb78d37cdf"
    instance_type = "t2.micro"
    key_name = aws_key_pair.key_gen.key_name
    vpc_security_group_ids = [aws_security_group.mysql_sg.id, aws_security_group.bastion_mysql_connect_sg.id]
    subnet_id = aws_subnet.private_subnet.id
    
    tags = {
        Name = "task_4_mysql_instance"
    }
}

# output "mysql_instance_def" {
#     value = aws_instance.mysql_instance
# }

# creating bastion host instance
resource "aws_instance" "bastion_instance"{
    depends_on = [
        aws_subnet.public_subnet,
        aws_key_pair.key_gen,
        aws_security_group.bastion_instance_sg,
        aws_instance.mysql_instance,
    ]

    ami = "ami-0810abbfb78d37cdf"
    instance_type = "t2.micro"
    key_name = aws_key_pair.key_gen.key_name
    vpc_security_group_ids = [aws_security_group.bastion_instance_sg.id]
    subnet_id = aws_subnet.public_subnet.id

#     provisioner "file" {
#     source      = "Terraform_Code_VPC_Bastion/${aws_key_pair.key_gen.key_name}"
#     destination = "/home/ec2-user/${aws_key_pair.key_gen.key_name}"
#   }

    tags = {
        Name = "task_4_bastion_instance"
    }
}

# resource "null_resource" "mysql_setting_by_bastion host" {
#     depends_on = [
#         aws_subnet.public_subnet,
#         aws_key_pair.key_gen,
#         aws_security_group.bastion_instance_sg,
#         aws_security_group.bastion_mysql_connect_sg,
#         aws_instance.mysql_instance,
#     ]

#     connection {
#         type = "ssh"
#         user = "ec2-user"
#         private_key = tls_private_key.this.private_key_pem
#         host = aws_instance.bastion_instance.public_ip
#     }

#     provisioner "remote-exec" {
#         inline = [
#             "sudo chmod 400 ${aws_key_pair.key_gen.key_name}"
#             "sudo ssh -i ${aws_key_pair.key_gen.key_name} "
#         ]
    
#     }
# }

# creating wordpress_instance
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
        Name = "task_4_wordpress_instance"
    }
}

# settings to be done in wordpress instance to launch wordpress using docker
resource "null_resource" "_wordpress_instance_config" {
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

# output "wordpress_instance_def" {
#     value = aws_instance.wordpress_instance
# }