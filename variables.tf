variable "databases" {
  description = "List of databases to create. Each object must have name, owner, password, and database_reclaim_policy."
  type = list(object({
    name                        = string
    owner                       = string
    password                    = string
    database_reclaim_policy     = optional(string, "retain")
    pg_database_name            = optional(string, "")
    create_connection_secret    = optional(bool, true)
    connection_secret_namespace = optional(string, "")
  }))
  default = []
  sensitive = true
}

variable "cluster" {
  description = "CloudNative-PG cluster configuration object"
  type = object({
    name                                    = optional(string, "default-cluster")
    namespace                               = optional(string, "default")
    instances                               = optional(number, 1)
    storage_class                           = optional(string, "longhorn")
    storage_size                            = optional(string, "10Gi")
    postgresql_max_connections              = optional(string, "100")
    postgresql_shared_buffers               = optional(string, "256MB")
    postgresql_effective_cache_size         = optional(string, "1GB")
    postgresql_maintenance_work_mem         = optional(string, "64MB")
    postgresql_checkpoint_completion_target = optional(string, "0.9")
    postgresql_wal_buffers                  = optional(string, "16MB")
    postgresql_default_statistics_target    = optional(string, "100")
    postgresql_random_page_cost             = optional(string, "1.1")
    postgresql_effective_io_concurrency     = optional(string, "200")
    postgresql_work_mem                     = optional(string, "2621kB")
    postgresql_min_wal_size                 = optional(string, "512MB")
    postgresql_max_wal_size                 = optional(string, "2GB")
    bootstrap_database                      = optional(string, "postgres")
    bootstrap_owner                         = optional(string, "postgres")
    enable_pod_monitor                      = optional(bool, true)
    resources = optional(object({
      requests = optional(object({
        memory = optional(string, "512Mi")
        cpu    = optional(string, "250m")
      }), {})
      limits = optional(object({
        memory = optional(string, "1Gi")
        cpu    = optional(string, "500m")
      }), {})
    }), {})
  })
  default = {}

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.cluster.name))
    error_message = "Cluster name must be a valid Kubernetes resource name (lowercase alphanumeric with hyphens)."
  }

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.cluster.namespace))
    error_message = "Namespace must be a valid Kubernetes resource name (lowercase alphanumeric with hyphens)."
  }
}

variable "labels" {
  description = "Additional labels to add to all resources"
  type        = map(string)
  default     = {}
}

variable "backup" {
  description = "Backup configuration for S3-based backups using Barman"
  type = object({
    enabled                 = optional(bool, false)
    s3_endpoint_url         = optional(string, "")
    s3_bucket_name          = optional(string, "")
    s3_access_key_id        = optional(string, "")
    s3_secret_access_key    = optional(string, "")
    retention_policy        = optional(string, "30d")
    schedule                = optional(string, "0 2 * * *")
    wal_compression         = optional(string, "gzip")
    data_compression        = optional(string, "gzip")
    jobs                    = optional(number, 2)
    target                  = optional(string, "prefer-standby")
    create_scheduled_backup = optional(bool, true)
    immediate               = optional(bool, false)
  })
  default   = {}
  sensitive = true

  validation {
    condition     = !var.backup.enabled || can(regex("^[1-9][0-9]*[dwm]$", var.backup.retention_policy))
    error_message = "Retention policy must be in format '<number><unit>' where unit is d (days), w (weeks), or m (months)."
  }

  validation {
    condition     = contains(["gzip", "bzip2", "snappy", "none"], var.backup.wal_compression)
    error_message = "WAL compression must be one of: gzip, bzip2, snappy, none."
  }

  validation {
    condition     = contains(["gzip", "bzip2", "snappy", "none"], var.backup.data_compression)
    error_message = "Data compression must be one of: gzip, bzip2, snappy, none."
  }

  validation {
    condition     = var.backup.jobs >= 1 && var.backup.jobs <= 8
    error_message = "Backup jobs must be between 1 and 8."
  }

  validation {
    condition     = contains(["primary", "prefer-standby"], var.backup.target)
    error_message = "Backup target must be either 'primary' or 'prefer-standby'."
  }
}
