variable "databases" {
  description = <<-EOT
    List of databases to create. Each object must have name, owner, password, and database_reclaim_policy.
    If the list is empty, the cluster will be created with no managed database users.
    Users can manually add roles to the cluster or add databases through this module later.
  EOT
  type = list(object({
    name                        = string
    owner                       = string
    password                    = string
    database_reclaim_policy     = optional(string, "retain")
    pg_database_name            = optional(string, "")
    create_connection_secret    = optional(bool, true)
    connection_secret_namespace = optional(string, "")
  }))
  default   = []
  sensitive = true

  validation {
    condition = alltrue([
      for db in var.databases :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", db.name))
    ])
    error_message = "Each database.name must be a valid Kubernetes resource name (lowercase alphanumeric with hyphens)."
  }

  validation {
    condition = alltrue([
      for db in var.databases :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", db.owner))
    ])
    error_message = "Each database.owner must be a valid PostgreSQL identifier (start with a letter or underscore, followed by letters, digits, or underscores)."
  }

  validation {
    condition = alltrue([
      for db in var.databases :
      length(db.password) >= 8
    ])
    error_message = "Each database.password must be at least 8 characters long."
  }

  validation {
    condition = alltrue([
      for db in var.databases :
      contains(["delete", "retain"], db.database_reclaim_policy)
    ])
    error_message = "Each database_reclaim_policy must be either \"delete\" or \"retain\"."
  }
}

variable "cluster" {
  description = "CloudNative-PG cluster configuration object"
  type = object({
    name                                    = optional(string, "default-cluster")
    namespace                               = optional(string, "default")
    instances                               = optional(number, 1)
    storage_class                           = optional(string, "longhorn") # Override with your cluster's available storage class
    storage_size                            = optional(string, "10Gi")
    inherited_labels                        = optional(map(string), {})
    inherited_annotations                   = optional(map(string), {})
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
    postgresql_max_slot_wal_keep_size       = optional(string, "10GB") # Cap WAL kept for an inactive replication slot; -1 (unlimited) lets a down replica fill the primary and halt it
    bootstrap_database                      = optional(string, "postgres")
    bootstrap_owner                         = optional(string, "postgres")
    enable_pod_monitor                      = optional(bool, true)
    pod_monitor_labels                      = optional(map(string), {})
    switchover_delay                        = optional(number) # spec.switchoverDelay: seconds the old primary gets to shut down on a switchover/failover; null = CNPG default (3600)
    image_name                              = optional(string) # spec.imageName: PostgreSQL operand image, e.g. ghcr.io/cloudnative-pg/postgresql:18.6-system-trixie; null = CNPG default, fixed at creation
    resources = optional(object({
      requests = optional(object({
        memory = optional(string, "512Mi")
        cpu    = optional(string, "250m")
      }), {})
      limits = optional(object({
        memory = optional(string)
        cpu    = optional(string)
      }), null)
    }), {})
  })
  default = {}

  validation {
    condition     = var.cluster.switchover_delay == null ? true : var.cluster.switchover_delay > 0
    error_message = "switchover_delay must be a positive number of seconds (or null for the CNPG default)."
  }

  validation {
    condition     = var.cluster.image_name == null ? true : can(regex("(:[A-Za-z0-9_][A-Za-z0-9_.-]*|@sha256:[a-f0-9]{64})$", var.cluster.image_name)) && !endswith(var.cluster.image_name, ":latest")
    error_message = "image_name must carry an explicit tag or digest (not :latest): CNPG only does a controlled rolling update when the image reference changes."
  }

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
    # "barmanObjectStore" = in-tree Barman Cloud (deprecated in CNPG 1.26, removed in 1.31)
    # "plugin"            = Barman Cloud Plugin (barman-cloud.cloudnative-pg.io), which must be installed
    method = optional(string, "barmanObjectStore")
  })
  default   = {}
  sensitive = true

  validation {
    condition     = !var.backup.enabled || can(regex("^[1-9][0-9]*[dwm]$", var.backup.retention_policy))
    error_message = "Retention policy must be in format '<number><unit>' where unit is d (days), w (weeks), or m (months)."
  }

  validation {
    condition     = contains(["barmanObjectStore", "plugin"], var.backup.method)
    error_message = "Backup method must be one of: barmanObjectStore, plugin."
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

  validation {
    condition = !var.backup.enabled || (
      var.backup.s3_bucket_name != "" &&
      var.backup.s3_access_key_id != "" &&
      var.backup.s3_secret_access_key != ""
    )
    error_message = "When backup is enabled, s3_bucket_name, s3_access_key_id, and s3_secret_access_key must all be provided."
  }
}

