###
provider "aws" {
  region  = "eu-west-2"
  profile = "ora2postgres"
  version = "~> 2.0"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_launch_configuration" "tf_ami" {
  image_id        = "ami-01a6e31ac994bbc09"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_dmz.id]

  user_data = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_cluster" {
  launch_configuration   = aws_launch_configuration.tf_ami.id
  vpc_zone_identifier    = data.aws_subnet_ids.default.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "tf-WebServer"
  }
}

resource "aws_security_group" "web_dmz" {
  name = "tf-web-dmz"

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
