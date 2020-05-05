###
terraform {
  required_version = "~> v0.12"

  backend "s3" {
    bucket = "tf-state-eu-west-2-rnbv"
    key    = "stage/services/webserver-cluster/terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "tf-locks-eu-west-2-rnbv"
    encrypt        = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "eu-west-2"
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    server_port = local.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}

resource "aws_launch_configuration" "tf_ami" {
  image_id        = "ami-01a6e31ac994bbc09"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.web_dmz.id]

  user_data = data.template_file.user_data.rendered

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_cluster" {
  launch_configuration = aws_launch_configuration.tf_ami.id
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "tf-WebServer"
  }
}

resource "aws_security_group" "web_dmz" {
  name = "${var.cluster_name}-web-dmz"
}

resource "aws_security_group_rule" "allow_ssh_instance" {
  type              = "ingress"
  security_group_id = aws_security_group.web_dmz.id

  from_port   = 22
  to_port     = 22
  protocol    = local.protocols.tcp
  cidr_blocks = [local.cidrblocks.cidrblock_all_ipv4]
}

resource "aws_security_group_rule" "allow_http_inbound_instance" {
  type              = "ingress"
  security_group_id = aws_security_group.web_dmz.id

  from_port        = local.server_port
  to_port          = local.server_port
  protocol         = local.protocols.tcp
  cidr_blocks      = [local.cidrblocks.cidrblock_all_ipv4]
  ipv6_cidr_blocks = [local.cidrblocks.cidrblock_all_ipv6]
}

resource "aws_security_group_rule" "allow_all_outbound_instance" {
  type              = "egress"
  security_group_id = aws_security_group.web_dmz.id

  from_port        = 0
  to_port          = 0
  protocol         = -1
  cidr_blocks      = [local.cidrblocks.cidrblock_all_ipv4]
  ipv6_cidr_blocks = [local.cidrblocks.cidrblock_all_ipv6]

}

resource "aws_lb" "tf_balancer" {
  name = "${var.cluster_name}-tf-balancer"

  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.tf_balancer.arn
  port              = local.server_port
  protocol          = local.protocols.http

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port        = local.server_port
  to_port          = local.server_port
  protocol         = local.protocols.tcp
  cidr_blocks      = [local.cidrblocks.cidrblock_all_ipv4]
  ipv6_cidr_blocks = [local.cidrblocks.cidrblock_all_ipv6]
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port        = 0
  to_port          = 0
  protocol         = -1
  cidr_blocks      = [local.cidrblocks.cidrblock_all_ipv4]
  ipv6_cidr_blocks = [local.cidrblocks.cidrblock_all_ipv6]
}

resource "aws_lb_target_group" "asg" {
  name = "${var.cluster_name}-asg"

  port     = local.server_port
  protocol = local.protocols.http
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = local.protocols.http
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
