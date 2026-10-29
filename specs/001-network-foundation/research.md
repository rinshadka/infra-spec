# Research: AWS Network Foundation

**Date**: 2026-10-29

Research used primary Terraform/HashiCorp, AWS, and tool-maintainer documentation. No deployment
values or existing resource ownership were inferred.

## Decisions

### Terraform and AWS Provider Constraints

- The network child module declares `hashicorp/aws >= 6.0.0` and a Terraform CLI minimum of
  `>= 1.12.0`. Reusable modules declare minimum compatibility rather than an upper provider bound.
- The sandbox root constrains Terraform to `>= 1.12.0, < 2.0.0` and the AWS provider to
  `>= 6.0.0, < 7.0.0`. On 2026-10-29, the provider's release page showed 6.70.0 (released October
  21); the exact version selected during implementation is recorded and checksummed in the root
  `.terraform.lock.hcl`.
- Provider upgrades are explicit reviewed changes using `terraform init -upgrade`, followed by
  validation, security scans, and plan review. Do not set a root provider version to `latest` or
  commit generated provider binaries.

**Rationale**: The major-version ceiling reduces unexpected provider breaking changes while allowing
reviewed 6.x updates. Child-module minimum-only constraints permit reuse by other roots. The lock
file makes a selected provider build repeatable.

**Alternatives considered**: Exact provider version in both module and root (overly restrictive for
the reusable module); unconstrained provider (unreviewed major upgrades possible); omit the lock file
(non-repeatable provider selection).

### Module and Environment Composition

- Keep `infra/modules/network` provider-agnostic with respect to account, Region, credentials, and
  backend. It declares provider requirements, typed inputs, resource logic, and stable outputs.
- Keep provider configuration, expected-account guard, backend, environment metadata, and module
  invocation in `infra/live/sandbox/network`.
- Build subnet allocations from explicit IPAM-approved ranges keyed by selected AZ. The module does
  not own an IPAM pool or silently derive unapproved ranges.

**Rationale**: HashiCorp recommends a shallow reusable module structure and a caller-provided
provider configuration. This keeps reusable network logic independent of environment credentials
and lifecycle.

**Alternatives considered**: Put all resources in the sandbox root (duplicates reusable network
logic); configure credentials/provider inside the child module (couples it to one environment).

### Provider and Tool Version Handling

- A root module sets a lower and upper AWS provider bound; the child module sets the supported
  minimum. Terraform CLI is separately constrained with `required_version`.
- Commit `.terraform.lock.hcl` for the sandbox root and retain the exact selected provider checksums.
- Pin TFLint, its AWS ruleset, Checkov, and Terraform CLI in CI to reviewed versions. Scanner upgrades
  are reviewed separately from infrastructure behavior changes.

**Rationale**: Terraform's lock file records provider selection/checksums; version constraints
declare compatibility, not the actual selected build.

**Alternatives considered**: Treat the lock file as a substitute for constraints (it does not express
compatibility policy); float CI scanner versions (scan results can change without a repository
change).

### Remote State

- Use the HashiCorp S3 backend with S3-native `use_lockfile = true`; do not add new DynamoDB-based
  locking because HashiCorp documents that option as deprecated.
- The separately managed backend must have versioning, encryption, public access blocked, TLS-only
  access, and IAM restricted to the state key and `.tflock` object for the relevant environment.
- Keep state account, bucket, KMS key, role, and backend configuration outside reusable module code
  and supply backend settings through a protected deployment configuration.
- Use a distinct state key for each environment and Region. CLI workspaces are not the sole
  production isolation boundary.
- Provision state storage in a separately managed organization state/security account. Require
  SSE-KMS, S3 versioning, bucket-owner-enforced ownership, blocked public access, TLS-only access,
  and environment/key-scoped roles. Production authorization cannot read non-production state.
- Use protected GitHub OIDC roles for trusted plans, no AWS credentials for untrusted PR static
  checks, and a separate apply role with environment approval. Stale-lock recovery requires
  verifying the run is inactive, reviewing the lock ID, and recording approval; do not force-unlock
  by default.
- Human operators use federated workforce identity and short-lived environment role sessions, not
  long-lived IAM user keys. Backend IAM grants prefix-scoped list, state get/put, lock get/put/delete,
  and KMS operations on the designated key; routine roles cannot delete state objects.

