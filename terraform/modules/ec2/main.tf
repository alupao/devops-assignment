resource "aws_instance" "unprotected" {
  for_each = { for name, instance in var.instances : name => instance if !instance.protected }

  ami                         = var.ami_id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false
  instance_type               = each.value.instance_type
  key_name                    = each.value.key_name

  root_block_device {
    encrypted   = true
    volume_type = each.value.root_volume_type
    volume_size = each.value.root_volume_size
    iops        = each.value.root_iops
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }
}

resource "aws_instance" "protected" {
  for_each = { for name, instance in var.instances : name => instance if instance.protected }

  ami                         = var.ami_id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false
  instance_type               = each.value.instance_type
  key_name                    = each.value.key_name

  root_block_device {
    encrypted   = true
    volume_type = each.value.root_volume_type
    volume_size = each.value.root_volume_size
    iops        = each.value.root_iops
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}
