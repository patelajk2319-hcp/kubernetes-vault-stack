# ============================================================================
# Local Variables
# ============================================================================

# Split the YAML file into separate resources (filter out empty strings)
locals {
  webapp_yaml_raw  = split("---", file("${path.module}/../../k8s/elk-dynamic/00_webapp-deployment.yaml"))
  webapp_yaml_docs = [for doc in local.webapp_yaml_raw : trimspace(doc) if trimspace(doc) != ""]
}
