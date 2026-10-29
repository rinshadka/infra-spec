# AWS network module

This child module builds an IPv4-only VPC with public, private application, and private data
subnets in each explicitly selected Availability Zone. It does not select a Region/account,
configure credentials or state, create load balancers, or adopt existing network resources.

## Required inputs

The caller must provide `environment`, `ipam_approval_reference`, `vpc_cidr_block`,
`availability_zone_ids`, `subnet_cidrs_by_az`, `nat_mode`, `flow_log_destination_arn`,
`flow_log_operations_owner`, and required governance `tags`. `nat_mode` is one of `disabled`,
`shared`, or `per_az`, with no default. NAT modes require an operations SNS topic. The module
requires at least two AZ IDs and a complete public/application/data subnet triplet for each AZ.
CIDRs must be canonical, non-overlapping IPv4 ranges, contained by the VPC, with subnets no
smaller than `/28`. The IPAM reference is a reviewer-verified record, not a machine-verifiable
claim of address ownership.

`endpoint_configs`, `allowed_flows`, `allowed_egress`, `public_lb_ingress`, and `additional_tags` default to empty
values. Endpoints exist only when declared. Interface endpoints are placed in selected private
subnets and allow HTTPS only from declared workload tiers. Gateway endpoints attach only to
selected route-table tiers and add prefix-list egress only to declared workload tiers. Service
availability and endpoint policy behavior must be reviewed in an authorized plan.

## Network boundaries

- Public IPv4 auto-assignment and IPv6 are disabled. The public route tables alone have an
  internet-gateway default route.
- Private application and data route tables receive NAT default routes only when NAT is enabled.
  Shared NAT uses the lexicographically first selected AZ ID; per-AZ NAT uses one gateway per AZ.
- Security groups have no inline ingress or egress. Only `allowed_flows`, endpoint access, and
  `allowed_egress` add rules. Egress requires explicit CIDR/prefix list, protocol, ports, and a
  rationale; universal destinations are rejected. NAT is not a destination filter.
- The module does not create a load balancer or public ingress. A workload owner must document
  business need, approval reference, source ranges, protocols, and ports in `public_lb_ingress`;
  the Platform Network/Security CODEOWNER verifies the approval before the plan is approved.
  The input is empty by default and its scope/evidence is returned in `public_lb_ingress_approvals`.
- VPC Flow Logs capture all traffic to the caller's approved central S3 destination. Encryption,
  bucket policy, access controls, and at least 90-day lifecycle are external prerequisites.

## Names, tags, and outputs

Names use `infra-spec-<environment>-<region>-<resource>[-<az-id>]`. Every taggable resource has
`Project`, `Environment`, `ManagedBy`, `Owner`, `CostCenter`, and `Name`; callers can add tags
without replacing these keys.

Outputs include VPC identity, AZ IDs, tier subnet IDs by AZ and in stable lists, tier route table
IDs, internet/NAT gateway IDs, endpoint IDs, default-deny load balancer/application/data security
group IDs, and declared network flow rule IDs. Consumers should use these named outputs rather
than derive subnet roles from list positions or CIDRs.

## Validation

Run `terraform fmt -check -recursive`, backend-free `terraform init -backend=false` and
`terraform validate`, `terraform test`, TFLint, and Checkov. An AWS plan additionally requires
confirmed account, Region, IPAM allocations, backend configuration, logging destination, owner,
cost center, and resource ownership. Do not apply until the plan and approval gates pass.
