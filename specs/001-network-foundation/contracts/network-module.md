# Network Module Contract

**Module path**: `infra/modules/network`

This contract is for the reusable network child module and its environment caller. The module does
not configure credentials, AWS account selection, provider Region, backend, or public load balancers.
The root composition supplies the provider and checks the expected account.

## Root Composition Inputs

| Name | Terraform type | Required/default | Contract |
|---|---|---|---|
| `aws_account_id` | `string` | Required; no default | Confirmed account ID. Root AWS provider restricts operations to this ID. Not a credential. |
| `aws_region` | `string` | Required; no default | Region for provider and network; no fixed project-wide Region. |
| `environment` | `string` | Required; no default | `sandbox`, `development`, `staging`, or `production`; one state per environment and Region. |
| `owner` | `string` | Required; no default | Value for the `Owner` tag. |
| `cost_center` | `string` | Required; no default | Value for the `CostCenter` tag. |
| `backend_config` | protected partial backend settings | Required before init/plan | Bucket, key, Region, role, and KMS settings supplied out of band; never checked into source. S3 versioning, SSE-KMS, public-access blocks, TLS-only policy, and key-scoped IAM are prerequisites. |

The root requires IPAM-approved VPC and subnet CIDRs as configuration. Actual account, Region,
CIDRs, owner, cost center, and backend settings are not supplied in this specification.

## Child Module Inputs

| Name | Terraform type | Required/default | Validation |
|---|---|---|---|
| `environment` | `string` | Required | One of the supported environment names; used in names/tags. |
| `ipam_approval_reference` | `string` | Required | IPAM allocation/ticket reference carried into the deployment review record; Terraform checks non-empty only, and the reviewer verifies ownership/approval. |
| `vpc_cidr_block` | `string` | Required | Valid IPv4 CIDR approved by organization IPAM. |
| `availability_zone_ids` | `set(string)` | Required | At least two unique AZ IDs available in the caller's Region; production target is three where supported. AZ IDs avoid account-specific name mapping. |
| `subnet_cidrs_by_az` | `map(object({ public = string, application = string, data = string }))` | Required | Keys exactly match selected AZs; all ranges are valid, within the VPC, non-overlapping, and large enough for AWS-reserved addresses. |
| `nat_mode` | `string` | Required; no default | One of `disabled`, `shared`, or `per_az`; environment composition selects explicitly. Non-production uses shared only when needed; production uses per-AZ when needed. |
| `endpoint_configs` | `map(object({ service_name = string, type = string, subnet_tiers = set(string), route_table_tiers = set(string), workload_tiers = set(string), policy_json = string }))` | `{}` | Only declared endpoints; type must be valid in Region; interface endpoints select exactly one private subnet tier (one subnet per AZ), gateway endpoints select private route-table tiers, and all endpoints select workload tiers. Require valid reviewed least-privilege JSON policy and verify service availability during plan. |
| `allowed_flows` | `list(object({ name = string, source_tier = string, destination_tier = string, protocol = string, from_port = number, to_port = number, description = string }))` | `[]` | Explicitly list valid source/destination tiers, `tcp`/`udp` protocol, port range, and rationale; create scoped ingress and egress rules. Security groups have no default allow rules. |
| `public_lb_ingress` | `list(object({ name = string, business_need = string, approval_reference = string, source_cidr_blocks = set(string), protocol = string, from_port = number, to_port = number, description = string }))` | `[]` | Empty by default. Each declared public-facing load-balancer ingress rule must include exact canonical IPv4 source ranges, protocol/ports, business need, and reviewer-verifiable approval reference; it adds only that ingress to the module-owned LB security group. Reviewers verify approval through CODEOWNERS. |
| `allowed_egress` | `list(object({ name = string, source_tier = string, destination_cidr_blocks = set(string), prefix_list_ids = set(string), protocol = string, from_port = number, to_port = number, description = string }))` | `[]` | Explicit IPv4 CIDR or managed prefix-list destinations; require `tcp`/`udp`, port range, and rationale. Reject `0.0.0.0/0` and `::/0`; DNS hostname filtering requires approved firewall/proxy. |
| `flow_log_destination_arn` | `string` | Required | Approved central S3 destination for all-traffic VPC Flow Logs; destination encryption and 90-day lifecycle are verified before plan. |
| `flow_log_operations_owner` | `string` | Required | Operations team responsible for the log destination, retention policy, and consuming records. |
| `nat_alarm_topic_arn` | `string` | Required when `nat_mode` is not `disabled` | Operations-owned SNS topic; receives alarms for `ErrorPortAllocation` Maximum above zero for three five-minute periods and dropped-packet ratio above 0.01% for two of three one-minute periods. |
| `tags` | `object({ Project = string, Environment = string, ManagedBy = string, Owner = string, CostCenter = string })` | Required | All five keys non-empty; caller may add tags only without overriding required keys. |
| `additional_tags` | `map(string)` | `{}` | Optional; merge only where keys do not conflict with required governance tags. |

