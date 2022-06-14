#
# SNS topic that receives scan results
#
resource "aws_sns_topic" "scan_complete" {
  name              = "s3-object-scan-complete"
  kms_master_key_id = aws_kms_key.sns_lambda.id
}

resource "aws_sns_topic_subscription" "scan_complete" {
  topic_arn = aws_sns_topic.scan_complete.arn
  protocol  = "lambda"
  endpoint  = module.s3_scan_object.function_arn
}

#
# KMS: SNS topic encryption keys
# A CMK is required so we can apply a policy that allows Lambda to use it
resource "aws_kms_key" "sns_lambda" {
  description = "KMS key for Lambda SNS topic"
  policy      = data.aws_iam_policy_document.sns_lambda.json
}

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "sns_lambda" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    # Publish to the SNS topic
    # principals {
    #   type        = "AWS"
    #   identifiers = ["arn:aws:iam::123456789012:role/SNSScanObjectComplete"]
    # }    
  }
}

resource "aws_lambda_permission" "scan_complete" {
  statement_id  = "AllowExecutionFromSNSScanComplete"
  action        = "lambda:InvokeFunction"
  function_name = module.s3_scan_object.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.scan_complete.arn
}
