# Most of these are used by kitchen so it can forward them to inspec
output "main_vpc_id" {
  value       = module.k8s_vpc.vpc_id
  description = "ID of the main VPC geenrated by the module"
}

output "kubeconfig" {
  # No secrets are recroded here: the conf will reference AWS CLI conf/ENV
  value = local.kubeconfig
  description = "kubeconfig data authorized users can download; please refrain from using it to edit state"
}

output "cluster_id" {
  value = aws_eks_cluster.k8s.id
  description = "The EKS cluster ID"
}
