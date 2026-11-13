locals {
  # Create a non-sensitive version of databases for use in for_each
  # This is required because for_each keys cannot be sensitive values
  # Note: The passwords remain sensitive when used in the secret data blocks
  databases_for_iteration = nonsensitive(var.databases)

  # Backup mode. nonsensitive() because var.backup is sensitive (it carries S3 keys)
  # and these booleans drive count/conditionals; they contain no secret material.
  backup_in_tree = nonsensitive(var.backup.enabled && var.backup.method == "barmanObjectStore")
  backup_plugin  = nonsensitive(var.backup.enabled && var.backup.method == "plugin")

  # 0 = backups disabled, 1 = plugin, 2 = in-tree barmanObjectStore
  backup_spec_index = local.backup_in_tree ? 2 : (local.backup_plugin ? 1 : 0)

  # Via a conditional (not a bare [0] index) because the in-tree spec fragment is
  # evaluated even when unused, and the secret doesn't exist with backups disabled.
  backup_secret_name = nonsensitive(var.backup.enabled) ? kubernetes_secret_v1.backup_credentials[0].metadata[0].name : ""

  barman_plugin_name = "barman-cloud.cloudnative-pg.io"
  object_store_name  = "${var.cluster.name}-backup"

  # Recovery mode. nonsensitive() because var.recovery is sensitive (it carries S3 keys)
  # and these drive count/index expressions; they contain no secret material.
  recovery_enabled       = nonsensitive(var.recovery.enabled)
  recovery_create_secret = nonsensitive(var.recovery.enabled && var.recovery.credentials_secret == "")

  # Name of the external cluster in spec.externalClusters and of the folder in the
  # object store. nonsensitive() so it can be used as a map key / resource name.
  recovery_source_name = nonsensitive(var.recovery.source_server_name)

  # Via a conditional (not a bare [0] index) because the recovery spec fragment is
  # evaluated even when unused, and the secret doesn't exist with recovery disabled.
  recovery_secret_name = (local.recovery_create_secret
    ? kubernetes_secret_v1.recovery_credentials[0].metadata[0].name
    : nonsensitive(var.recovery.credentials_secret)
  )

  # spec.bootstrap.recovery.recoveryTarget: only the keys that were set. An explicit
  # null would be sent to the API server and rejected by the CRD.
  recovery_target = {
    for k, v in {
      backupID        = var.recovery.backup_id
      targetTime      = var.recovery.target_time
      targetLSN       = var.recovery.target_lsn
      targetName      = var.recovery.target_name
      targetXID       = var.recovery.target_xid
      targetImmediate = var.recovery.target_immediate
      exclusive       = var.recovery.target_exclusive
    } : k => v if v != null
  }
}
