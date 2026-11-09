resource "aws_iam_role" "role_a" {
  provider = aws

  name        = "roleA"
  description = "Administrative API access except IAM; assumed by named MFA-authenticated human users."
  tags        = local.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = [for name in local.human_users : aws_iam_user.account_a[name].arn] }
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })
}

resource "aws_iam_role_policy" "role_a_permissions" {
  provider = aws

  name = "roleA-admin-except-iam"
  role = aws_iam_role.role_a.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "*", Resource = "*" },
      { Effect = "Deny", Action = "iam:*", Resource = "*" },
    ]
  })
}

resource "aws_iam_role" "role_b" {
  provider = aws

  name        = "roleB"
  description = "Cross-account entry role; its only permission is assuming Account B roleC."
  tags        = local.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = aws_iam_user.account_a["engine"].arn }
      },
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = [for name in local.human_users : aws_iam_user.account_a[name].arn] }
        Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
      },
    ]
  })
}

resource "aws_iam_role_policy" "role_b_permissions" {
  provider = aws

  name = "roleB-assume-roleC-only"
  role = aws_iam_role.role_b.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = var.role_c_arn
    }]
  })
}
