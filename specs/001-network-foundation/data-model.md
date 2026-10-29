# Data Model: AWS Network Foundation

This is the design-time model for a Terraform network module. It describes configuration objects,
not application data stored in AWS. Account, Region, CIDRs, and tag values are supplied at
environment composition and have no invented values here.

## Environment Network

One VPC and its routing boundary for a single environment and Region.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `aws_account_id` | string | Yes | Confirmed AWS account ID expected by the root provider; no default. |
| `aws_region` | string | Yes | AWS Region supplied by the environment; no default. |
| `environment` | string | Yes | One of `sandbox`, `development`, `staging`, or `production`. |
| `ipam_approval_reference` | string | Yes | Human-reviewed IPAM allocation/ticket reference; Terraform validates only that it is non-empty. |
| `vpc_cidr_block` | string | Yes | VPC CIDR explicitly approved by organization IPAM. |
| `availability_zone_ids` | set(string) | Yes | At least two explicit AZ IDs valid in the selected Region; target three in production where supported. |
| `subnet_cidrs_by_az` | map(object) | Yes | Every selected AZ has exactly `public`, `application`, and `data` CIDRs. |
| `tags` | object | Yes | Required governance tags are present; additional tags cannot override them. |
| `name_prefix` | string | Derived | Lowercase kebab-case `<project>-<environment>-<region>`. |

The sandbox root configures provider identity and backend. It uses the expected `aws_account_id` to
guard the provider but does not pass the account ID to the child module. Authorization comes from
the caller's short-lived AWS role.

## Subnet Tier

One CIDR allocation associated with exactly one AZ and one functional tier.

| Field | Type | Rules |
|---|---|---|
| `tier` | enum | `public`, `application`, or `data`. |
| `availability_zone_id` | string | Must be a member of `availability_zone_ids`. |
| `cidr_block` | string | Must be inside the VPC CIDR, valid for IPv4, large enough for AWS reservations, and non-overlapping with all other subnet allocations. |
| `route_policy` | derived | Public routes to the internet gateway; private app/data routes use the selected NAT policy where enabled and have no direct internet gateway route. |
| `auto_assign_public_ipv4` | boolean | False for all subnet tiers; no public IPv4 addresses are assigned directly to workload network interfaces. |

## Egress Policy

Environment-level policy controlling private subnet internet egress.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `mode` | enum | Yes | Required explicit choice: `disabled`, `shared`, or `per_az`; no module default. Non-production uses shared only when needed; production uses per-AZ when needed. |
| `nat_subnet_tier` | enum | Derived | NAT gateways use public subnets. |
| `route_associations` | map | Derived | Private subnet route tables use only NAT gateways selected by `mode`. |

`shared` uses one NAT gateway for the VPC. `per_az` maps private subnet egress to a NAT gateway in
the same AZ. `disabled` creates no NAT gateway or NAT default route. Shared mode has a common zonal
failure dependency and cross-AZ transfer cost. NAT does not filter destinations; use explicit
workload egress rules and a separately approved firewall/proxy when destination filtering is needed.

## Service Endpoint

An optional endpoint declaration per workload/environment, absent from the platform baseline unless
a workload requests it.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `service_name` | string | Yes | AWS service endpoint name valid in the selected Region. |
| `type` | enum | Yes | `gateway` or `interface`; supported service/type combinations only. |
| `subnet_tiers` | set(enum) | Conditional | Exactly one private tier for an interface endpoint; AWS permits one endpoint subnet per AZ. |
| `route_table_tiers` | set(enum) | Conditional | Required for gateway endpoints; only route tables needing the service path. |
| `workload_tiers` | set(enum) | Conditional | Workload security groups allowed to use the endpoint; only `application` or `data`. |
| `policy_json` | string | Required where supported | Reviewed least-privilege policy for the service/type. |

Endpoint policies are an additional control; IAM and service resource policies remain independently
required. Only endpoint-backed SG egress to the endpoint SG or gateway prefix list is generated; it
does not exist without the endpoint. An endpoint that is unavailable in the Region fails planning.
VPC Flow Logs are a separate
all-traffic operational record delivered to an approved encrypted central destination with at least
90-day retention.

## Flow Log Delivery

