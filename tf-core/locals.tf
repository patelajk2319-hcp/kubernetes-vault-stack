# Local variables
locals {
  vault_license     = trimspace(file(var.vault_license_file))
}
