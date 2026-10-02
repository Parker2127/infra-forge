output "cluster_admin_role_arn" {
  description = "ARN of the cluster-admin role. Map it to cluster-admin in aws-iam-authenticator."
  value       = aws_iam_role.cluster_admin.arn
}

output "ci_deployer_role_arn" {
  description = "ARN of the CI deployer role for pipeline AWS credentials."
  value       = aws_iam_role.ci_deployer.arn
}
