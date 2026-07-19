output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint URL for the EKS Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID created by EKS for cluster communication."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "IAM role ARN used by the EKS managed node group."
  value       = aws_iam_role.node.arn
}

output "node_group_name" {
  description = "Name of the default EKS managed node group."
  value       = aws_eks_node_group.default.node_group_name
}