output "instance_ids" {
  description = "Instance name to EC2 ID."
  value       = { for name, instance in merge(aws_instance.unprotected, aws_instance.protected) : name => instance.id }
}

output "private_ips" {
  description = "Instance name to private IP address."
  value       = { for name, instance in merge(aws_instance.unprotected, aws_instance.protected) : name => instance.private_ip }
}