variable "recovery" {
  description = <<-EOT
    Bootstrap the cluster from an existing Barman object store instead of initdb - a DRP restore
    or a clone of another cluster. When enabled, spec.bootstrap.recovery plus spec.externalClusters
    replace spec.bootstrap.initdb, and var.cluster.bootstrap_database/bootstrap_owner are ignored.

    Recovery only happens once, when the cluster is first created: changing these values afterwards
    does not re-run it, the cluster has to be destroyed and created again.

    Leave every target_* and backup_id unset to recover to the end of the WAL archive.

    The restored cluster keeps the roles, passwords and databases of the source. Combine it with
    databases = [] so the module does not create Database objects or reset owner passwords on
    restored data.
  EOT
  type = object({
    enabled = optional(bool, false)

    # serverName of the source cluster inside the object store - the folder the source
    # archived into, which is the source cluster's own name unless it was overridden.
    source_server_name = optional(string, "")

    # Source object store. The credentials only need read access.
    s3_bucket_name       = optional(string, "")
    s3_endpoint_url      = optional(string, "")
    s3_access_key_id     = optional(string, "")
    s3_secret_access_key = optional(string, "")
    # Use an existing secret (keys ACCESS_KEY_ID / ACCESS_SECRET_KEY) instead of the
    # access keys above, e.g. the backup credentials secret of the source cluster.
    credentials_secret = optional(string, "")

    wal_max_parallel = optional(number, 2)

    # spec.bootstrap.recovery.recoveryTarget - at most one of these
    target_time      = optional(string) # e.g. "2026-11-13 09:30:00+00"
    target_lsn       = optional(string)
    target_name      = optional(string)
    target_xid       = optional(string)
    target_tli       = optional(string) # target timeline: "latest" or a positive integer
    target_immediate = optional(bool)   # stop as soon as a consistent state is reached
    target_exclusive = optional(bool)   # CRD field "exclusive"; false (the CNPG default) is meaningful
    backup_id        = optional(string)
  })
  default   = {}
  sensitive = true

  validation {
    condition     = !var.recovery.enabled || var.recovery.source_server_name != ""
    error_message = "When recovery is enabled, source_server_name must be set to the serverName the source cluster archived under."
  }

  validation {
    condition     = !var.recovery.enabled || var.recovery.s3_bucket_name != ""
    error_message = "When recovery is enabled, s3_bucket_name must be set: it forms the destinationPath of the source object store."
  }

  validation {
    condition = !var.recovery.enabled || var.recovery.credentials_secret != "" || (
      var.recovery.s3_access_key_id != "" && var.recovery.s3_secret_access_key != ""
    )
    error_message = "When recovery is enabled, set either credentials_secret or both s3_access_key_id and s3_secret_access_key."
  }

  # target_immediate is only a target when it is true: an explicit false means
  # "do not stop early" and must not collide with target_time and friends.
  validation {
    condition = length(compact([
      var.recovery.target_time,
      var.recovery.target_lsn,
      var.recovery.target_name,
      var.recovery.target_xid,
      var.recovery.target_immediate == true ? "targetImmediate" : null,
    ])) <= 1
    error_message = "Set at most one recovery target (target_time, target_lsn, target_name, target_xid, target_immediate). Leave all unset to recover to the end of the WAL archive."
  }

  validation {
    condition     = !var.recovery.enabled || var.recovery.wal_max_parallel >= 1
    error_message = "wal_max_parallel must be at least 1."
  }

  # The restored cluster archives under serverName = var.cluster.name. If that is the
  # folder it recovers from, it would overwrite the source's own backup catalog.
  validation {
    condition = !(
      var.recovery.enabled &&
      var.backup.enabled &&
      var.backup.s3_bucket_name == var.recovery.s3_bucket_name &&
      var.cluster.name == var.recovery.source_server_name
    )
    error_message = "A restored cluster must not archive into the object store folder it recovers from. Give the cluster a different name than recovery.source_server_name, or disable backup."
  }
}
