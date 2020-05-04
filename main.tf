###
provider "aws" {
  region = "eu-west-2"
}

resource "aws_instance" "tf_ubuntu" {
  ami = "ami-0917237b4e71c5759"
  instance_type = "t2.micro"

tags = {
  Name = "tf-WebServer"
}
}
