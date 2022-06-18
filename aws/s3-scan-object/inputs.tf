variable "scan_files_api_key" {
  description = "Scan Files API key"
  sensitive   = true
  type        = string
}

variable "scan_files_role_arn" {
  description = "Scan Files lambda execution role ARN"
  sensitive   = true
  type        = string
}

variable "scan_files_url" {
  description = "Scan Files URL"
  default     = "https://scan-files.alpha.canada.ca"
  type        = string
}