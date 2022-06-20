resource "aws_iam_role" "scan_files" {
  name               = "ScanFilesGetObjects"
  assume_role_policy = data.aws_iam_policy_document.scan_files_assume_role.json
}

data "aws_iam_policy_document" "scan_files_assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.scan_files_role_arn]
    }
  }
}

resource "aws_iam_policy" "scan_files" {
  name   = "ScanFilesGetObjects"
  path   = "/"
  policy = data.aws_iam_policy_document.scan_files.json
}

resource "aws_iam_role_policy_attachment" "scan_files" {
  role       = aws_iam_role.scan_files.name
  policy_arn = aws_iam_policy.scan_files.arn
}

data "aws_iam_policy_document" "scan_files" {

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionTagging"
    ]
    resources = [
      module.upload_bucket.s3_bucket_arn,
      "${module.upload_bucket.s3_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.scan_complete.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*"
    ]
    resources = [
      aws_kms_key.sns_lambda.arn
    ]
  }
}


