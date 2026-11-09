data "aws_partition" "current" {}

locals {
  human_users = ["alice", "bob"]
  group_members = {
    group1 = ["engine", "ci"]
    group2 = local.human_users
  }
  tags = {
    Environment = "assignment"
    Owner       = var.owner
  }
}

resource "aws_iam_user" "account_a" {
  provider = aws
  for_each = toset(concat(local.group_members.group1, local.human_users))

  name          = each.key
  force_destroy = false
  tags          = local.tags
}

resource "aws_iam_group" "access" {
  provider = aws
  for_each = local.group_members

  name = each.key
}

resource "aws_iam_group_membership" "access" {
  provider = aws
  for_each = local.group_members

  name  = "${each.key}-members"
  group = aws_iam_group.access[each.key].name
  users = [for name in each.value : aws_iam_user.account_a[name].name]
}

resource "aws_iam_access_key" "programmatic" {
  provider = aws
  for_each = aws_iam_user.account_a

  user    = each.value.name
  pgp_key = var.user_pgp_keys[each.key]
  status  = "Active"
}

resource "aws_iam_user_login_profile" "human" {
  provider = aws
  for_each = toset(local.human_users)

  user                    = aws_iam_user.account_a[each.key].name
  pgp_key                 = var.user_pgp_keys[each.key]
  password_length         = 24
  password_reset_required = true
}

resource "aws_iam_group_policy" "human_access" {
  provider = aws

  name  = "group2-role-access-and-password-change"
  group = aws_iam_group.access["group2"].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["sts:AssumeRole"]
        Resource  = [aws_iam_role.role_a.arn, aws_iam_role.role_b.arn]
        Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
      },
      {
        Effect   = "Allow"
        Action   = ["iam:ChangePassword"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.account_a_id}:user/$${aws:username}"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:GetAccountPasswordPolicy"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy" "engine_access" {
  provider = aws

  name = "engine-assume-roleB"
  user = aws_iam_user.account_a["engine"].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sts:AssumeRole"]
      Resource = aws_iam_role.role_b.arn
    }]
  })
}
