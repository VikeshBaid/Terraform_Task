# Terraform Task

## Task 1

In this task, I have created a EC2 Instance, Key Pair, and Security Group for EC2 Instance. The security group only allow ssh and http connction to the EC2 Instance. A null instance is also created whch is used to congifure the EC2 Instance to run webserver. An external EBS volume is also attached to EC2 Instance. This will works as Persistent Storage, data present in this EBS volume will not be deleted after Instance is deleted or crashed. A S3-Bucket is created which will store static file. To use this image in our webpage I am using CloudFront. Cloud Front provides a universl url for the image.

### AWS services used in Task 1
1. EC2 Instance
2. External EBS Volumes (For Persistent Storage, Sub Service of EC2 Instance)
3. Security Group (Sub Service of EC2 Instance)
4. Key-Pair (Sub Service of EC2 Instance)
5. S3 bucket
6. CloudFront

## Task 2

In this task, I have created a EC2 Instance, Key Pair, and Security Group for EC2 Instance. The security group only allow ssh and http connction to the EC2 Instance. A null instance is also created whch is used to congifure the EC2 Instance to run webserver. An external EFS storage (uses NFS protocol) is also attached to EC2 Instance. This will works as Persistent Storage, data present in this EFS storage will not be deleted after Instance is deleted or crashed. A S3-Bucket is created which will store static file. To use this image in our webpage I am using CloudFront. Cloud Front provides a universl url for the image. 

### AWS services used in Task 1
1. EC2 Instance
2. External EFS Storage (For Persistent Storage)
3. Security Group (Sub Service of EC2 Instance)
4. Key-Pair (Sub Service of EC2 Instance)
5. S3 bucket
6. CloudFront

## Task 3

In this task, I have created two EC2 instance (one for WordPress and one for MySQL Server), one Key-Pair and two Security Groups (one for Worpress Instance and one for MySQL Instance). I have added Security Rules for MySQL Instance which helps to connect to it using ssh protocol on port 22 and to connect to MySQL Server on port 3306. The source for 3306 port is Security Group of WordPress, which indicates that if any instance have WordPress Security Group attach to it can send and receive data to and from MySQL server. The internal connection between WordPress and MySQL is done using Private IP.

Both the instances are created in a VPC created by me. In this VPC two subnets are present. One is Public Subnet which allow instances launched in it to go to the Internet and one Private Subnet which won't allow instances launched in it to connect to Internet (outside world). In Public Subnet WordPress instance is running and in Private Subnet MySQL Server Instance is running.

I have used a raw image while creating MySQL Server Instance, which doesn't have MySQL Server running in it. That's why it can't be connected to WordPress Instance. I also can't configure the instance to run MySQL Server as there is no way by which we can reach to MySQL Instance.

In WordPress instance, I have used docker image to run WordPress. It reduces the time to configure the WordPress. First, I configured yum repository for Docker. Then ins
tall it and then run the docker service permanently. Then I run a docker container for WordPress. It is accessible from the outside world as i have exposed the port 80 (on which WordPress is running) and done patting on port 80.

Both Exposing a port and patting are the concepts of Docker.


### AWS service used in Task 3
1. VPC
2. EC2 Instance
3. Security Groups (Sub Service of EC2 Instance)
4. Key-Pair (Sub Service of EC2 Instance)
5. Internet Gateway (Sub Service of VPC)
6. Route Table (Sub service of VPC)

### Extra software  needed in Task 3
1. Docker

## Task 4

In this task, I have created three EC2 instance (one for WordPress, one for MySQL Server, one for bastion host), one Key-Pair and four Security Groups (one for Worpress Instance, one for MySQL Instance to connect with WordPress Instance, one for MySQL Instance to connect with Bastion Host and one for Bastion host). I have added Security Rules for MySQL Instance which helps to connect to it using ssh protocol on port 22 and to connect to MySQL Server on port 3306.I have also created Security Rules for connecting MySQL with Bastion host to configure MySQL Server. The source for 3306 port is Security Group of WordPress, which indicates that if any instance have WordPress Security Group attach to it can send and receive data to and from MySQL server. The source for 22 port is Security Group of Bastion Host, which allows Bastion Host to access the MySQL Instance. The internal connection between WordPress and MySQL is done using Private IP.

Both the instances are created in a VPC created by me. In this VPC two subnets are present. One is Public Subnet which allow instances launched in it to go to the Internet and one Private Subnet which won't allow instances launched in it to connect to Internet (outside world). In Public Subnet WordPress instance is running and in Private Subnet MySQL Server Instance is running.

I have used a raw image while creating MySQL Server Instance, which doesn't have MySQL Server running in it. Now I will configure the MySQL instance using Bastion Host. As I have added Security Group of Bastion Host as source to 22 port, I can use ssh protocol to get into the MySQL Instance. Now I congifured yum repository for Docker. Then install the Docker and then run the docker container which launched MySQL Server inside it. As I have exposed the port 3306 and also done patting on 3306 whcile creating docker contianer. Now I can access the MySQL server running at 3306 using MySQL Instance Private IP to connect it with the WordPress site.

In WordPress instance, I have used docker image to run WordPress. It reduces the time to configure the WordPress. First, I configured yum repository for Docker. Then ins
tall it and then run the docker service permanently. Then I run a docker container for WordPress. It is accessible from the outside world as i have exposed the port 80 (on which WordPress is running) and done patting on port 80.

Both Exposing a port and patting are the concepts of Docker. 

I have also used NAT Gateway, using which we can connect the Instances running in Private Subnet to the Internet. That's why docker can be downloaded on MySQL Instance as it uses the yum repository to fetch the code of docker from the Internet. Elastic IP is used in NAT Gateway. 

### AWS service used in Task 3
1. VPC
2. EC2 Instance
3. Security Groups (Sub Service of EC2 Instance)
4. Key-Pair (Sub Service of EC2 Instance)
5. Internet Gateway (Sub Service of VPC)
6. Route Table (Sub service of VPC)
7. NAT Gateway (Sub Service of VPC)
8. Elastic IP (Sub Service of VPC)

### Extra software  needed in Task 3
1. Docker







