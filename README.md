# Terraform Module: CloudNative-PG Database

Terraform module for creating PostgreSQL databases in CloudNative-PG clusters with automatic user and secret management.

## Features

- 🔐 Automatic password secret creation with hot-reload support
- 📦 Database and user provisioned declaratively
- 🔌 Connection details secret for easy application integration
- 🏷️ Customizable labels for all resources
- ✅ Input validation for security best practices
- 💾 S3-based backup configuration with CloudNativePG/Barman
- 📅 Automated scheduled backups with retention policies
- 🔄 Point-in-Time Recovery (PITR) support

## Prerequisites

- CloudNative-PG operator installed in your Kubernetes cluster

## Usage

### Basic Example

```hcl
module "my_app_database" {
  source = "github.com/pascalinthecloud/terraform-module-cnpg-database"

  databases = [{
    name     = "my-app"
    owner    = "my_app_user"
    password = var.database_password # Use a secure variable or secret manager
  }]

  cluster = {
    name      = "shared-postgres-prod"
    namespace = "databases-prod"
  }
}
```

### Complete Example with Labels

```hcl
module "my_app_database" {
  source = "github.com/pascalinthecloud/terraform-module-cnpg-database"

  databases = [{
    name     = "my-app"
    owner    = "my_app_user"
    password = var.database_password
  }]

  cluster = {
    name      = "shared-postgres-prod"
    namespace = "databases-prod"
  }

  labels = {
    app         = "my-app"
    environment = "production"
    managed-by  = "terraform"
  }
}
```

### Custom PostgreSQL Database Name

```hcl
module "my_app_database" {
  source = "github.com/pascalinthecloud/terraform-module-cnpg-database"

  databases = [{
    name             = "my-app"
    pg_database_name = "myapp_production" # Custom PostgreSQL database name
    owner            = "my_app_user"
    password         = var.database_password
  }]

  cluster = {
    name      = "shared-postgres-prod"
    namespace = "databases-prod"
  }
}
```

### Connection Secret in Different Namespace

```hcl
module "my_app_database" {
  source = "github.com/pascalinthecloud/terraform-module-cnpg-database"

  databases = [{
    name                        = "my-app"
    owner                       = "my_app_user"
    password                    = var.database_password
    connection_secret_namespace = "my-app-namespace" # Deploy connection secret to app namespace
  }]

  cluster = {
    name      = "shared-postgres-prod"
    namespace = "databases-prod"
  }
}
```

### With S3 Backups Enabled

