# VPC module

Isolated network foundation for the platform: one VPC, public and private
subnets across two AZs, internet gateway, NAT gateway(s), and route tables.

Public subnets carry the `kubernetes.io/role/elb` tags (and private subnets
`kubernetes.io/role/internal-elb`) so the AWS Load Balancer Controller can
discover them automatically.

## Cost note

A single shared NAT gateway is the default (`enable_nat_gateway_per_az = false`).
Flip it to `true` for production HA — roughly $32/month extra per gateway.

## Inputs

| Name | Description | Default |
|---|---|---|
| `name_prefix` | Prefix for Name tags | — |
| `cluster_name` | EKS cluster name (subnet discovery tags) | — |
| `cidr_block` | VPC CIDR, validated | `10.0.0.0/16` |
| `azs` | Exactly 2 availability zones | — |
| `enable_nat_gateway_per_az` | HA NAT topology | `false` |
| `tags` | Extra tags | `{}` |