The child module has no `region`, `account_id`, credential, `ipv6_enabled`, or public-IP assignment
input. The caller's provider selects account and Region; IPv6 and workload public IPs are disabled
by the accepted feature requirements.

## Outputs

| Output | Type/shape | Consumer use |
|---|---|---|
| `vpc_id` | `string` | ECS/EKS/RDS/load-balancer VPC association. |
| `vpc_cidr_block` | `string` | Address and routing documentation. |
| `availability_zone_ids` | `set(string)` | Zone placement and topology awareness. |
| `public_subnet_ids_by_az` | `map(string)` | Public load balancer placement, only after documented approval. |
| `private_application_subnet_ids_by_az` | `map(string)` | ECS tasks and EKS node/workload placement. |
| `private_data_subnet_ids_by_az` | `map(string)` | RDS subnet group and private data placement. |
| `public_subnet_ids` | `list(string)` | Consumers needing the flattened public subnet list. |
| `private_application_subnet_ids` | `list(string)` | ECS/EKS consumers needing a flattened application list. |
| `private_data_subnet_ids` | `list(string)` | RDS consumers needing a flattened data subnet list. |
| `public_route_table_ids` | `map(string)` | Network troubleshooting and route inspection. |
| `private_application_route_table_ids` | `map(string)` | Private application routing inspection. |
| `private_data_route_table_ids` | `map(string)` | Private data routing inspection. |
| `internet_gateway_id` | `string` | Public edge route association and inspection. |
| `nat_gateway_ids_by_az` | `map(string)` | Egress topology inspection; one element for shared mode or one per selected AZ for per-AZ mode; empty when disabled. |
| `vpc_endpoint_ids_by_service` | `map(string)` | Workload endpoint references. |
| `load_balancer_security_group_id` | `string` | Explicitly approved LB-to-application connectivity. |
| `application_security_group_id` | `string` | ECS/EKS workload attachment and explicit flows. |
| `data_security_group_id` | `string` | RDS attachment and explicit inbound app flows. |
| `network_flow_rule_ids` | `map(string)` | Rule traceability and security review. |
| `public_lb_ingress_approvals` | `map(object)` | Review record of declared public ingress need, approval reference, sources, protocol, and ports. |
| `ipam_approval_reference` | `string` | Human-reviewed IPAM allocation/ticket reference used for the plan. |

All outputs are stable named values; callers must not infer tier identity from subnet order or
reconstruct security boundaries from CIDRs.

## Naming and Tags Contract

`Name` values use lowercase kebab-case:

```text
infra-spec-<environment>-<region>-<resource>[-<availability-zone>]
```

Do not embed account IDs or CIDRs in names. Every taggable resource receives:

```text
Project     = infra-spec
Environment = <environment>
ManagedBy   = Terraform
Owner       = <required caller value>
CostCenter  = <required caller value>
```

## Security and Ownership Contract

- Workloads receive no public IP addresses. Public subnets are exposed only as placement outputs;
  they do not constitute approval to create public-facing workloads.
- The network module does not create load balancers. `public_lb_ingress` is empty by default. A
  workload change requesting public load-balancer ingress records business need, approval
  reference, allowed source CIDRs, protocols, and ports; the reviewed plan must show only that
  ingress. Platform Network/Security CODEOWNERS verify the approval reference.
- No application-to-data rule is created unless it appears in `allowed_flows`.
- Ingress and egress are denied by default at tier security groups. Endpoint policies, IAM
  permissions, and service resource policies are reviewed together. Endpoint policies do not grant
  permissions omitted by IAM.
- Internet egress is permitted only by `allowed_egress` declarations with explicit destinations,
  protocol, port, and rationale. Universal destination ranges are rejected.
- NAT provides IPv4 translation and a route; it does not filter destinations. Destination/domain
  filtering requires a separately approved firewall/proxy path.
- Flow-log destination ownership, encryption, and retention are verified before plan; the module
  does not assume or manage an existing central logging bucket.
- The module creates only resources in its documented ownership boundary. It does not discover,
  import, replace, or modify pre-existing resources without an approved ownership/adoption plan.
