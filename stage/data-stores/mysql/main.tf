###
provider "aws" {
  version                 = "~> 2.0"
  region                  = "eu-west-2"
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "ora2postgres"
}

terraform {
  required_version = "~> v0.12"

  backend "s3" {
    bucket = "tf-state-eu-west-2-rnbv"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "tf-locks-eu-west-2-rnbv"
    encrypt        = true
  }
}

resource "aws_db_instance" "tf_db" {
  skip_final_snapshot = true
  identifier_prefix = "tf-eu-west-2-rnbv"
  engine            = "mysql"
  allocated_storage = 10
  instance_class    = "db.t2.micro"
  name              = "tfmysql"
  username          = "admin"
  password          = var.db_password
}