**Rationale**: State is sensitive and must be recoverable and locked against concurrent writers.
Separating backend lifecycle avoids a bootstrap dependency where the network stack must create the
bucket that stores its own state.

**Alternatives considered**: Local state (not shared/recoverable); workspace-only production
separation (insufficient access boundary); new DynamoDB lock table (deprecated backend mechanism).

### Network Topology and Address Ownership

- Deliver only the reusable module and sandbox root in this feature. Later environment roots have
  independent configuration, state keys, and role boundaries.
- Use at least two explicitly supplied AZ IDs; target three AZs in production where Region and
  workload support it. AZ IDs avoid account-specific letter-name mappings.
- Require explicit NAT mode with no module default. Use shared NAT for sandbox/development/staging
  only when external egress is needed; use per-AZ NAT for production when it is needed; disable NAT
  when endpoints/private connectivity satisfy the workload.
- Treat NAT as routing/address translation, not destination filtering. Require least-privilege
  workload security-group egress to explicit destination CIDRs or managed prefix lists, protocols,
  and ports; reject universal destinations. Destination/domain filtering uses a separately approved
  AWS Network Firewall or proxy path and is outside this module's default scope.
- Require IPAM allocations as inputs and reviewer verification of ownership/non-overlap with
  connected networks. Module validation checks syntax, containment, overlap, and capacity but does
  not prove IPAM ownership.
- Keep IPv4-only, Amazon DNS resolution/hostnames, private workloads, and no direct workload public
  IPs. A public LB belongs to the workload root and its reviewed change records approver/reference,
  source CIDRs, protocols, and ports.
- Enable all-traffic VPC Flow Logs to an approved encrypted central S3 destination with at least
  90-day retention. Alarm per NAT gateway on `ErrorPortAllocation` >0 for three consecutive
  five-minute periods, following AWS's alarm example. Alarm on `PacketsDropCount` ratio >0.01% for
  two of three one-minute periods; the AWS docs identify 0.01% as a possible service issue and the
  two-of-three window is our noise-reduction baseline. The environment supplies the operations-owned
  SNS topic.
  Workload owners define RTO/RPO before critical workload deployment.

**Rationale**: AWS documents that a shared NAT AZ outage can remove egress for resources in other AZs
that depend on it, while same-AZ NAT improves isolation and reduces cross-AZ transfer at additional
gateway cost. AWS recommends AZ IDs for cross-account consistency. AWS guidance treats NAT and
destination filtering as separate controls, and recommends workload security-group egress, VPC
endpoints, and firewall/proxy controls where needed. Flow Logs provide network-level visibility but
not application-layer hostnames.

**Alternatives considered**: A shared NAT default in production (lower cost, but unacceptable
shared-AZ egress dependency); enabling costly Network Firewall in every VPC without a declared
filtering requirement; using AZ letter names across accounts; guessing IPAM ranges or logging
destinations; assigning application RTO/RPO centrally without knowing workload criticality.

### VPC Endpoint Policy

- Do not install a platform-wide endpoint baseline. Each workload/environment declares endpoint
  services and eligible subnet/SG scope.
- Require endpoint type and service name. For interface endpoints, specify subnet placement and
  security groups. For gateway endpoints, specify route-table associations. Require an explicit
  reviewed endpoint policy where supported; any use of the AWS full-access default policy needs
  documented approval. Endpoint policy is an additional control and does not replace IAM or the
  service resource policy.

**Rationale**: The specification intentionally avoids unnecessary endpoints and lets workload needs
drive the set. Endpoint type determines the path and required scope; policy and IAM controls must be
reviewed together.

**Alternatives considered**: Always provision S3/ECR/Logs/SSM endpoints (could create endpoints with
no consumer and extra cost); send all AWS API traffic through NAT (unnecessary public routing).

### Validation, Security Scanning, and Plan Review

- Use `terraform fmt -check`, `terraform validate`, and native `terraform test` for module behavior.
- Use TFLint with its Terraform and AWS rulesets for language/provider-specific issues.
- Use Checkov for static AWS Terraform misconfiguration/security checks; pin the tool. Every
  suppression records finding ID, resource scope, rationale, approver, and expiry/review date.
- Run an authenticated `terraform plan` only after account, Region, IPAM ranges, state backend,
  ownership status, and workload flows/endpoints are confirmed. Review route/rule changes, public
  exposure, replacements/destroys, NAT cost/availability, and state impact before apply approval.

