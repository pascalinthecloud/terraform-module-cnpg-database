# Example: PostGIS-enabled CloudNative-PG cluster

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

# Create a PostGIS-enabled cluster
module "postgis_database" {
  source  = "git::ssh://git@github.com/pascalinthecloud/terraform-module-cnpg-database.git?ref=v0.0.7"

  databases = [
    {
      name                    = "geospatial-app"
      owner                   = "geo_user"
      password                = var.database_password
      database_reclaim_policy = "retain"
    }
  ]

  cluster = {
    name          = "postgis-cluster"
    namespace     = "databases"
    instances     = 3
    storage_class = "longhorn"
    storage_size  = "10Gi"

    # Use the PostGIS image (must match the PG major version)
    image_name = "ghcr.io/cloudnative-pg/postgis:17-3.5"

    # Create PostGIS and related extensions during bootstrap
    bootstrap_post_init_sql = [
      "CREATE EXTENSION IF NOT EXISTS postgis;",
      "CREATE EXTENSION IF NOT EXISTS postgis_topology;",
      "CREATE EXTENSION IF NOT EXISTS hstore;",
      "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;",
    ]
  }

  labels = {
    app         = "geospatial-app"
    environment = "production"
    managed-by  = "terraform"
  }
}

# Output connection details
output "connection_host" {
  description = "Database connection hostname"
  value       = module.postgis_database.connection_host
}

output "connection_port" {
  description = "Database connection port"
  value       = module.postgis_database.connection_port
}

output "connection_uris" {
  description = "Full PostgreSQL connection URIs"
  value       = module.postgis_database.connection_uris
  sensitive   = true
}
