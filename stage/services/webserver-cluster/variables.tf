variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}

variable "cidrblocks" {
  type = map
  default = {
    cidrblock_all_ipv4 = "0.0.0.0/0"
    cidrblock_all_ipv6 = "::/0"
  }
}

variable "protocols" {
  type = map
  default = {
    tcp  = "tcp"
    http = "HTTP"
  }
}
