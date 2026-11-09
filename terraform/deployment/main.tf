module "account_a" {
  source    = "../modules/account-a"
  providers = { aws = aws.account_a, tls = tls, local = local }

  account_a_id       = data.aws_caller_identity.account_a.account_id
  aws_region         = var.aws_region
  name_prefix        = var.name_prefix
  owner              = var.owner
  user_pgp_keys      = var.user_pgp_keys
  role_c_arn         = module.account_b.role_c_arn
  ami_id             = var.ami_id
  instances          = var.instances
  keypair_output_dir = abspath("${path.root}/keypairs-output")
}

module "account_b" {
  source    = "../modules/account-b"
  providers = { aws = aws.account_b }

  account_b_id = data.aws_caller_identity.account_b.account_id
  aws_region   = var.aws_region
  name_prefix  = var.name_prefix
  owner        = var.owner
  role_b_arn   = module.account_a.role_b_arn
}