```hcl
module "my_app_database" {
  source = "github.com/pascalinthecloud/terraform-module-cnpg-database"

  databases = [{
    name     = "my-app"
    owner    = "my_app_user"
    password = var.database_password
  }]

  cluster = {
    name      = "shared-postgres-prod"
    namespace = "databases-prod"
  }

  # Enable S3 backups
  backup = {
    enabled              = true
    s3_endpoint_url      = "https://s3.amazonaws.com"  # Or your S3-compatible endpoint
    s3_bucket_name       = "my-postgres-backups"
    s3_access_key_id     = var.s3_access_key_id
    s3_secret_access_key = var.s3_secret_access_key
    retention_policy     = "30d"
    schedule             = "0 2 * * *"  # Daily at 2 AM UTC
    target               = "prefer-standby"
    wal_compression      = "gzip"
    data_compression     = "gzip"
  }

  labels = {
    app         = "my-app"
    environment = "production"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.cluster](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.database](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.pod_monitor](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.scheduled_backup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_role_binding_v1.backup_secret_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_v1.backup_secret_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [kubernetes_secret_v1.backup_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.connection](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.database_password](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup"></a> [backup](#input\_backup) | Backup configuration for S3-based backups using Barman | <pre>object({<br/>    enabled                 = optional(bool, false)<br/>    s3_endpoint_url         = optional(string, "")<br/>    s3_bucket_name          = optional(string, "")<br/>    s3_access_key_id        = optional(string, "")<br/>    s3_secret_access_key    = optional(string, "")<br/>    retention_policy        = optional(string, "30d")<br/>    schedule                = optional(string, "0 2 * * *")<br/>    wal_compression         = optional(string, "gzip")<br/>    data_compression        = optional(string, "gzip")<br/>    jobs                    = optional(number, 2)<br/>    target                  = optional(string, "prefer-standby")<br/>    create_scheduled_backup = optional(bool, true)<br/>    immediate               = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | CloudNative-PG cluster configuration object | <pre>object({<br/>    name                                    = optional(string, "default-cluster")<br/>    namespace                               = optional(string, "default")<br/>    instances                               = optional(number, 1)<br/>    storage_class                           = optional(string, "longhorn") # Override with your cluster's available storage class<br/>    storage_size                            = optional(string, "10Gi")<br/>    inherited_labels                        = optional(map(string), {})<br/>    inherited_annotations                   = optional(map(string), {})<br/>    postgresql_max_connections              = optional(string, "100")<br/>    postgresql_shared_buffers               = optional(string, "256MB")<br/>    postgresql_effective_cache_size         = optional(string, "1GB")<br/>    postgresql_maintenance_work_mem         = optional(string, "64MB")<br/>    postgresql_checkpoint_completion_target = optional(string, "0.9")<br/>    postgresql_wal_buffers                  = optional(string, "16MB")<br/>    postgresql_default_statistics_target    = optional(string, "100")<br/>    postgresql_random_page_cost             = optional(string, "1.1")<br/>    postgresql_effective_io_concurrency     = optional(string, "200")<br/>    postgresql_work_mem                     = optional(string, "2621kB")<br/>    postgresql_min_wal_size                 = optional(string, "512MB")<br/>    postgresql_max_wal_size                 = optional(string, "2GB")<br/>    bootstrap_database                      = optional(string, "postgres")<br/>    bootstrap_owner                         = optional(string, "postgres")<br/>    enable_pod_monitor                      = optional(bool, true)<br/>    pod_monitor_labels                      = optional(map(string), {})<br/>    resources = optional(object({<br/>      requests = optional(object({<br/>        memory = optional(string, "512Mi")<br/>        cpu    = optional(string, "250m")<br/>      }), {})<br/>      limits = optional(object({<br/>        memory = optional(string)<br/>        cpu    = optional(string)<br/>      }), null)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | List of databases to create. Each object must have name, owner, password, and database\_reclaim\_policy.<br/>If the list is empty, the cluster will be created with no managed database users.<br/>Users can manually add roles to the cluster or add databases through this module later. | <pre>list(object({<br/>    name                        = string<br/>    owner                       = string<br/>    password                    = string<br/>    database_reclaim_policy     = optional(string, "retain")<br/>    pg_database_name            = optional(string, "")<br/>    create_connection_secret    = optional(bool, true)<br/>    connection_secret_namespace = optional(string, "")<br/>  }))</pre> | `[]` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backup_destination_path"></a> [backup\_destination\_path](#output\_backup\_destination\_path) | S3 destination path for backups |
| <a name="output_backup_enabled"></a> [backup\_enabled](#output\_backup\_enabled) | Whether backups are configured for this cluster |
| <a name="output_backup_secret_name"></a> [backup\_secret\_name](#output\_backup\_secret\_name) | Name of the Kubernetes secret containing backup credentials |
| <a name="output_connection_host"></a> [connection\_host](#output\_connection\_host) | Database connection hostname |
| <a name="output_connection_port"></a> [connection\_port](#output\_connection\_port) | Database connection port |
| <a name="output_connection_secret_names"></a> [connection\_secret\_names](#output\_connection\_secret\_names) | Names of the Kubernetes secrets containing connection details |
| <a name="output_connection_uris"></a> [connection\_uris](#output\_connection\_uris) | Full PostgreSQL connection URIs for each database |
| <a name="output_database_names"></a> [database\_names](#output\_database\_names) | Names of the created databases in PostgreSQL |
| <a name="output_owner_usernames"></a> [owner\_usernames](#output\_owner\_usernames) | Usernames of the database owners |
| <a name="output_password_secret_names"></a> [password\_secret\_names](#output\_password\_secret\_names) | Names of the Kubernetes secrets containing the database passwords |
| <a name="output_scheduled_backup_name"></a> [scheduled\_backup\_name](#output\_scheduled\_backup\_name) | Name of the ScheduledBackup resource |
<!-- END_TF_DOCS -->

## Backup Configuration

This module supports S3-based backups using CloudNativePG's Barman integration.

### Prerequisites for Backups

1. **S3-Compatible Storage**: AWS S3, MinIO, or other S3-compatible storage
2. **S3 Bucket**: Pre-created bucket for storing backups
3. **S3 Credentials**: Access key ID and secret access key

### Backup Features

- **Continuous WAL Archiving**: Write-Ahead Logs continuously archived to S3
- **Scheduled Backups**: Automated backups based on cron schedule
- **Retention Policies**: Automatic cleanup of old backups
- **Compression**: Configurable compression (gzip, bzip2, snappy)
- **PITR**: Point-in-Time Recovery support

### Backup Configuration

The `backup` object accepts the following properties:

| Property | Description | Default | Required |
|----------|-------------|---------|----------|
| `enabled` | Enable S3 backups | `false` | No |
| `s3_endpoint_url` | S3 endpoint URL (empty for AWS S3) | `""` | When enabled |
| `s3_bucket_name` | S3 bucket name | `""` | When enabled |
| `s3_access_key_id` | S3 access key ID | `""` | When enabled |
| `s3_secret_access_key` | S3 secret access key | `""` | When enabled |
| `retention_policy` | Retention policy (e.g., "30d") | `"30d"` | No |
| `schedule` | Cron schedule | `"0 2 * * *"` | No |
| `wal_compression` | WAL compression algorithm | `"gzip"` | No |
| `data_compression` | Data compression algorithm | `"gzip"` | No |
| `jobs` | Parallel backup jobs | `2` | No |
| `target` | Backup target instance | `"prefer-standby"` | No |
| `create_scheduled_backup` | Create ScheduledBackup resource | `true` | No |
| `immediate` | Take immediate backup on creation | `false` | No |

### What Gets Created for Backups

When `backup.enabled = true`, the module creates:

1. **Kubernetes Secret**: Stores S3 credentials securely
2. **RBAC Role**: Allows cluster service account to read backup credentials
3. **RBAC RoleBinding**: Binds the role to the cluster's service account
4. **Cluster Backup Config**: Configures Barman object store in cluster spec
5. **ScheduledBackup Resource**: Creates automated backup schedule (if `create_scheduled_backup = true`)

### Backup Schedule Examples

```hcl
# Daily at 2 AM UTC
backup = {
  schedule = "0 2 * * *"
}

