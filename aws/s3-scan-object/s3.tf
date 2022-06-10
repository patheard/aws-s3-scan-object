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
# Trigger scan when file is created
#
resource "aws_s3_bucket_notification" "s3_scan_object" {
  bucket = module.upload_bucket.s3_bucket_id

  lambda_function {
    id                  = "ScanObjectCreated"
    lambda_function_arn = module.s3_scan_object.function_arn
    events              = ["s3:ObjectCreated:*"]
  }
}