**Rationale**: Terraform formatting/validation checks configuration shape; a plan evaluates proposed
changes against target state; static security tools catch known misconfiguration patterns. None of
these replaces human review of the plan.

**Alternatives considered**: `validate` alone (does not evaluate remote objects or actual values);
several overlapping security scanners at once (noise and duplicate findings); auto-apply after a
successful plan (violates the constitution's review/approval gate).

### Public Exposure, Cost, and Workflow

- Every plan includes a Region/traffic-specific NAT and flow-log estimate reviewed by the
  environment CostCenter owner. Numeric budget limits are owner-provided.
- Public load balancers are created by workload roots. A public-facing change records business need,
  approver/reference, allowed source CIDRs, protocols, and ports.
- Static checks run without AWS credentials on untrusted PRs. Trusted authenticated plans use
  protected GitHub OIDC, a read-only infrastructure role with narrow state/lock access, and a
  separate apply role behind protected environment approval. Plan artifacts are short lived and
  access controlled.

### Existing Resource Adoption and Rollback

- Before planning changes, inventory the account/Region and confirm the authoritative owner of each
  network resource. Unknown ownership blocks adoption.
- Prefer a new isolated VPC if existing network ownership or state cannot be confirmed.
- For explicitly approved adoption, use import blocks with configuration matching live resources;
  review the import plan and only proceed if no unintended updates/replacements appear. Use `moved`
  blocks for address refactors; use `terraform state mv` only as a documented fallback.
- For configuration changes, revert source and generate a new plan. Restore versioned state only
  after checking it matches live resources. Do not use destroy as the routine network rollback.

**Rationale**: Terraform must not accidentally claim or recreate manually managed resources, and
restoring old state without checking live infrastructure can increase drift.

**Alternatives considered**: Import every discovered resource automatically (ownership is not
confirmed); force-recreate on mismatch (risk of outage/data-plane disruption); overwrite state with
an old snapshot without a live-resource comparison.

## Primary Sources

- HashiCorp, [Provider requirements and version constraints](https://developer.hashicorp.com/terraform/language/providers/requirements)
- HashiCorp, [Providers within modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
- HashiCorp, [Terraform version constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
- HashiCorp, [Dependency lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- HashiCorp, [S3 backend and state locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- HashiCorp, [Terraform module development](https://developer.hashicorp.com/terraform/language/modules/develop)
- HashiCorp, [Format and validate Terraform configuration](https://developer.hashicorp.com/terraform/cli/code)
- HashiCorp, [Plan command](https://developer.hashicorp.com/terraform/cli/commands/plan)
- HashiCorp, [Import resources](https://developer.hashicorp.com/terraform/language/import/single-resource)
- HashiCorp, [Move resources in state](https://developer.hashicorp.com/terraform/cli/state/move)
- AWS, [NAT gateway basics](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-basics.html)
- AWS, [Availability Zone IDs](https://docs.aws.amazon.com/global-infrastructure/latest/regions/az-ids.html)
- AWS, [Secure outbound network traffic guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-outbound-network-traffic/introduction.html)
- AWS, [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- AWS, [NAT gateway metrics](https://docs.aws.amazon.com/vpc/latest/userguide/metrics-dimensions-nat-gateway.html)
- AWS, [Create NAT gateway CloudWatch alarms](https://docs.aws.amazon.com/vpc/latest/userguide/creating-alarms-nat-gateway.html)
- AWS, [GitHub OIDC role trust guidance](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)
- AWS, [Amazon VPC IPAM](https://docs.aws.amazon.com/vpc/latest/ipam/)
- AWS, [Create a VPC using an IPAM pool](https://docs.aws.amazon.com/vpc/latest/ipam/create-vpc-ipam.html)
- AWS, [Amazon DNS concepts](https://docs.aws.amazon.com/vpc/latest/userguide/AmazonDNS-concepts.html)
- AWS, [VPC endpoint policies](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html)
- TFLint maintainers, [TFLint and AWS ruleset](https://github.com/terraform-linters/tflint-ruleset-aws)
- Checkov maintainers, [Checkov overview](https://github.com/bridgecrewio/checkov/blob/main/docs/1.Welcome/What%20is%20Checkov.md)
