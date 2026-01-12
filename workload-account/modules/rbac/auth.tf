provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = var.eks_cluster_ca_certificate
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = var.eks_cluster_ca_certificate
  token                  = data.aws_eks_cluster_auth.cluster.token
}
