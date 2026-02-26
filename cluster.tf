# Create the PostgreSQL cluster with managed roles
resource "kubernetes_manifest" "cluster" {
  depends_on = [kubernetes_secret_v1.database_password]

  # Ignore server-side defaults added by CNPG operator
  computed_fields = [
    "spec.postgresql.parameters",
    "spec.resources.limits",
    "spec.inheritedMetadata",
  ]

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = var.cluster.name
      namespace = var.cluster.namespace
      labels    = var.labels
    }
    spec = {
      instances = var.cluster.instances

      # Inherited metadata for PVCs and other resources
      inheritedMetadata = length(var.cluster.inherited_labels) > 0 || length(var.cluster.inherited_annotations) > 0 ? {
        labels      = length(var.cluster.inherited_labels) > 0 ? var.cluster.inherited_labels : null
        annotations = length(var.cluster.inherited_annotations) > 0 ? var.cluster.inherited_annotations : null
      } : null

      # Resources
      resources = merge(
        {
          requests = var.cluster.resources.requests
        },
        var.cluster.resources.limits != null ? { limits = var.cluster.resources.limits } : {}
      )

      # Storage using configurable storage class
      storage = {
        storageClass = var.cluster.storage_class
        size         = var.cluster.storage_size
      }

      # PostgreSQL configuration
      postgresql = {
        parameters = {
          max_connections              = var.cluster.postgresql_max_connections
          shared_buffers               = var.cluster.postgresql_shared_buffers
          effective_cache_size         = var.cluster.postgresql_effective_cache_size
          maintenance_work_mem         = var.cluster.postgresql_maintenance_work_mem
          checkpoint_completion_target = var.cluster.postgresql_checkpoint_completion_target
          wal_buffers                  = var.cluster.postgresql_wal_buffers
          default_statistics_target    = var.cluster.postgresql_default_statistics_target
          random_page_cost             = var.cluster.postgresql_random_page_cost
          effective_io_concurrency     = var.cluster.postgresql_effective_io_concurrency
          work_mem                     = var.cluster.postgresql_work_mem
          min_wal_size                 = var.cluster.postgresql_min_wal_size
          max_wal_size                 = var.cluster.postgresql_max_wal_size
        }
      }

      # Bootstrap
      bootstrap = {
        initdb = {
          database = var.cluster.bootstrap_database
          owner    = var.cluster.bootstrap_owner
        }
      }

      # Monitoring
      # When custom pod_monitor_labels are set, disable the auto-generated PodMonitor
      # and create a custom one (see below) with the desired labels instead.
      monitoring = {
        enablePodMonitor = length(var.cluster.pod_monitor_labels) > 0 ? false : var.cluster.enable_pod_monitor
      }

      # Managed roles - define users based on distinct database owners
      managed = {
        roles = [for owner in distinct([for db in local.databases_for_iteration : db.owner]) : {
          name    = owner
          ensure  = "present"
          login   = true
          inherit = true
          passwordSecret = {
            # Use the first database name associated with this owner.
            # This is safe because 'owner' comes from the databases list, so at least one database exists per owner.
            name = "${element([for db in local.databases_for_iteration : db.name if db.owner == owner], 0)}-user-password"
          }
        }]
      }

      # Backup configuration (conditional based on backup.enabled)
      backup = var.backup.enabled ? {
        barmanObjectStore = {
          # S3 destination
          destinationPath = "s3://${var.backup.s3_bucket_name}/"
          endpointURL     = var.backup.s3_endpoint_url != "" ? var.backup.s3_endpoint_url : null
          serverName      = var.cluster.name

          # S3 credentials reference
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

          # WAL (Write-Ahead Log) configuration
          wal = {
            compression = var.backup.wal_compression
            # WAL upload parallelism is intentionally limited to 2 to avoid excessive I/O/CPU pressure
            # and to follow CNPG/Barman recommendations. Data backup parallelism is configured separately
            # via var.backup.jobs in the "data" block below.
            maxParallel = 2
          }

          # Data backup configuration
          data = {
            compression         = var.backup.data_compression
            jobs                = var.backup.jobs
            immediateCheckpoint = false
          }
        }

        # Retention policy
        retentionPolicy = var.backup.retention_policy

        # Backup target
        target = var.backup.target
      } : null
    }
  }
}

# Custom PodMonitor with additional labels (e.g. for Prometheus Operator discovery)
# Created when pod_monitor_labels is set, replacing the CNPG auto-generated PodMonitor.
resource "kubernetes_manifest" "pod_monitor" {
  count = length(var.cluster.pod_monitor_labels) > 0 ? 1 : 0

  depends_on = [kubernetes_manifest.cluster]

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = var.cluster.name
      namespace = var.cluster.namespace
      labels    = merge(var.labels, var.cluster.pod_monitor_labels)
    }
    spec = {
      selector = {
        matchLabels = {
          "cnpg.io/cluster" = var.cluster.name
        }
      }
      podMetricsEndpoints = [
        {
          port = "metrics"
        }
      ]
    }
  }
}
