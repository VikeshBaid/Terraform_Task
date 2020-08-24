provider "aws" {
    region = "ap-southeast-2"
    shared_credentials_file = "$HOME/.aws/credentials"
}

# getting default VPC value
data "aws_vpc" "default" {
    default = true
}

# creating key pair
resource "tls_private_key" "this" {
    algorithm = "RSA"
    rsa_bits = 4096
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

# security group for webserver
resource "aws_security_group" "webserver" {

    name = "webserver"
    description = "Allow ssh and https request"
    vpc_id = data.aws_vpc.default.id

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

resource "aws_instance" "webserver" {
    depends_on = [
        tls_private_key.this,
        aws_security_group.ssh_and_httpd
    ]
    
    ami = "ami-0810abbfb78d37cdf"
    instance_type = "t2.micro"
    key_name = "deployer_key1"
    security_groups = [aws_security_group.ssh_and_httpd.name]

    tags = {
        Name = "task_one1"
    }
}

