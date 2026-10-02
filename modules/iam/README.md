# IAM module

Least-privilege access for humans and machines:

| Role | Who | Can do |
|---|---|---|
| `<prefix>-cluster-admin` | Platform engineers (SSO principals), MFA enforced | Administer EKS via `aws-iam-authenticator` mapping |
| `<prefix>-ci-deployer` | CI system (external ID on trust policy) | `eks:DescribeCluster`, ECR push/pull under `<prefix>/*`, write deploy logs |

Deliberately absent: `AdministratorAccess`, IAM mutation rights, and
`ecr:GetAuthorizationToken` scoping (that action only supports `*` —
documented inline). Every role and policy carries a `description` so the
next engineer knows *why* it exists.
