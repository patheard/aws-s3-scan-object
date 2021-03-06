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

resource "aws_sns_topic_policy" "scan_complete" {
  arn    = aws_sns_topic.scan_complete.arn
  policy = data.aws_iam_policy_document.scan_complete.json
}

data "aws_iam_policy_document" "scan_complete" {
  statement {
    sid       = "AccountOwnerFullAdmin"
    effect    = "Allow"
    resources = [aws_sns_topic.scan_complete.arn]
    # SNS policy does not support "sns:*" actions wildcard
    actions = [
      "sns:AddPermission",
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
      "sns:Receive",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowScanFilesPublish"
    effect    = "Allow"
    resources = [aws_sns_topic.scan_complete.arn]
    actions   = ["sns:Publish"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.scan_files.arn]
    }
  }
}

#
# KMS: SNS topic encryption keys
# A CMK is required so we can apply a policy that allows Lambda to use it
resource "aws_kms_key" "sns_lambda" {
  description = "KMS key for Lambda SNS topic"
  policy      = data.aws_iam_policy_document.sns_lambda.json
}

data "aws_iam_policy_document" "sns_lambda" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
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

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.scan_files.arn]
    }
  }
}

resource "aws_lambda_permission" "scan_complete" {
  statement_id  = "AllowExecutionFromSNSScanComplete"
  action        = "lambda:InvokeFunction"
  function_name = module.s3_scan_object.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.scan_complete.arn
}
