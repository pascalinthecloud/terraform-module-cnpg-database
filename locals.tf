locals {
  # Create a non-sensitive version of databases for use in for_each
  # This is required because for_each keys cannot be sensitive values
  # Note: The passwords remain sensitive when used in the secret data blocks
  databases_for_iteration = nonsensitive(var.databases)

  # Backup mode. nonsensitive() because var.backup is sensitive (it carries S3 keys)
  # and these booleans drive count/conditionals; they contain no secret material.
  backup_in_tree = nonsensitive(var.backup.enabled && var.backup.method == "barmanObjectStore")
  backup_plugin  = nonsensitive(var.backup.enabled && var.backup.method == "plugin")

  barman_plugin_name = "barman-cloud.cloudnative-pg.io"
  object_store_name  = "${var.cluster.name}-backup"
}
