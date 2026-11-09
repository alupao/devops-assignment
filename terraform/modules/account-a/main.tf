data "aws_ssm_parameter" "amazon_linux" {
  count           = var.ami_id == null ? 1 : 0
  name            = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  with_decryption = false
}

data "aws_ami" "selected" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [var.ami_id != null ? var.ami_id : nonsensitive(data.aws_ssm_parameter.amazon_linux[0].value)]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

module "ec2" {
  source             = "../ec2"
  ami_id             = data.aws_ami.selected.id
  subnet_id          = aws_subnet.assignment.id
  security_group_ids = [aws_security_group.assignment.id]
  instances          = { for name, instance in var.instances : name => merge(instance, { key_name = aws_key_pair.instance[name].key_name }) }
}
