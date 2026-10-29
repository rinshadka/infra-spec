# Implementation Plan: AWS Network Foundation

**Branch**: `001-network-foundation` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-network-foundation/spec.md`

## Summary

Build a reusable Terraform network module and a separate sandbox composition. The module accepts
the confirmed account and Region, IPAM-approved VPC and subnet CIDRs, environment metadata, AZ
selection, NAT policy, workload-declared endpoints, and explicit network flows. It returns stable
VPC, subnet, route, endpoint, and security-group outputs for ECS, EKS, RDS, and load-balancer
consumers. The first environment target and its account, Region, CIDRs, owner, and cost center remain
required external inputs; no deployable values are invented here.

## Technical Context

**Language/Version**: Terraform HCL; root CLI constraint `>= 1.12.0, < 2.0.0`. Reusable module
requires Terraform `>= 1.12.0`.

**Primary Dependencies**: HashiCorp AWS provider. The reusable module declares
`hashicorp/aws >= 6.0.0`; the sandbox root bounds it to `>= 6.0.0, < 7.0.0`. The root commits
`.terraform.lock.hcl`; select and review the exact provider version at implementation time. The
official release page showed AWS provider 6.70.0 on 2026-10-29.

**Storage**: Remote S3 state, in a separately bootstrapped and confirmed state account. Require
versioning, encryption, public-access blocking, TLS-only access, S3 lock files (`use_lockfile =
true`), and key-scoped IAM access. Use a distinct state key per environment and Region. Backend
bucket, key values, KMS key, state-account identity, and authorized roles are deployment inputs;
none are specified as existing resources.

**Testing**: Terraform native module tests; `terraform fmt -check`, `terraform init -backend=false`,
`terraform validate`, TFLint with Terraform and AWS rulesets, Checkov IaC security scanning, and a
reviewed environment `terraform plan`. No plan or apply is run as part of this design phase.

**Target Platform**: AWS VPC, IPv4-only, Amazon-provided DNS resolution and hostnames enabled.

**Project Type**: Reusable Terraform module plus an independently stateful sandbox root composition. Later environment roots are follow-on compositions and are not part of this feature's delivered source.

**Performance Goals**: No generic throughput, service latency, or workload RTO/RPO target is
assumed. All environments use at least two AZ IDs; production targets three where supported.
Sandbox/development/staging use shared NAT only when external egress is needed; production uses
per-AZ NAT when needed. NAT mode is an explicit root input with no module default.

**Constraints**: No fixed AWS account ID, Region, CIDR, IPAM pool, or pre-existing resource ownership
is assumed. Account ID, Region, IPAM-approved VPC/subnet CIDRs, `Owner`, and `CostCenter` are
required root inputs. The first deployment must stop until these and the remote-state backend have
been confirmed. Never configure credentials or secrets in Terraform source or committed variable
files. Existing resources are not imported until ownership is confirmed and an import plan is
reviewed.

**Scale/Scope**: This feature delivers one sandbox root and a reusable module. Each selected AZ has
public, private application, and private data subnets. The module supports disabled, shared, and
per-AZ NAT policies and workload-declared endpoints. Later environment roots use separate
configuration, state keys, and roles.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status and evidence |
|---|---|---|
| Security and data protection | Least privilege, private by default, no committed secrets | PASS — private app/data tiers, explicit public LB approval, scoped state access, no credentials or fixed identifiers in module inputs. |
| Terraform as source of truth | Managed changes use reviewed Terraform | PASS — module and root composition are the only ownership path; any emergency drift is reconciled through reviewed code. |
| Remote state protection | Encrypted remote state, locking, environment access boundaries | PASS — separately bootstrapped S3 backend with versioning, encryption, native lock files, and key-scoped IAM is a precondition. |
| Environment isolation | Separate configuration and state | PASS — independent root/state key for each environment and Region; sandbox is the first composition. |
| Private networking by default | Public access explicitly justified | PASS — public subnet outputs are available for approved edge use; workloads use private tiers and receive no public IPs. |
| Reliability and recovery | Appropriate AZs, backup, and recovery needs | PASS — at least two AZ IDs; production targets three where supported. Non-production shared NAT has a documented shared-AZ outage risk; production per-AZ NAT limits an AZ outage to that AZ's egress. Workload owners define RTO/RPO before workload implementation. |
| Evidence before apply | Format, validation, security scan, plan review | PASS — required checks and human plan review are defined; apply remains gated by environment approval. |
| Consistent governance | Naming, tags, documentation, approvals | PASS — lowercase kebab-case names and the five required tags are defined in the contract. |

No constitution violations require an exception. Exact account, Region, CIDRs, tag values, and state
backend details remain explicit deployment prerequisites rather than hidden defaults.

## Phase 0: Research

See [research.md](research.md) for decisions, alternatives, and primary-source references. Key
decisions are: a standalone reusable module called by the sandbox root; AWS provider major version
6 with module minimum and root upper bound; S3 state with native lock files; IPAM-approved explicit
CIDR inputs; workload-declared endpoints; and explicit route/security-flow contracts.

## Phase 1: Design and Contracts

### Module and Environment Boundaries

- `infra/modules/network` owns only the VPC, subnet tiers, route tables, internet/NAT gateways,
  selected VPC endpoints, tier security groups, and the explicitly declared network rules.
- `infra/live/sandbox/network` owns provider configuration, AWS account guard, selected Region,
  environment/tag values, backend configuration, remote state key, and module composition.
- The module does not create or adopt an IPAM service/pool, state bucket, KMS key, application
  workload, database, cluster, or load balancer. It consumes approved CIDRs and exposes placement
  and security-group outputs for those consumers.
- This feature creates the reusable module and sandbox root only. Development, staging, and
  production roots are follow-on compositions and MUST have separate state keys and environment
  roles when introduced.

### Typed Input and Output Contract

The detailed contract is in [contracts/network-module.md](contracts/network-module.md). Inputs are
typed, documented, and validated. Required CIDR inputs are supplied by organization IPAM; reviewers
verify allocation ownership and connected-network non-overlap. The module validates IPv4 syntax,
VPC containment, internal overlap, and capacity but does not prove IPAM approval.

### Naming and Tags

Use lowercase kebab-case `Name` tags in the form
`infra-spec-<environment>-<region>-<resource>[-<availability-zone>]`. The module does not include
account IDs or CIDRs in names. Apply `Project`, `Environment`, `ManagedBy`, `Owner`, and `CostCenter`
to every taggable managed resource. Set `Project=infra-spec` and `ManagedBy=Terraform` in the
environment composition; require environment, owner, and cost-center values as explicit inputs.
Additional tags may be merged only when they do not override required keys.

### State and Provider Configuration

- Use the separately managed S3 backend with partial backend configuration; do not commit bucket
  names, role ARNs, KMS key ARNs, or account-specific backend settings.
- Key pattern: `network/<environment>/<region>/terraform.tfstate`; the actual values are supplied
  by the environment deployment process.
- Provision the backend separately in an organization-controlled state/security account. Require S3
  versioning, SSE-KMS, bucket-owner-enforced ownership, all public access blocks, TLS-only bucket
  policy, and native lock files. Use environment-specific state roles and key-scoped state/lock
  permissions; production access must not include non-production state.
- Enable audit logging for state-object access and follow the organization backup policy for
  recoverable state versions/replicas; any replica Region and retention follow data-residency policy.
- Backend permissions are limited to `s3:ListBucket` with a prefix condition, `s3:GetObject` and
  `s3:PutObject` on that environment's state object, and `s3:GetObject`, `s3:PutObject`, and
  `s3:DeleteObject` on its `.tflock` object. Scope KMS encrypt/decrypt/data-key permissions to the
  designated backend key. Do not grant state-object delete permission to routine plan/apply roles.
- Enable `use_lockfile = true`; do not add a DynamoDB lock table for new roots because S3 locking is
  supported and the old DynamoDB backend lock option is deprecated.
- Require the environment root's expected account ID and configure the AWS provider's allowed
  account guard from that input. Use short-lived role credentials from the approved local or CI
  identity flow; never put access keys in `.tf` or `.tfvars` files.
- Human operators use the organization's federated workforce identity (such as IAM Identity Center)
  and assume environment-specific Terraform roles; do not use long-lived IAM user access keys.
- Untrusted PR static checks receive no AWS credentials. Authenticated plans run from a trusted,
  protected workflow via GitHub OIDC restricted by repository, branch, and protected environment.
  Use a read-only infrastructure role plus only the S3 state read and lock operations Terraform
  requires. Apply uses a separate role and protected approval. Plan artifacts are access controlled
  and short lived. Workflow jobs use minimal token permissions, grant `id-token: write` only to the
  authenticated plan/apply job that needs OIDC, pin GitHub Actions to full commit SHAs, and never
  use `pull_request_target` to run untrusted Terraform code with credentials.
- Recover a stale lock only after verifying its run/process is inactive and the lock belongs to this
  state key; record approval and use the Terraform lock ID. Never force-unlock by default. Restore a
  state object version only after comparing it with live infrastructure.
- Keep `provider` and `backend` configuration in the root. The child module declares its provider
  source/minimum version and accepts the configured provider from its caller.
- Pin the Terraform CLI to the declared compatibility range in CI/tooling. Commit a lock file for
  each root configuration, and update it only in a reviewed provider-upgrade change.

### Validation, Security, and Plan Gates

Run credential-free static checks in pull requests, in order:

1. `terraform fmt -check -recursive` over the module and root.
2. `terraform init -backend=false` followed by `terraform validate` for the module and root syntax.
3. Terraform native tests for subnet/AZ completeness, CIDR overlap and size checks, NAT mode route
   selection, explicit egress destinations, endpoint scoping, public-address defaults, default-deny
   tier flows, flow-log wiring, and NAT alarms.
4. TFLint with the Terraform ruleset and AWS ruleset; pin executable and plugin versions in CI.
5. Checkov against Terraform configuration; pin the scanner version. A suppression requires finding
   ID, resource scope, rationale, approver, and expiry/review date.
6. In a trusted protected workflow, run an authenticated plan with the confirmed account, Region, CIDR
   allocations, and remote backend. Review create/update/replace/destroy actions, route exposure,
   rule ports/sources, NAT cost and AZ dependency, state changes, and tags. Re-run the final plan
   after any change before approval.

Security gates include: no unapproved internet ingress; no direct workload public IP; no route from
private tiers to an internet gateway; no default security-group ingress or egress; database access
only through listed app-to-data flows; endpoint scope and policies reviewed; no credentials in
source or plans; no broad internet egress; and least-privilege IAM on AWS resources and remote-state
paths. AWS provisioning roles enumerate required actions and scope resource ARNs/conditions wherever
AWS supports them; avoid broad `*` resource permissions except documented APIs that require it.
Scanner results do not replace plan review. A suppression requires finding ID, scope, rationale,
approver, and expiry/review date.

### Egress, Resilience, and Operations Policy

- Require an explicit `nat_mode`; never create a paid NAT gateway through an implicit module
  default. Use `disabled` when endpoints/private connectivity satisfy workload needs. Shared NAT is
  the sandbox/development/staging profile only when public IPv4 egress is required. Production uses
  per-AZ NAT when external egress is required.
- Shared NAT lowers gateway count but creates cross-AZ processing and a single-AZ egress dependency.
  If its AZ fails, private egress in all AZs can fail. Per-AZ NAT improves AZ independence; egress
  may fail in the affected AZ while other AZs continue. Do not promise automatic failover.
- NAT gateways do not filter destination hostnames or services. Use least-privilege workload
  security-group egress declared as explicit destination CIDRs or managed prefix lists, protocols,
  ports, and rationale; reject universal `0.0.0.0/0` and `::/0` egress. Destination/domain filtering
  requires a separately approved AWS Network Firewall or proxy architecture, outside this module
  unless separately approved. Prefer private endpoints for AWS service destinations.
- Require at least two AZ IDs and target at least three in production where Region/workload support
  it. Inputs use explicit AZ IDs rather than account-specific letter names.
- Enable VPC Flow Logs for all traffic to an approved encrypted central S3 destination with at
  least 90-day retention. Destination ARN and operations owner are external prerequisites; retention
  is enforced by the logging platform lifecycle policy. For each NAT gateway, alarm on
  `ErrorPortAllocation` above zero for three consecutive five-minute periods, and use CloudWatch
  metric math to alarm on dropped packets above 0.01% of total packets for two of three one-minute
  periods. Notify an operations-owned SNS topic supplied to the root. Disabled NAT creates no NAT
  alarms; the platform operations team owns alert response.
- Workload owners set service RTO/RPO and backup/DR requirements in workload designs before
  implementation. This feature documents routing failure behavior and state recovery, not application
  service-level objectives.

### Public Exposure and Cost Review

- This module does not create load balancers. A workload PR requesting a public LB records the
  business need, approver/reference from the Platform Network/Security CODEOWNER, and exact source
  CIDRs, protocols, and ports. Branch protection requires that CODEOWNER approval; the organization
  must map this role to its approved team before enabling protected deployment. Direct public
  workload IPs remain prohibited.
- Each plan includes a Region/traffic-specific NAT and flow-log estimate reviewed by the environment
  CostCenter owner. Numeric budgets are externally supplied because Region, traffic, and budget
  authority are unknown.

Saved plans and state contain sensitive data. Do not commit them; store them only in approved,
access-controlled CI artifacts with a limited retention period.

### Migration and Rollback

1. Inventory the target account/Region and confirm the owner and management source of every existing
   VPC, subnet, route table, gateway, endpoint, and security group before any apply.
2. If no network exists, create a new VPC only after the IPAM ranges and state backend are approved.
   If resources exist, do not overwrite or recreate them. Select either a new isolated VPC or a
   separately reviewed adoption plan.
3. For approved adoption, write configuration matching the live resource first, use Terraform import
   blocks (or a documented state move when changing addresses), and review the import plan for zero
   unintended modifications before applying. Keep a protected state backup/version and record the
   ownership handover.
4. For route or security-rule changes, revert the reviewed configuration and create a fresh plan;
   apply only after approval. If state is damaged, restore a versioned state snapshot only after
   confirming it matches live resources. Do not use `terraform destroy` as the default rollback for
   shared networks; destructive removal requires a separately approved plan and dependency check.

### Quickstart

The implementation-phase validation guide is [quickstart.md](quickstart.md). It uses placeholders
for account, Region, IPAM allocations, owner, cost center, and backend settings. It does not contain
invented deployment values or invoke `apply`.

## Constitution Check (Post-Design)

| Gate | Status after design |
|---|---|
| Security and data protection | PASS — private-by-default routing, explicit flow rules, guarded account, credential-free source, least-privilege endpoint/state policies. |
| Terraform ownership | PASS — one module/root composition owns the new network; adoption requires verified ownership. |
| Remote state | PASS — S3 encryption/versioning/native locking and scoped access; actual backend must be provisioned and confirmed first. |
| Environment isolation | PASS — distinct root and key by environment/Region; sandbox only in first slice. |
| Private network default | PASS — no direct public workload IP; private application/data subnets and approved LB exposure. |
| Reliability and recovery | PASS — environment NAT profiles and failure domains documented; workload owners set RTO/RPO before workload implementation. |
| Quality gates | PASS — format, validate, tests, TFLint, Checkov, and reviewed plan required. |
| Governance | PASS — fixed naming form and required tags are in contract. |

**Open deployment prerequisites**: Confirm the sandbox AWS account ID and Region, IPAM-approved VPC
and subnet CIDRs, owner and cost-center tag values, state-backend location/role/KMS policy, central
flow-log destination and retention, existing resource ownership inventory, workload-specific
endpoint and flow declarations, and the production CostCenter approval path before a real plan or
apply. Also confirm the operations SNS topic and map the Platform Network/Security CODEOWNER role to
an approved organization team. Design choices are recorded above; workload RTO/RPO remain required
in workload specifications.

## Project Structure

### Documentation (this feature)

```text
specs/001-network-foundation/
├── plan.md
├── research.md
├── data-model.md
├── contracts/
│   └── network-module.md
└── quickstart.md
```

### Source Code (repository root)

```text
infra/
├── modules/
│   └── network/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── flow_logs.tf
│       ├── nat_alarms.tf
│       ├── README.md
│       └── tests/
│           ├── network_topology.tftest.hcl
│           ├── egress_endpoints.tftest.hcl
│           └── security_flows.tftest.hcl
└── live/
    └── sandbox/
        └── network/
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── versions.tf
            ├── backend.tf
            ├── sandbox.tfvars.example
            └── .terraform.lock.hcl

tests/
└── terraform/
    └── network/
```

**Structure Decision**: Follow the repository's existing separation of `infra/modules` for reusable
capabilities and `infra/live` for environment composition. The feature's first composition is
sandbox; later environments use separate roots and state while calling the same module.

## Complexity Tracking

No constitution violations or unnecessary architecture layers were identified.
