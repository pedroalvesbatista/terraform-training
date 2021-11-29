terraform {
   required_providers {
      aws = { 
        source  = "hashicorp/aws"
  	     version = "~>3.8.0"
      }
   }
   
   required_version = "0.15.4"
}

provider "aws" {
   region = "sa-east-1"
   profile = "default"
} 

# Creates an instance for Rocky Linux 8   	
resource "aws_instance" "example" {
   ami 		              = "ami-0ab5e8fd80db76070"
   instance_type          = "t2.micro"
   vpc_security_group_ids = [aws_security_group.instance.id]

   user_data = "${file("hello.sh")}"
    	
   tags = {
     Name = "terraform-example"
   }
}
# Creates a security group
resource "aws_security_group" "instance" {
   name = "terraform-example-instance"
   
   ingress {
     from_port   = 8080
     to_port     = 8080
     protocol    = "tcp"	      
     cidr_blocks = ["0.0.0.0/0"]
   }
}

# Create variable to http port
variable "server_port" {
   description = "The port the server will use for HTTP requests"
   type        = number
   default     = 8080
  
}

# Fetches the public IP from instance
output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}

# Creates a launch configuration for ASG
resource "aws_launch_configuration" "example" {
   image_id        = "ami-0ab5e8fd80db76070"
   instance_type   = "t2.micro" 
   security_groups = [aws_security_group.instance.id]

   lifecycle {
     create_before_destroy = true
   }
  
}

# Create auto scaling group
resource "aws_autoscaling_group" "example" {
   launch_configuration = aws_launch_configuration.example.name
   vpc_zone_identifier = data.aws_subnet_ids.default.ids

   target_groups_arns = [aws_lb_target_group.asg.arn]
   health_check_type  = "ELB"

   min_size = 2
   max_size = 10

   tag {
      key                 = "Name"
      value               = "terraform-asg-example"
      propagate_at_launch = true
   }
}

# Create a load balancer
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]

  
}

# Create listener for the load balancer
resource "aws_lb_listener" "http" {
   load_balancer_arn = aws_lb.example.arn
   port              = 80
   protocol          = "HTTP"

   #By default, return a simple 404 page
   default_action {
     type = "fixed-response"

     fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code  = 404
     }
   }
}

# Create security group for the load balancer
resource "aws_security_group" "alb" {
   name = "terraform-example-alb"

   # Allow inbound HTTP requests
   ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] 
   }

   # Allow outbound HTTP requests
   ingress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"] 
   }
  
}

# Create targe group 
resource "aws_lb_target_group" "asg" {
   name     = "terraform-asg-example"
   port     = var.server_port
   protocol = "HTTP" 
   vpc_id   = data.aws_vpc.default.id

   health_check {
     path                = "/"
     protocol            = "HTTP"
     matcher             = "200"
     interval            = 15
     timeout             = 3
     healthy_threshold   = 2
     unhealthy_threshold = 2
   }
  
}

# Create load balancer listener rule
resource "aws_lb_listener_rule" "asg" {
   listener_arn = aws_lb_listener.http.arn
   priority     = 100

   condition {
      field = "path-pattern"
      value = ["*"]
   }

   action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.asg.arn
   }
  
}