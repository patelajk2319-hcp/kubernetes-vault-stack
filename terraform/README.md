# Terraform Infrastructure for Vault Stack

This directory contains Terraform configuration to deploy the Kubernetes Vault Stack infrastructure.

## What Gets Deployed

Terraform manages:
- ✅ Kubernetes namespace
- ✅ TLS certificate generation (CA + Vault certs)
- ✅ Kubernetes secrets (certificates, Vault license)
- ✅ Helm chart deployment (Vault stack)
- ✅ ECK operator for Elasticsearch

Scripts still handle:
- `.env` file creation
- Port forwarding
- Vault init/unseal
- Status and info commands

## Prerequisites

1. **Terraform** (>= 1.5.0)
   ```bash
   brew install terraform
   ```

2. **Kubernetes cluster** access (kubeconfig configured)

3. **Vault Enterprise license** at `licenses/vault-enterprise/license.lic`

## Directory Structure

```
terraform/
├── main.tf                    # Main configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── providers.tf               # Provider configuration
├── modules/
│   ├── certificates/          # TLS certificate generation
│   ├── secrets/               # Kubernetes secrets
│   └── helm-releases/         # Helm chart deployments
└── README.md                  # This file
```

## Usage

### Using Taskfile (Recommended)

```bash
# Deploy stack
task up

# Destroy stack
task clean

# View Terraform plan
cd terraform && terraform plan
```

### Direct Terraform Commands

```bash
cd terraform

# Initialise Terraform
terraform init

# Review changes
terraform plan

# Deploy infrastructure
terraform apply

# Destroy infrastructure
terraform destroy
```

## Modules

### certificates

Generates TLS certificates using the `tls` provider:
- Self-signed CA certificate
- Vault server certificate signed by CA
- Includes SANs for all Vault pod DNS names

### secrets

Creates Kubernetes secrets:
- `vault-certs` - Vault TLS certificates
- `elasticsearch-certs` - Elasticsearch TLS certificates
- `vault-license` - Vault Enterprise license (base64 encoded)

### helm-releases

Deploys Helm charts:
- Vault stack (main chart with all services)
- ECK operator (for Elasticsearch)

## Variables

Key variables (see `variables.tf` for full list):

| Variable | Default | Description |
|----------|---------|-------------|
| `namespace` | `vault-stack` | Kubernetes namespace |
| `release_name` | `vault-stack` | Helm release name |
| `chart_path` | `../helm-chart/vault-stack` | Path to Helm chart |
| `vault_license_file` | `../licenses/vault-enterprise/license.lic` | Vault license file path |
| `cert_validity_hours` | `8760` | Certificate validity (1 year) |

## Outputs

After deployment, Terraform outputs:
- Namespace name
- Helm release statuses
- Secret names
- Next steps instructions

## State Management

**Important:** Terraform state contains sensitive data (certificates, license).

For production:
- Use remote state backend (S3, Terraform Cloud, etc.)
- Enable state encryption
- Configure state locking

Example remote backend:
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "vault-stack/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Migration from Shell Scripts

The legacy shell script workflow is still available via:
```bash
task up-legacy
task clean-legacy
```

Differences:
- Terraform generates certificates instead of `00_create-certs.sh`
- Terraform creates secrets instead of `01_secrets_from_certs.sh`
- Terraform deploys Helm charts instead of `10_deploy_helm.sh` and `11_deploy_elk.sh`
- `.env` creation and port-forwarding still use scripts

## Troubleshooting

### License file not found
```
Error: Error in function call
│ Call to function "file" failed: no file exists at ../licenses/vault-enterprise/license.lic
```

**Solution:** Create the license file and add your Vault Enterprise license key.

### Helm repository errors
```
Error: Failed to download chart
```

**Solution:** Add Helm repositories manually:
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add elastic https://helm.elastic.co
helm repo update
```

### Namespace already exists
Terraform will adopt the existing namespace if it matches the configuration.

### ECK CRDs not ready
The configuration includes a 30-second wait after ECK operator deployment. If Elasticsearch fails to deploy, try running `terraform apply` again.

## Next Steps After Deployment

1. Initialise Vault: `task init`
2. Unseal Vault: `task unseal`
3. View access info: `task info`
