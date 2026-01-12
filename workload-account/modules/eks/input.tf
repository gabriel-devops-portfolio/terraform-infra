variable "eks_vpc_id" {
  type        = string
  default     = ""
  description = "The VPC for the eks cluster"
}


variable "eks_cluster_endpoint_public_access" {
  description = ""
  type        = bool
  default     = false
}

variable "manage_aws_auth_configmap" {
  type    = bool
  default = true
}
variable "cluster_endpoint_public_access_cidrs" {
  default = []
}

variable "enable_sso_roles" {
  default = false
}


variable "eks_cluster_endpoint_private_access" {
  description = ""
  type        = bool
  default     = true
}

variable "eks_config_output_path" {
  type        = string
  default     = ""
  description = "Name of the cluster"
}

variable "eks_cluster_name" {
  type        = string
  default     = ""
  description = "Name of the cluster"
}

variable "eks_cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  default     = []
  description = "cidr"
}

variable "subnet_ids" {
  type        = any
  default     = ""
  description = "subnets the cluster will manage"
}
variable "aws_auth_users" {
  description = "IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
}

variable "aws_auth_roles" {
  description = "IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
}

variable "aws_auth_accounts" {
  type    = list(string)
  default = []
}

variable "cluster_enabled_log_types" {
  type        = list(string)
  default     = []
  description = "log types"
}


variable "eks_kms_arn" {
  type        = string
  default     = ""
  description = "The KMS key for encryption"
}
variable "eks_cluster_version" {
  type        = string
  default     = ""
  description = "k8s version"
}
variable "eks_cluster_tags" {
  type        = any
  default     = ""
  description = "Cluster Tags"
}
variable "eks_cluster_encryption_config" {
  type        = any
  default     = ""
  description = "Cluster encryption config"
}
variable "eks_worker_groups_launch_template" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults for valid keys."
  type        = any
  default     = []
}

variable "eks_managed_node_groups" {
  type        = map(any)
  description = "A map of maps defining eks managed node group configurations to be defined using AWS Launch Templates. See .../modules/eks/.terraform/modules/eks-cluster/modules/node_groups/README.md"
  default     = {}
}

variable "cluster_addons" {
  default = {}
}
variable "cluster_security_group_additional_rules" {
  default = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }
}

variable "node_security_group_ntp_ipv4_cidr_block" {
  default = ["169.254.169.123/32"]
}
variable "cloud_watch_log_group_retention_period" {
  default = 90
}
variable "node_security_group_additional_rules" {
  default = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # Control plane invoke Karpenter webhook
    ingress_karpenter_webhook_tcp = {
      description                   = "Control plane invoke Karpenter webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    # Control plane invoke AWS Load Balancer
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }
}

variable "storage_class_yaml" {
  default = <<YAML
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
allowVolumeExpansion: true
reclaimPolicy: Delete
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
YAML

}

variable "eks_full_access_role" {
  default = "EKS-Full-Access"
}
