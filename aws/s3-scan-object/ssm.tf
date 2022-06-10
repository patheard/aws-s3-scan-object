resource "aws_ssm_parameter" "scan_files_api_key" {
  name  = "/scan-files/api-key"
  type  = "SecureString"
  value = var.scan_files_api_key
}
