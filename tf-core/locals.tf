# Local variables
locals {
  vault_license     = trimspace(file(var.vault_license_file))
  vault_license_b64 = base64encode(local.vault_license)
}
