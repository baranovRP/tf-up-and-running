output "public_ip" {
  value       = aws_instance.tf_ami.public_ip
  description = "The public IP address of the web server"
}
