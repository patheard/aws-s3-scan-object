variable "scan_files_api_key" {
  description = "Scan Files API key"
  sensitive   = true
  type        = string
}

variable "scan_files_url" {
  description = "Scan Files URL"
  default     = "https://scan-files.alpha.canada.ca"
  type        = string
}