# Every 6 hours
backup = {
  schedule = "0 */6 * * *"
}

# Weekly on Sunday at 3 AM
backup = {
  schedule = "0 3 * * 0"
}

# Monthly on the 1st at 1 AM
backup = {
  schedule = "0 1 1 * *"
}
```

### Monitoring Backups

Check backup status:

```bash
# List all backups
kubectl get backups -n <namespace>

# Check scheduled backup
kubectl get scheduledbackup -n <namespace>

# Describe backup details
kubectl describe backup <backup-name> -n <namespace>

# View cluster backup status
kubectl describe cluster <cluster-name> -n <namespace>
```

### Point-in-Time Recovery (PITR)

To restore from backups, create a new cluster with recovery configuration. See the [CloudNativePG documentation](https://cloudnative-pg.io/documentation/current/recovery/) for details.

## Connection Details Secret

When `create_connection_secret = true` (default), the module creates a secret with the following keys:

- `host` - Database hostname
- `port` - Database port (5432)
- `database` - Database name
- `username` - Database username
- `password` - Database password
- `uri` - Full connection URI

Example usage in a pod:

```yaml
env:
  - name: DATABASE_HOST
    valueFrom:
      secretKeyRef:
        name: my-app-db-connection
        key: host
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: my-app-db-connection
        key: uri
```

## How It Works

1. **Password Secret**: Creates a `kubernetes.io/basic-auth` secret with the `cnpg.io/reload` label for hot password updates
2. **Database CRD**: Creates a CloudNative-PG Database resource that triggers database creation
3. **Connection Secret**: Optionally creates a connection details secret for application use

The CloudNative-PG operator reconciles the managed role in the cluster and creates the database with the specified owner.

## Security Best Practices

- Always use a secure method to provide passwords (e.g., Terraform variables with encryption, secret managers)
- Never commit passwords to version control
- Use strong passwords (minimum 8 characters enforced by validation)
- Consider using Kubernetes RBAC to restrict access to password secrets

## License

MIT

## Author

Pascal Toepke
