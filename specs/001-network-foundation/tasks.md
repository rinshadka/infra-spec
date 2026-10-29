# Tasks: AWS Network Foundation

**Input**: Design documents from `specs/001-network-foundation/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/network-module.md](contracts/network-module.md),
[quickstart.md](quickstart.md)

**Tests**: Terraform native module tests are included because the implementation plan and
quickstart require them. Fixtures use synthetic CIDRs only and are never deployment inputs.

**Organization**: Tasks follow the three P1 stories; foundational design decisions are recorded,
while deployment-specific prerequisites remain explicit inputs.

## Format: `[ID] [P?] [Story?] Description with file path`

- `[P]` means independent files and satisfied prerequisites permit parallel work.
- User-story tasks carry `[US1]`, `[US2]`, or `[US3]`; setup, foundational, and polish tasks do not.

## Phase 1: Setup

**Purpose**: Establish planned Terraform and documentation locations.

- [X] T001 Create module, sandbox root, tests, workflow, and operations documentation directories at `infra/modules/network/`, `infra/live/sandbox/network/`, `infra/modules/network/tests/`, `.github/workflows/`, and `docs/operations/`.
- [X] T002 [P] Ignore Terraform state, plans, caches, and local variable files while retaining `*.tfvars.example` in `.gitignore`.

## Phase 2: Foundational Decisions and Prerequisites

**Purpose**: Resolve design gaps and establish safe, account-guarded remote state before network resource implementation.

**Decision status**: T003–T010 record the adopted design choices. They do not supply deployment-specific values. Do not run an authenticated plan until account, Region, IPAM ranges, backend, logging destination, and ownership are confirmed.

- [X] T003 Record environment-specific AZ/NAT profiles, outage behavior, and the workload-owned RTO/RPO requirement in `specs/001-network-foundation/spec.md` and `specs/001-network-foundation/plan.md`.
- [X] T004 Limit this feature's delivered composition to sandbox while requiring separate later environment roots/state; align FR-016 and scope in `specs/001-network-foundation/spec.md` and `specs/001-network-foundation/plan.md`.
- [X] T005 Define NAT as routing only, require explicit NAT mode and least-privilege SG egress, and require separately approved firewall/proxy filtering for destination controls in `specs/001-network-foundation/spec.md`, `specs/001-network-foundation/plan.md`, and `specs/001-network-foundation/contracts/network-module.md`.
- [X] T006 Require explicitly supplied AZ IDs, at least two everywhere, and target three in production where supported in `specs/001-network-foundation/spec.md`, `specs/001-network-foundation/plan.md`, and `specs/001-network-foundation/contracts/network-module.md`.
- [X] T007 Require all-traffic VPC Flow Logs to a supplied encrypted central destination with at least 90-day retention and operational ownership in `specs/001-network-foundation/spec.md` and `specs/001-network-foundation/plan.md`.
- [X] T008 Record workload-owned public LB approval evidence and exact source/protocol/port boundaries in `specs/001-network-foundation/spec.md`, `specs/001-network-foundation/contracts/network-module.md`, and `specs/001-network-foundation/plan.md`.
- [X] T009 Require a Region/traffic-specific NAT and Flow Logs estimate reviewed by the environment CostCenter owner; leave numeric budget limits owner-supplied in `specs/001-network-foundation/plan.md` and `specs/001-network-foundation/quickstart.md`.
- [X] T010 Define credential-free static PR checks and protected OIDC authenticated plan/apply roles with separate approval in `specs/001-network-foundation/plan.md` and `specs/001-network-foundation/quickstart.md`.
- [X] T011 [P] Declare reusable module Terraform `>= 1.12.0` and AWS provider `>= 6.0.0` constraints in `infra/modules/network/versions.tf`.
- [X] T012 [P] Declare root Terraform `>= 1.12.0, < 2.0.0` and AWS provider `>= 6.0.0, < 7.0.0` constraints in `infra/live/sandbox/network/versions.tf`.
- [X] T013 Configure required target account, Region, environment, Owner, and CostCenter inputs and an AWS allowed-account guard in `infra/live/sandbox/network/variables.tf` and `infra/live/sandbox/network/providers.tf`.
- [X] T014 Configure partial S3 backend with `use_lockfile = true`, without embedded bucket, role, KMS, or account-specific values, in `infra/live/sandbox/network/backend.tf`.
- [X] T015 Add a non-deployable example listing required sandbox inputs without invented account IDs, Region, CIDRs, owner, cost center, or backend values in `infra/live/sandbox/network/sandbox.tfvars.example`.

**Checkpoint**: Decision gaps are resolved in the source artifacts; tool constraints and deployment guards exist. No AWS resources have been created.

## Phase 3: User Story 1 - Establish an Isolated Environment Network (P1)

**Goal**: Create a validated IPv4 VPC with public, private application, and private data subnets in each selected AZ; private tiers have no direct internet-gateway route.

**Independent test**: Synthetic inputs prove subnet completeness per selected AZ, reject invalid/overlapping/out-of-VPC/undersized CIDRs, and show no private internet-gateway routes or workload public-IP assignment.

### Tests

- [X] T016 [US1] Write Terraform tests for AZ-ID/subnet completeness, minimum AZ count, CIDR containment/overlap/capacity, DNS settings, required tags, no public-IP assignment, and all-traffic flow-log destination configuration in `infra/modules/network/tests/network_topology.tftest.hcl`.

### Implementation

- [X] T017 [US1] Define typed environment, human-reviewed IPAM reference, VPC CIDR, explicit `availability_zone_ids`, subnet-by-AZ, flow-log destination/operations owner, and tag inputs; validate AZ keys and all three subnet tiers, IPv4 syntax, VPC containment, non-overlap, and capacity in `infra/modules/network/variables.tf` and `infra/modules/network/locals.tf`.
- [X] T018 [US1] Define lowercase kebab-case resource naming and merge required `Project`, `Environment`, `ManagedBy`, `Owner`, and `CostCenter` tags without permitting overrides in `infra/modules/network/locals.tf`.
- [X] T019 [US1] Create IPv4-only VPC with Amazon DNS resolution and hostnames enabled and no default public addressing in `infra/modules/network/main.tf`.
- [X] T020 [US1] Create public, private application, and private data subnets per selected AZ from supplied approved CIDRs with public IPv4 auto-assignment disabled in `infra/modules/network/subnets.tf`.
- [X] T021 [US1] Create internet gateway, per-tier route tables and associations, and a public-only internet-gateway route in `infra/modules/network/routing.tf`.
- [X] T022 [US1] Export VPC identity/CIDR, selected AZs, subnet IDs by tier and AZ, flattened tier lists, and route-table IDs in `infra/modules/network/outputs.tf`.
- [X] T023 [US1] Define the remaining sandbox variable declarations and compose the reusable module with account/Region, IPAM reference/CIDRs, AZ IDs, explicit NAT mode, flow-log destination/owner, NAT alarm topic, workload declarations, and governance tags without inventing deployment values in `infra/live/sandbox/network/variables.tf`, `infra/live/sandbox/network/sandbox.tfvars.example`, and `infra/live/sandbox/network/main.tf`.

**Checkpoint**: US1 provides isolated subnet tiers and routing. NAT egress and endpoint routing follow in US2.

## Phase 4: User Story 2 - Control Internet and AWS Service Routing (P1)

**Goal**: Implement the resolved NAT egress boundary, configurable disabled/shared/per-AZ modes, and workload-declared endpoints with explicit routing scope.

**Independent test**: Tests prove private route intent for each NAT mode and confirm selected endpoints are scoped to intended route tables/subnets and avoid general internet routing when private access is supported.

### Tests

- [X] T024 [US2] Write Terraform tests for disabled/shared/per-AZ NAT routes, explicit egress CIDR/prefix-list validation and wildcard rejection, endpoint service/type/subnet/route-table scope and policy, metric-alarm thresholds/windows, and no alarms when NAT is disabled in `infra/modules/network/tests/egress_endpoints.tftest.hcl`.

### Implementation

- [X] T025 [US2] Add required typed `nat_mode` with no default, `allowed_egress`, workload endpoint inputs, and conditional operations SNS topic input; validate destinations, ports, endpoint scope, and policy declarations in `infra/modules/network/variables.tf`.
- [X] T026 [P] [US2] Create NAT gateways and private route associations for disabled, shared, and per-AZ modes in `infra/modules/network/egress.tf`.
- [X] T027 [P] [US2] Create only declared gateway/interface endpoints, validate service/type compatibility, scope route tables/subnets and workload tiers, generate endpoint-specific SG egress only with the endpoint resource, and require reviewed endpoint policy input where supported in `infra/modules/network/endpoints.tf`.
- [X] T028 [US2] Export NAT gateway IDs by AZ and VPC endpoint IDs by service in `infra/modules/network/outputs.tf`.

**Checkpoint**: US1 and US2 provide the segmented network and its approved egress/service paths.

## Phase 5: User Story 3 - Connect Workload and Data Tiers Through Explicit Rules (P1)

**Goal**: Create only explicitly declared tier flows and stable ECS, EKS, RDS, and load-balancer placement outputs, including verifiable public-load-balancer approval.

**Independent test**: No flow declaration yields no app-to-data ingress; declared rules encode source, destination, protocol, port, and rationale; public LB approval is required and surfaced; consumers can resolve subnet and security-group outputs.

### Tests

- [X] T029 [US3] Write Terraform tests for default-deny ingress/egress, declared source/destination/protocol/port rules, flow rationale, required tag coverage, and consumer output names in `infra/modules/network/tests/security_flows.tftest.hcl`.

### Implementation

- [X] T030 [US3] Add typed `allowed_flows` with uniqueness, tier, tcp/udp protocol, port-range, and required rationale validation in `infra/modules/network/variables.tf`.
- [X] T031 [US3] Create load-balancer, application, and data security groups with no default ingress or egress and only declared tier-flow and explicit destination egress rules; do not create a load balancer or implicit public-ingress rules in `infra/modules/network/security_groups.tf`.
- [X] T032 [US3] Export load-balancer/application/data security-group IDs and flow-rule references in `infra/modules/network/outputs.tf`.
- [X] T033 [US3] Re-export VPC, subnet, route, NAT, endpoint, and security-group contract outputs from the sandbox root in `infra/live/sandbox/network/outputs.tf`.
- [X] T034 [US3] Document typed inputs, defaults, validations, output meanings, required tags, naming, public exposure approval, and network boundaries in `infra/modules/network/README.md`.

**Checkpoint**: All three stories form an independently reviewable network foundation; resource exposure is evidence-backed.

## Phase 6: Polish and Cross-Cutting Concerns

**Purpose**: Provide repeatable static/security checks, operational guidance, and a safe reviewed plan path.

- [X] T035 [P] Configure pinned Terraform and AWS ruleset plugins with the selected ruleset in `.tflint.hcl`.
- [X] T036 [P] Configure Terraform security scanning and a documented suppression policy in `.checkov.yaml`.
- [X] T037 Add credential-free pull-request checks and a trusted protected OIDC plan workflow with scoped read-only infrastructure/state permissions, protected apply approval, and short-lived plan artifacts in `.github/workflows/terraform-network.yml`; require the Platform Network/Security CODEOWNER rule to be mapped to the organization's approved team before enabling protected plans in `.github/CODEOWNERS`.
- [X] T038 [P] Update implementation validation commands and expected routing/output assertions in `specs/001-network-foundation/quickstart.md`.
- [X] T039 [P] Document account/Region ownership, approved import procedure, rollback triggers, state recovery safeguards, and assigned operational ownership in `docs/operations/network-migration.md`.
- [X] T040 [P] Document network module adoption, validation gates, environment/state scope, and no-unconfirmed-values rule in `README.md`.
- [X] T041 Create all-traffic VPC Flow Logs to the supplied central destination and per-NAT alarms (`ErrorPortAllocation` Maximum >0 for three five-minute periods; dropped-packet ratio >0.01% for two of three one-minute periods) to the operations SNS topic; document 90-day retention, operational ownership, and cost review in `infra/modules/network/flow_logs.tf`, `infra/modules/network/nat_alarms.tf`, and `docs/operations/network-migration.md`.
- [ ] T042 Run `terraform fmt -check -recursive`, backend-free `terraform validate`, Terraform tests, TFLint, and Checkov; select and commit reviewed provider checksums, then resolve or document approved findings in `infra/modules/network/`, `infra/live/sandbox/network/`, and `infra/live/sandbox/network/.terraform.lock.hcl`.
- [ ] T043 Generate and review an authorized environment `terraform plan` only after account, Region, IPAM CIDRs, Owner/CostCenter, backend settings, and resource ownership are confirmed; review state protections, replacement/destruction, network exposure, tags, recovery characteristics, and NAT cost estimate in `infra/live/sandbox/network/`.

## Dependencies and Execution Order

- Setup (Phase 1) precedes Foundational (Phase 2).
- T003–T010 are completed design decisions; T011–T015 establish code/state prerequisites. External deployment values still block authenticated plans.
- US1 follows Phase 2. US2 and US3 both depend on US1 and may proceed in parallel after its checkpoint.
- Polish documentation/tooling may begin after decisions stabilize; T041–T043 and final validation follow implementation.

### Parallel Opportunities

- T011 and T012 use separate version files after T001.
- T026 and T027 use separate module files after T025.
- After US1, US2 and US3 can proceed concurrently if shared `variables.tf` and `outputs.tf` edits are coordinated.
- T035, T036, T038, T039, and T040 use separate files once design decisions are stable.

### Parallel Example: User Stories 2 and 3

```text
After US1:
Owner A: T024 → T025 → T026 and T027 in parallel → T028
Owner B: T029 → T030 → T031 → T032 → T033 → T034
```

### Per-Story Parallel Work

- US1: Follow T016 → T017 → T018 → T019 → T020 → T021 → T022 → T023; shared topology contracts make safe concurrent edits unlikely.
- US2: After T025, T026 and T027 can proceed in parallel; T028 follows both.
- US3: Follow T029 → T030 → T031 → T032 → T033 → T034 to preserve the common flow and output contract.

## Implementation Strategy

### MVP First

With T003–T010 design decisions recorded, complete setup and foundational prerequisites, then deliver US1 as the isolated VPC/subnet baseline. Validate with synthetic fixtures and a reviewed plan before using the network. Treat it as a baseline only; complete US2 before workloads that require egress or AWS service paths.

### Incremental Delivery

1. Resolve foundational decisions and deployment/state prerequisites.
2. Deliver US1 isolated subnet tiers.
3. Add US2 approved NAT modes and workload-specific endpoints.
4. Add US3 explicit flows, approval evidence, and consumer outputs.
5. Run cross-cutting checks and an authorized reviewed plan; do not apply before environment approval.

## Notes

- Every task includes a repository path and follows the required checkbox/ID/story format.
- `[P]` is limited to separate files with satisfied dependencies.
- Test CIDRs are synthetic and never copied into deployable inputs.
- `checklists/network.md` remains reviewer-owned.
- Account, Region, CIDRs, backend values, ownership, and governance values remain explicit external prerequisites; no values are guessed.
