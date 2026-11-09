data "aws_caller_identity" "account_a" {
  provider = aws.account_a
}

data "aws_caller_identity" "account_b" {
  provider = aws.account_b
}
