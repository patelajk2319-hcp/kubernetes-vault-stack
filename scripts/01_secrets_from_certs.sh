#!/bin/bash

# Create Kubernetes secrets from certificate files
# This script creates secrets for Elasticsearch and Kibana TLS certificates

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Generate certificates if not already present
if [ ! -d certs ]; then
  echo "No certs directory found"
  echo "Running certificate generation script..."
  ./scripts/00_create-certs.sh
fi

echo -e "${BLUE}Creating certificate secrets${NC}"

# Create Elasticsearch certificate secret
kubectl create secret generic elasticsearch-certs \
  --from-file=ca.crt=certs/ca/ca.crt \
  --from-file=elasticsearch.crt=certs/elasticsearch/elasticsearch.crt \
  --from-file=elasticsearch.key=certs/elasticsearch/elasticsearch.key \
  --from-file=fleet-server.crt=certs/fleet-server/fleet-server.crt \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Create Kibana certificate secret
kubectl create secret generic kibana-certs \
  --from-file=ca.crt=certs/ca/ca.crt \
  --from-file=kibana.crt=certs/kibana/kibana.crt \
  --from-file=kibana.key=certs/kibana/kibana.key \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo -e "${GREEN}Certificate secrets created${NC}"

# Create .env file if it doesn't exist (for Vault credentials only)
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo -e "${BLUE}Creating .env file${NC}"
  cat > "$ENV_FILE" <<EOF
# Vault address - required for Vault CLI commands
export VAULT_ADDR=http://127.0.0.1:8200

# Vault Enterprise license - required for Vault Enterprise features
export VAULT_LICENSE=02MV4UU43BK5HGYYTOJZWFQMTMNNEWU33JJ5CFU2SOIRATCWSEM52E26SNGRHFGMBQJZKFM22MKRBGQTLKIV2FS6SVPJHFIVJULJCGG52NGJMTISLJO5UVSM2WPJSEOOLULJMEUZTBK5IWST3JJEZFUR2FO5HEOTLZLJBTC22NNJVXUTCUJUYFU3KVORHGUWLXJZUTC3KNGJITKTRSKZWVSMSSNFNEIZ3JJRBUU4DCNZHDAWKXPBZVSWCSOBRDENLGMFLVC2KPNFEXCSLJO5UWCWCOPJSFOVTGMRDWY5C2KNETMSLKJF3U22SVORGUI23UJVCEMVKNKRITMTKUJE3E4VCJOVHGUY3YJZ5FCMCOKRVTIV3JJFZUS3SOGBMVQSRQLAZVE4DCK5KWST3JJF4U2RCJGFGFIQJVJRKEC6CWIRAXOT3KIF3U62SBO5LWSSLTJFWVMNDDI5WHSWKYKJYGEMRVMZSEO3DULJJUSNSJNJEXOTLKLF2E2RCJORGWU2CVJVCECNSNIRATMTKEIJQUS2LXNFSEOVTZMJLWY5KZLBJHAYRSGVTGIR3MORNFGSJWJFVES52NNJMXITKEJF2E22TIKVGUIQJWJVCECNSNIRBGCSLJO5UWGSCKOZNEQVTKMRBUSNSJNZNGQZCXPAYES2LXNFNG26DILIZU22KPNZZWSYSXHFVWIV3YNRRXSSJWK54UU5DEK54DAYKTGFVVS6JRPJMTERTTLJJUS42JNVSHMZDNKZ4WE3KGOVMTEVLUMNDTS43BK5HDKSLJO5UVSV2SGJMVONLKLJLVC5C2I5DDAWKTGF3WG3JZGBNFOTRQMFLTS5KMLBJHSWKXGV5FU3JZPFRFGSLTJFWUM23ENVDHKWJSKZVUYV2SNBSEORLUMNEEU5TEI5LGUZCHNR3GE2JROJNFQ23UMJLUM5KZK5SGYYSXKZ2WIQ2KMRTFQMB5FZAUS2ZPJFLCWVRQNQ2FUMTYGIZGEY3CLEZHG4THHFBGWNSJGVJHESLLKE3WSNDHHE2USWDVMU3UQK2ZGBDUW42SJJXFINDWOJCWSU2YJJAWU3JQOJWHCVSUNBFWYN3VM52UQ4DGIRNDCZCBNNRWCNDEKYYDGMZYKB3W2VTMMF3EUUBUOBFHQSKJHFCDMVKGJRKWCVSQNJVVOSTUMNCDM4DBNQ3G6T3GI5XEWMT2KBFUUUTNI5EFMM3FLJ3XCRTFFNXTO2ZPOMVUCVCONBIFUZ2TF5FVMWLHF5FSW3CHKB3UYN3KIJ4ESN2HJ5QWWNSVMFUWCSDPMVVTAUSUN43TERCRHU6Q

# Vault root token - dynamically generated during 'task init'
export VAULT_TOKEN=placeholder
EOF
  echo -e "${GREEN}.env file created${NC}"
fi
