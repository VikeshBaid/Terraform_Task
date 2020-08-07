provider "aws" {
    region = "ap-southeast-2"
    shared_credentials_file = "$HOME/.aws/credentials"
}

resource "tls_private_key" "this" {
    algorithm = "RSA"
    rsa_bits = 2048
}

module "key_pair" {
    source = "terraform-aws-modules/key-pair/aws"
    key_name = "deployer_key1"
    public_key = tls_private_key.this.public_key_openssh
}

data "aws_vpc" "default" {
    default = true
}

resource "aws_security_group" "ssh_and_httpd" {
    name = "web-server"
    description = "allowing inbound http requests"
    vpc_id = data.aws_vpc.default.id

    ingress{
        from_port   = 2049
        to_port     = 2049
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
       
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0 
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_efs_file_system" "efs_121" {
    creation_token = "efs"
    throughput_mode = "bursting"

    tags = {
        Name = "efs_for_webserver"
    }
}

# output "file_system_subnet_id" {
#     value = aws_efs_file_system.efs_121
# }

resource "aws_instance" "webserver" {
    depends_on = [
        tls_private_key.this,
        aws_security_group.ssh_and_httpd
    ]
    ami = "ami-0a58e22c727337c51"
    instance_type = "t2.micro"
    key_name = "deployer_key1"
    security_groups = [aws_security_group.ssh_and_httpd.name]

    tags = {
        Name = "task_two2"
    }
}

data "aws_subnet" "subnets"{
    depends_on = [
        aws_instance.webserver
    ]
    vpc_id = data.aws_vpc.default.id
    availability_zone = aws_instance.webserver.availability_zone
}

# output "subnets" {
#     value = data.aws_subnet.subnets
# }

resource "aws_efs_mount_target" "alpha" {
    depends_on = [
        aws_efs_file_system.efs_121,
        aws_security_group.ssh_and_httpd,
        data.aws_subnet.subnets,
    ]
    file_system_id = aws_efs_file_system.efs_121.id
    subnet_id      = data.aws_subnet.subnets.id
    security_groups = [aws_security_group.ssh_and_httpd.id]
}


# output "webserver_subnet_id" {
#   value = aws_instance.webserver.subnet_id
# }



# output "subnet_created_acc_webserver" {
#     value = data.aws_subnet.subnets.id
# }


resource "null_resource" "instance_config" {
    depends_on = [
        aws_instance.webserver,
        aws_efs_mount_target.alpha,
    ]

    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = tls_private_key.this.private_key_pem
        host = aws_instance.webserver.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "sudo yum install httpd php git amazon-efs-utils -y",
            "sudo mount -t efs ${aws_efs_file_system.efs_121.id}:/ /var/www/html",
            "echo '${aws_efs_file_system.efs_121.id}:/ /var/www/html efs _netdev 0 0' | sudo tee -a /etc/fstab", 
            "sudo rm -rf /var/www/html/*",
            "sudo git clone https://github.com/VikeshBaid/multicloud.git /var/www/html/",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
        ]
    }
}

resource "aws_s3_bucket" "images" {
    depends_on = [
        aws_efs_mount_target.alpha
    ]

    bucket = "image-storage-tf1"
    acl = "public-read"
    tags = {
        Name = "image_bucket"
    }
}

resource "null_resource" "clone_image" {
    provisioner "local-exec" {
        command = "git clone https://github.com/VikeshBaid/images.git images"
    }

    provisioner "local-exec" {
        when = destroy
        command = "rm -rf images"    
    }
}

resource "aws_s3_bucket_object" "object" {
    depends_on = [
        aws_s3_bucket.images,
        null_resource.clone_image
    ]

    bucket = aws_s3_bucket.images.id
    key = "terraform_image.jpg"
    content_type = "image/jpg"
    acl = "public-read"
    source = "images/Terraform-main-image.jpg"
}

resource "aws_cloudfront_origin_access_identity" "access" {
    comment = "used by cloudfront to access origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    depends_on = [
        aws_instance.webserver,
        aws_s3_bucket_object.object,
        aws_cloudfront_origin_access_identity.access
    ]

    origin {
        domain_name = aws_s3_bucket.images.bucket_domain_name
        origin_id = "S3-${aws_s3_bucket.images.id}"

        s3_origin_config {
            origin_access_identity = aws_cloudfront_origin_access_identity.access.cloudfront_access_identity_path
        }
    }

    enabled = true
    is_ipv6_enabled = true

    default_cache_behavior {
        allowed_methods = ["GET", "HEAD"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.images.id}"
    
    forwarded_values {
        query_string = false

        cookies {
            forward = "none"
        }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

resource "null_resource" "entry_index_php" {
    depends_on = [
        aws_cloudfront_distribution.s3_distribution
    ]

    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = tls_private_key.this.private_key_pem
        host = aws_instance.webserver.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "sudo su << EOF",
            "echo \"<html>\" >> /var/www/html/index.php",
            "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key}'>\" >> /var/www/html/index.php",
            "echo \"</html>\" >> /var/www/html/index.php",
            "EOF"
        ]    
    }
}

output "cfront" {
    value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "Public_IP_of_EC2" {
    value = aws_instance.webserver.public_ip
}

resource "null_resource" "launch" {
    depends_on = [
        aws_cloudfront_distribution.s3_distribution
    ]

    provisioner "local-exec" {
        command = "firefox ${aws_instance.webserver.public_ip}"    
    }
}