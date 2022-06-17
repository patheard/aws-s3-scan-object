data "aws_caller_identity" "current" {}
locals {
  account_id      = data.aws_caller_identity.current.account_id
  lambda_role_arn = "arn:aws:iam::${local.account_id}:role/s3-scan-object"
}
