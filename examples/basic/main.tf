# Basic example of using the CloudNative-PG database module

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

# Configure providers (adjust to your environment)
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Create cluster and databases using the module
module "example_app_database" {
  source  = "git::ssh://git@github.com/pascalinthecloud/terraform-module-cnpg-database.git?ref=v0.0.7"

  databases = [
    {
      name                        = "example-app"
      owner                       = "example_app_user"
      password                    = var.database_password
      database_reclaim_policy     = "retain"
      create_connection_secret    = true
      connection_secret_namespace = ""
    }
  ]

  cluster = {
    name                       = "shared-postgres-dev"
    namespace                  = "databases-dev"
    instances                  = 1
    storage_class              = "longhorn"
    storage_size               = "10Gi"
    postgresql_max_connections = "100"
    # Other PostgreSQL parameters use defaults
  }

  labels = {
    app         = "example-app"
    environment = "dev"
    managed-by  = "terraform"
  }

  # Backup configuration (optional)
  backup = {
    enabled                 = var.backup_enabled
    s3_endpoint_url         = var.s3_endpoint_url
    s3_bucket_name          = var.s3_bucket_name
    s3_access_key_id        = var.s3_access_key_id
    s3_secret_access_key    = var.s3_secret_access_key
    retention_policy        = "90d"
    schedule                = "0 2 * * *" # Daily at 2 AM UTC
    wal_compression         = "gzip"
    data_compression        = "gzip"
    target                  = "prefer-standby"
    create_scheduled_backup = true
  }
}

# Output connection details
output "connection_host" {
  description = "Database connection hostname"
  value       = module.example_app_database.connection_host
}

output "connection_port" {
  description = "Database connection port"
  value       = module.example_app_database.connection_port
}

output "database_names" {
  description = "Names of the created databases"
  value       = module.example_app_database.database_names
}

output "connection_secret_names" {
  description = "Names of the connection secrets"
  value       = module.example_app_database.connection_secret_names
}

output "connection_uris" {
  description = "Full PostgreSQL connection URIs"
  value       = module.example_app_database.connection_uris
  sensitive   = true
}

# Backup outputs
output "backup_enabled" {
  description = "Whether backups are configured"
  value       = module.example_app_database.backup_enabled
}

output "backup_destination" {
  description = "S3 destination for backups"
  value       = module.example_app_database.backup_destination_path
}
