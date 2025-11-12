variable "cert_validity_days" {
  description = "Number of days certificates are valid for"
  type        = number
  default     = 365
}

variable "cert_key_size" {
  description = "RSA key size for certificates"
  type        = number
  default     = 4096
}

variable "cert_output_path" {
  description = "Base path for certificate output"
  type        = string
  default     = "../../certs"
}
