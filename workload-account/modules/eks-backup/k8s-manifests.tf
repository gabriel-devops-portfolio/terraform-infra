# Kubernetes Manifests for EKS Backup Components

############################
# Velero Namespace
############################

resource "kubernetes_namespace" "velero" {
  count = var.enable_velero ? 1 : 0

  metadata {
    name = "velero"
    labels = {
      "app.kubernetes.io/name" = "velero"
      "app.kubernetes.io/component" = "backup"
    }
  }
}

############################
# Velero Service Account
############################

resource "kubernetes_service_account" "velero" {
  count = var.enable_velero ? 1 : 0

  metadata {
    name      = "velero"
    namespace = kubernetes_namespace.velero[0].metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.velero.arn
    }
  }

  depends_on = [kubernetes_namespace.velero]
}

############################
# Velero ConfigMap
############################

resource "kubernetes_config_map" "velero_config" {
  count = var.enable_velero ? 1 : 0

  metadata {
    name      = "velero-config"
    namespace = kubernetes_namespace.velero[0].metadata[0].name
  }

  data = {
    "backup-location-config.yaml" = yamlencode({
      region = data.aws_region.current.name
      s3ForcePathStyle = "false"
      s3Url = "https://s3.${data.aws_region.current.name}.amazonaws.com"
    })

    "volume-snapshot-location-config.yaml" = yamlencode({
      region = data.aws_region.current.name
    })
  }

  depends_on = [kubernetes_namespace.velero]
}

############################
# Velero Backup Storage Location
############################

resource "kubectl_manifest" "velero_backup_storage_location" {
  count = var.enable_velero ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind = "BackupStorageLocation"
    metadata = {
      name = "default"
      namespace = kubernetes_namespace.velero[0].metadata[0].name
    }
    spec = {
      provider = "aws"
      objectStorage = {
        bucket = aws_s3_bucket.velero_backups.bucket
        prefix = "backups"
      }
      config = {
        region = data.aws_region.current.name
        s3ForcePathStyle = "false"
        s3Url = "https://s3.${data.aws_region.current.name}.amazonaws.com"
      }
    }
  })

  depends_on = [kubernetes_namespace.velero]
}

############################
# Velero Volume Snapshot Location
############################

resource "kubectl_manifest" "velero_volume_snapshot_location" {
  count = var.enable_velero ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind = "VolumeSnapshotLocation"
    metadata = {
      name = "default"
      namespace = kubernetes_namespace.velero[0].metadata[0].name
    }
    spec = {
      provider = "aws"
      config = {
        region = data.aws_region.current.name
      }
    }
  })

  depends_on = [kubernetes_namespace.velero]
}

############################
# Velero Scheduled Backups
############################

# Daily full cluster backup
resource "kubectl_manifest" "velero_daily_backup" {
  count = var.enable_velero ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind = "Schedule"
    metadata = {
      name = "daily-backup"
      namespace = kubernetes_namespace.velero[0].metadata[0].name
    }
    spec = {
      schedule = var.backup_schedule
      template = {
        includedNamespaces = ["*"]
        excludedNamespaces = ["kube-system", "kube-public", "kube-node-lease"]
        includeClusterResources = true
        snapshotVolumes = true
        ttl = "${var.backup_retention_days * 24}h0m0s"
        storageLocation = "default"
        volumeSnapshotLocations = ["default"]
        metadata = {
          labels = {
            "backup-type" = "scheduled"
            "cluster" = var.cluster_name
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_namespace.velero,
    kubectl_manifest.velero_backup_storage_location,
    kubectl_manifest.velero_volume_snapshot_location
  ]
}

# Weekly full cluster backup with longer retention
resource "kubectl_manifest" "velero_weekly_backup" {
  count = var.enable_velero ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind = "Schedule"
    metadata = {
      name = "weekly-backup"
      namespace = kubernetes_namespace.velero[0].metadata[0].name
    }
    spec = {
      schedule = "0 1 * * 0" # Weekly on Sunday at 1 AM
      template = {
        includedNamespaces = ["*"]
        includeClusterResources = true
        snapshotVolumes = true
        ttl = "${var.backup_retention_days * 2 * 24}h0m0s" # Double retention for weekly backups
        storageLocation = "default"
        volumeSnapshotLocations = ["default"]
        metadata = {
          labels = {
            "backup-type" = "weekly"
            "cluster" = var.cluster_name
          }
        }
      }
    }
  })

  depends_on = [
    kubernetes_namespace.velero,
    kubectl_manifest.velero_backup_storage_location,
    kubectl_manifest.velero_volume_snapshot_location
  ]
}

############################
# Backup Monitoring Resources
############################

# ServiceMonitor for Prometheus (if using Prometheus Operator)
resource "kubectl_manifest" "velero_service_monitor" {
  count = var.enable_backup_monitoring ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = "velero"
      namespace = kubernetes_namespace.velero[0].metadata[0].name
      labels = {
        "app.kubernetes.io/name" = "velero"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "velero"
        }
      }
      endpoints = [{
        port = "monitoring"
        path = "/metrics"
      }]
    }
  })

  depends_on = [kubernetes_namespace.velero]
}

############################
# Backup Restore Examples
############################

# ConfigMap with restore examples and documentation
resource "kubernetes_config_map" "backup_restore_examples" {
  count = var.enable_velero ? 1 : 0

  metadata {
    name      = "backup-restore-examples"
    namespace = kubernetes_namespace.velero[0].metadata[0].name
  }

  data = {
    "README.md" = templatefile("${path.module}/templates/backup-restore-guide.md", {
      cluster_name = var.cluster_name
      velero_bucket = aws_s3_bucket.velero_backups.bucket
    })

    "restore-examples.yaml" = templatefile("${path.module}/templates/restore-examples.yaml", {
      cluster_name = var.cluster_name
    })

    "backup-verification.sh" = templatefile("${path.module}/templates/backup-verification.sh", {
      cluster_name = var.cluster_name
      velero_bucket = aws_s3_bucket.velero_backups.bucket
    })
  }

  depends_on = [kubernetes_namespace.velero]
}
