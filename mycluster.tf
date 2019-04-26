provider "aws" {
  access_key = "AKIAJMTPO4LHPMTQNJEA"
  secret_key = "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"
  region     = "us-east-2"
}

terraform {  
    backend "s3" {
        bucket     = "opiqueras-bucket"
        key        = "terraform.tfstate"    
        region     = "us-east-2"  
         access_key = "AKIAJMTPO4LHPMTQNJEA"
         secret_key = "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"

    }
}


data "aws_availability_zones" "all" {}


variable "server_from_port" {
  description = "The port the server will open low range"
}

variable "server_to_port" {
  description = "The port the server will open high range"
}



#resource "aws_instance" "example" {
#  ami                    = "ami-0653e888ec96eab9b"
#  instance_type          = "t2.micro"
#  key_name               = "my-first-kp"
#  vpc_security_group_ids = ["${aws_security_group.instance.id}"]
#
#  tags {
#     Name = "my-first-example"
#  }
#  user_data = <<-EOF
#              #!/bin/bash
#              echo "Hello, World" > index.html
#              nohup busybox httpd -f -p 8080 &
#              EOF
#}


#configuracion del grupo de segurdidad ip's que se pueden conectar y puertos que estan abiertos
resource "aws_security_group" "my-cluster-sg" {
  name = "my-cluster-sg"
  ingress {
    from_port   = "${var.server_from_port}"
    to_port     = "${var.server_to_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
     create_before_destroy = true
  }
}

#configuracion del grupo de segurdidad ip's que se pueden conectar y puertos que estan abiertos
# para el load balancers 
resource "aws_security_group" "my-lb-sec-group" {
  name = "my-lb-sec-group"

  egress {
    from_port    = 0
    to_port     = 0
    protocol    =  "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##configuracion de las maquinas que participan en el cluster
resource "aws_launch_configuration" "my-cluster_lc" {
  image_id               = "ami-0653e888ec96eab9b"
  instance_type          = "t2.micro"
  key_name               = "my-first-kp"
  security_groups        = ["${aws_security_group.my-cluster-sg.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

#Configuracion del grupo y parametros de escalamiento
resource "aws_autoscaling_group" "my-cluster-as-group" {
  launch_configuration = "${aws_launch_configuration.my-cluster_lc.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
  min_size             = 2
  max_size             = 4

  load_balancers    = ["${aws_elb.my-cluster-lb.name}"]
  health_check_type = "ELB"
 
  tag {
    key                 = "Name"
    value               = "my-cluster-as-group"
    propagate_at_launch = true
  }
}

#Definicion del load balancer
resource "aws_elb" "my-cluster-lb" {
  name               = "my-cluster-lb"
  security_groups    = ["${aws_security_group.my-lb-sec-group.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target = "HTTP:${var.server_to_port}/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_to_port}"
    instance_protocol = "http"
  }
}

output "elb_dns_name" {
  value = "${aws_elb.my-cluster-lb.dns_name}"
}


#my-lb-sec-group

#resource "aws_eip" "ip" {
#  instance = "${aws_instance.example.id}"
#}
