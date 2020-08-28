provider "aws" {
    region = "ap-southeast-2"
    shared_credentials_file = "$HOME/.aws/credentials"
}

data "aws_vpc" "default" {
    default = true
}

resource "aws_security_group" "rds_sg_group" {
    name = "allow_minikube"
    description = "allows the connection from minikube"
    vpc_id = data.aws_vpc.default.id

    ingress {
        description = "allow all"
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_db_instance" "mysqlrdsdb" {
    depends_on = [
        aws_security_group.rds_sg_group
    ]
    engine = "mysql"
    storage_type = "gp2"
    engine_version = "5.7.30"
    instance_class = "db.t2.micro"
    name = "wordpressdb"
    username = "wordpress"
    password = "wordpress1234"
    allocated_storage = 10
    parameter_group_name = "default.mysql5.7"
    vpc_security_group_ids = [aws_security_group.rds_sg_group.id]
    publicly_accessible = true

    skip_final_snapshot = true

    tags = {
        Name = "wordpress_RDS"
    }
}

output "dns" {
    value = aws_db_instance.mysqlrdsdb.address
}