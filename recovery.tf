# ============================================
# Recovery Configuration Resources
# ============================================
# Credentials for reading the source object store the cluster is bootstrapped from
# (spec.bootstrap.recovery). Only created when var.recovery.credentials_secret is
# empty; otherwise an existing secret is referenced, e.g. the backup credentials
# secret of the source cluster when it lives in the same namespace.

resource "kubernetes_secret_v1" "recovery_credentials" {
  count = local.recovery_create_secret ? 1 : 0

  metadata {
    name      = "${var.cluster.name}-recovery-credentials"
    namespace = var.cluster.namespace
    labels    = var.labels
  }

  data = {
    ACCESS_KEY_ID     = var.recovery.s3_access_key_id
    ACCESS_SECRET_KEY = var.recovery.s3_secret_access_key
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

# Allow the cluster service account to read the recovery credentials, mirroring the
# backup credentials role. CloudNativePG creates the ServiceAccount with the same
# name as the cluster.
resource "kubernetes_role_v1" "recovery_secret_reader" {
  count = local.recovery_create_secret ? 1 : 0

  metadata {
    name      = "${var.cluster.name}-recovery-secret-reader"
    namespace = var.cluster.namespace
    labels    = var.labels
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = [kubernetes_secret_v1.recovery_credentials[0].metadata[0].name]
    verbs          = ["get"]
  }
}

resource "kubernetes_role_binding_v1" "recovery_secret_reader" {
  count = local.recovery_create_secret ? 1 : 0

  metadata {
    name      = "${var.cluster.name}-recovery-secret-reader"
    namespace = var.cluster.namespace
    labels    = var.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.recovery_secret_reader[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.cluster.name
    namespace = var.cluster.namespace
  }
}