One VPC-level subscription that captures accepted and rejected IP traffic.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `destination_arn` | string | Yes | Approved central S3 destination; supplied by the logging platform owner. |
| `traffic_type` | enum | Yes | `ALL`; captures accepted and rejected traffic. |
| `encryption` | policy | Yes | Destination encrypts stored records; the logging platform owns its KMS configuration. |
| `retention_days` | number | Yes | At least 90 days, enforced by the central logging destination lifecycle policy. |
| `operations_owner` | string | Yes | Platform team responsible for access, retention, and consuming the records. |

## NAT Metric Alarm

One alarm pair per NAT gateway; absent when NAT mode is disabled.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `metric_name` | enum | Yes | `ErrorPortAllocation` or dropped-packet ratio from `PacketsDropCount` divided by total packet count. |
| `threshold` | number | Yes | Port allocation: greater than zero. Dropped-packet ratio: greater than 0.01%. |
| `evaluation_periods` | number | Yes | Port allocation: three consecutive five-minute periods. Dropped-packet ratio: two of three one-minute periods. |
| `notification_topic_arn` | string | Yes | Operations-owned SNS topic supplied as an environment input. |

Operations uses CloudWatch NAT metrics alongside VPC Flow Logs. When NAT is disabled, no NAT alarms
are created.

## Network Flow Rule

An explicitly allowed stateful flow between a declared workload tier's security groups.

| Field | Type | Rules |
|---|---|---|
| `name` | string | Unique stable key within the environment. |
| `source_tier` | enum | `load_balancer`, `application`, or `data`. |
| `destination_tier` | enum | `load_balancer`, `application`, or `data`. |
| `protocol` | enum | `tcp` or `udp`; no wildcard all-protocol rule. |
| `from_port` / `to_port` | number | Valid ordered port range for the selected protocol. |
| `description` | string | Required rationale/workload reference for review. |

Tier security groups have no default ingress or egress rules. No flow exists unless present in the
input list. Public internet ingress is outside the flow rule's implicit behavior and requires a
workload change with documented approval, source CIDRs, protocols, and ports for a public load
balancer.

## Public Load-Balancer Ingress Approval

Optional ingress declaration for a workload-owned public load balancer. No ingress exists when
the declaration is empty.

| Field | Type | Rules |
|---|---|---|
| `business_need` | string | Required service rationale. |
| `approval_reference` | string | Required change/security record reference; Platform Network/Security CODEOWNERS verify it. |
| `source_cidr_blocks` | set(string) | Exact canonical IPv4 sources, one rule per CIDR. |
| `protocol` / `from_port` / `to_port` | enum / number | Explicit TCP/UDP protocol and valid port range. |
| `description` | string | Required rationale attached to the security-group rule. |

The module records this evidence in `public_lb_ingress_approvals` and creates only the declared
rules on its load-balancer security group. It does not create the load balancer itself.

## Allowed Egress Rule

An explicitly permitted outbound path from a workload tier to a stable external IPv4 destination.

| Field | Type | Rules |
|---|---|---|
| `name` | string | Unique stable key within the environment. |
| `source_tier` | enum | `application` or `data`; public edge ingress is handled separately. |
| `destination_cidr_blocks` | set(string) | Explicit approved IPv4 ranges; cannot contain `0.0.0.0/0`. |
| `prefix_list_ids` | set(string) | Optional approved AWS-managed or customer-managed prefix lists. |
| `protocol` | enum | `tcp` or `udp`; no wildcard all-protocol rule. |
| `from_port` / `to_port` | number | Valid ordered port range for the protocol. |
| `description` | string | Required workload need and review rationale. |

At least one destination CIDR or prefix list is required. Dynamic hostname destinations use an AWS
service endpoint or separately approved firewall/proxy, not broad security-group egress.

## Governance Tags

The module requires `Project`, `Environment`, `ManagedBy`, `Owner`, and `CostCenter` string values.
The root sets `Project` to `infra-spec`, `ManagedBy` to `Terraform`, and derives `Environment` from
its explicit input. `Owner` and `CostCenter` are required deployment values. All taggable managed
network resources receive these tags.

## Remote State Boundary

Each root configuration has one remote S3 state object keyed by environment and Region. The state
backend owns no VPC entities; it is a separate bootstrap lifecycle. S3 versioning, SSE-KMS,
bucket-owner-enforced ownership, public-access blocking, TLS-only access, native locking, and scoped
environment-role access protect state and lock objects. Restore a prior version only after checking
it against live resources; verify stale-lock ownership before a reviewed recovery.
