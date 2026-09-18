# ============================================
# Backup Configuration Resources
# ============================================
# These resources enable S3-based backups using Barman for CloudNativePG clusters.
# Includes: credentials secret, RBAC permissions, and scheduled backups.

# Create Kubernetes secret with S3 credentials for backups
resource "kubernetes_secret_v1" "backup_credentials" {
  count = var.backup.enabled ? 1 : 0

  metadata {
    name      = "${var.cluster.name}-backup-credentials"
    namespace = var.cluster.namespace
    labels    = var.labels
  }

  data = {
    ACCESS_KEY_ID     = var.backup.s3_access_key_id
    ACCESS_SECRET_KEY = var.backup.s3_secret_access_key
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

# Create RBAC role to allow the cluster service account to read backup credentials
resource "kubernetes_role_v1" "backup_secret_reader" {
  count = var.backup.enabled ? 1 : 0

  metadata {
    name      = "${var.cluster.name}-backup-secret-reader"
    namespace = var.cluster.namespace
    labels    = var.labels
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = [kubernetes_secret_v1.backup_credentials[0].metadata[0].name]
    verbs          = ["get"]
  }
}

# Bind the role to the cluster's service account
# CloudNativePG automatically creates a ServiceAccount with the same name as the cluster
resource "kubernetes_role_binding_v1" "backup_secret_reader" {
  count = var.backup.enabled ? 1 : 0

  metadata {
    name      = "${var.cluster.name}-backup-secret-reader"
    namespace = var.cluster.namespace
    labels    = var.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.backup_secret_reader[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.cluster.name
    namespace = var.cluster.namespace
  }
}

# Create scheduled backup resource for automated backups
resource "kubernetes_manifest" "scheduled_backup" {
  count = var.backup.enabled && var.backup.create_scheduled_backup ? 1 : 0

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "ScheduledBackup"
    metadata = {
      name      = "${var.cluster.name}-scheduled"
      namespace = var.cluster.namespace
      labels    = var.labels
    }
    spec = merge({
      # Cron schedule for backups
      schedule = var.backup.schedule

      # Backup ownership - "self" means the ScheduledBackup owns the Backup resources
      backupOwnerReference = "self"

      # Target cluster
      cluster = {
        name = var.cluster.name
      }

      # Backup method: in-tree Barman Cloud or the Barman Cloud Plugin
      method = local.backup_plugin ? "plugin" : "barmanObjectStore"

      # Take backup immediately on creation
      immediate = var.backup.immediate

      # Target instance for backups (prefer-standby reduces load on primary)
      target = var.backup.target
      },
      # pluginConfiguration only in plugin mode (omitted, not null, otherwise)
      [{}, { pluginConfiguration = { name = local.barman_plugin_name } }][local.backup_plugin ? 1 : 0],
    )
  }

  depends_on = [
    kubernetes_manifest.cluster
  ]
}

# Barman Cloud Plugin object store (backup.method = "plugin").
# A direct translation of the in-tree .spec.backup.barmanObjectStore block; the
# retention policy moves here from the Cluster.
resource "kubernetes_manifest" "object_store" {
  count = local.backup_plugin ? 1 : 0

  manifest = {
    apiVersion = "barmancloud.cnpg.io/v1"
    kind       = "ObjectStore"
    metadata = {
      name      = local.object_store_name
      namespace = var.cluster.namespace
      labels    = var.labels
    }
    spec = {
      retentionPolicy = var.backup.retention_policy
      configuration = {
        destinationPath = "s3://${var.backup.s3_bucket_name}/"
        endpointURL     = var.backup.s3_endpoint_url != "" ? var.backup.s3_endpoint_url : null

        s3Credentials = {
          accessKeyId = {
            name = kubernetes_secret_v1.backup_credentials[0].metadata[0].name
            key  = "ACCESS_KEY_ID"
          }
          secretAccessKey = {
            name = kubernetes_secret_v1.backup_credentials[0].metadata[0].name
            key  = "ACCESS_SECRET_KEY"
          }
        }

        wal = {
          compression = var.backup.wal_compression
          maxParallel = 2
        }

        data = {
          compression         = var.backup.data_compression
          jobs                = var.backup.jobs
          immediateCheckpoint = false
        }
      }
    }
  }
}

