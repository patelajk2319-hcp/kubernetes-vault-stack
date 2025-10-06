# Kubernetes Services Module

resource "kubernetes_service" "vault_nodeport" {
  metadata {
    name      = "vault-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "vault"
      "app.kubernetes.io/instance" = "vault-stack"
    }

    port {
      name        = "http"
      port        = 8200
      target_port = 8200
      node_port   = 30200
    }

    port {
      name        = "https-internal"
      port        = 8201
      target_port = 8201
      node_port   = 30201
    }
  }
}

resource "kubernetes_service" "grafana_nodeport" {
  metadata {
    name      = "grafana-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "grafana"
      "app.kubernetes.io/instance" = "vault-stack-grafana"
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      node_port   = 30300
    }
  }
}

resource "kubernetes_service" "prometheus_nodeport" {
  metadata {
    name      = "prometheus-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "prometheus"
      "app.kubernetes.io/instance" = "vault-stack-prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
      node_port   = 30090
    }
  }
}

resource "kubernetes_service" "kibana_nodeport" {
  metadata {
    name      = "kibana-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "kibana.k8s.elastic.co/name" = "kibana"
    }

    port {
      name        = "http"
      port        = 5601
      target_port = 5601
      node_port   = 30601
    }
  }
}

resource "kubernetes_service" "elasticsearch_nodeport" {
  metadata {
    name      = "elasticsearch-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "elasticsearch.k8s.elastic.co/cluster-name" = "elasticsearch"
    }

    port {
      name        = "https"
      port        = 9200
      target_port = 9200
      node_port   = 30920
    }
  }
}
