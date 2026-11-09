resource "tls_private_key" "instance" {
  for_each  = var.instances
  algorithm = "ED25519"
}

resource "aws_key_pair" "instance" {
  for_each   = var.instances
  key_name   = "${var.name_prefix}-${each.key}"
  public_key = tls_private_key.instance[each.key].public_key_openssh
  tags       = merge(local.tags, { Name = "${var.name_prefix}-${each.key}" })
}

resource "local_sensitive_file" "private_key" {
  for_each             = var.instances
  content              = tls_private_key.instance[each.key].private_key_openssh
  filename             = "${var.keypair_output_dir}/${each.key}.pem"
  file_permission      = "0600"
  directory_permission = "0700"
}

resource "local_file" "public_key" {
  for_each             = var.instances
  content              = tls_private_key.instance[each.key].public_key_openssh
  filename             = "${var.keypair_output_dir}/${each.key}.pub"
  file_permission      = "0600"
  directory_permission = "0700"
}
