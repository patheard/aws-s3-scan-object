#
# Lambda function triggered bo S3 object create
# 
module "s3_scan_object" {
  source = "github.com/cds-snc/terraform-modules?ref=v2.0.5//lambda"

  name      = "s3-scan-object"
  image_uri = "${aws_ecr_repository.s3_scan_object.repository_url}:latest"
  ecr_arn   = aws_ecr_repository.s3_scan_object.arn
  memory    = 1024
  timeout   = 60

  reserved_concurrent_executions = 10

  environment_variables = {
    AWS_ACCOUNT_ID                = local.account_id
    SCAN_FILES_URL                = var.scan_files_url
    SCAN_FILES_API_KEY_PARAM_NAME = aws_ssm_parameter.scan_files_api_key.name
    SNS_SCAN_COMPLETE_TOPIC_ARN   = aws_sns_topic.scan_complete.arn
  }

  policies = [
    data.aws_iam_policy_document.s3_scan_object.json
  ]

  billing_tag_value = "Operations"
}

#
# Lambda IAM policies
#
data "aws_iam_policy_document" "s3_scan_object" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [
      aws_ssm_parameter.scan_files_api_key.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObjectTagging",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      module.upload_bucket.s3_bucket_arn,
      "${module.upload_bucket.s3_bucket_arn}/*",
    ]
  }
}

#
# Lambda Docker image
#
resource "aws_ecr_repository" "s3_scan_object" {
  name                 = "s3-scan-object"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "s3_scan_object_exire_untagged" {
  repository = aws_ecr_repository.s3_scan_object.name
  policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Expire images older than 14 days",
        "selection" : {
          "tagStatus" : "untagged",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : 14
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}
