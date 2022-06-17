#
# Upload bucket
#
resource "random_pet" "upload_bucket" {}
module "upload_bucket" {
  source            = "github.com/cds-snc/terraform-modules?ref=v2.0.5//S3"
  bucket_name       = "s3-scan-object-upload-bucket-${random_pet.upload_bucket.id}"
  billing_tag_value = "Operations"

  versioning = {
    enabled = true
  }
}

#
# Bucket policy
#
resource "aws_s3_bucket_policy" "upload_bucket" {
  bucket = module.upload_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.upload_bucket.json
}

data "aws_iam_policy_document" "upload_bucket" {
  source_policy_documents = [
    data.aws_iam_policy_document.limit_tagging.json
  ]
}

#
# Only allow the lambda to add object tags
# to upload bucket
#
data "aws_iam_policy_document" "limit_tagging" {
  statement {
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:DeleteObjectTagging",
      "s3:DeleteObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      "${module.upload_bucket.s3_bucket_arn}/*"
    ]
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values   = [local.lambda_role_arn]
    }
  }

  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.lambda_role_arn]
    }
    actions = [
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      "${module.upload_bucket.s3_bucket_arn}/*"
    ]
  }
}

#
# Trigger scan when file is created
#
resource "aws_lambda_permission" "s3_execute" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  principal     = "s3.amazonaws.com"
  function_name = module.s3_scan_object.function_name
  source_arn    = module.upload_bucket.s3_bucket_arn
}

resource "aws_s3_bucket_notification" "s3_scan_object" {
  bucket = module.upload_bucket.s3_bucket_id

  lambda_function {
    lambda_function_arn = module.s3_scan_object.function_arn
    id                  = "ScanObjectCreated"
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_execute]
}
