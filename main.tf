###
provider "aws" {
  region  = "eu-west-2"
  profile = "ora2postgres"
  version = "~> 2.0"
}

resource "aws_instance" "tf_ami" {
  ami                    = "ami-01a6e31ac994bbc09"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_dmz.id]

  user_data = file("user_data.sh")

  tags = {
    Name = "tf-WebServer"
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
