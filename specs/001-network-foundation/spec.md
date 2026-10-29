# Feature Specification: AWS Network Foundation

**Feature Branch**: `001-network-foundation`

**Created**: 2026-10-28

**Status**: Draft

**Input**: User description: "Create the AWS network foundation for the infrastructure platform. Support configurable AWS Regions and environments; public, private application and private data subnets; multiple Availability Zones; controlled internet access through NAT gateways; VPC endpoints; explicit application and database network rules; clear ECS, EKS, RDS and load balancer outputs; and acceptance criteria for network isolation and routing. The feature must comply with the project constitution."

## Clarifications

### Session 2026-10-29

- Q: Should the network feature name a specific AWS account and Region now, or require them as environment inputs and leave the first deployment target TBD? → A: Require the account and Region as environment inputs; leave the first deployment target TBD.
- Q: Who should own assigning and approving VPC and subnet CIDR ranges for each environment? → A: Organization IPAM allocates and approves ranges.
- Q: What initial Availability Zone count and NAT gateway policy should apply to production and non-production environments? → A: The original clarification selected two AZs and shared NAT for all environments. This answer is superseded by the later best-practice decision below: no implicit NAT default, non-production shared NAT only when needed, production per-AZ NAT when needed, and a three-AZ production target where supported.
- Q: Which AWS service endpoints should be required by default in each environment? → A: No fixed set; workloads declare required endpoints.
- Q: What defaults should apply to IPv6, DNS, and public IP addresses for workloads? → A: IPv4 only; AWS-provided DNS with resolution and hostnames enabled; no workload public IPs; public load balancers require explicit approval.
- Q: What production and non-production topology, egress, and operational defaults should apply? → A: Keep account IDs, Regions, CIDRs, ownership, and backend identifiers as confirmed deployment inputs. Use at least two AZs everywhere and target three AZs for production where the Region and workload support it. Require each composition to select NAT mode explicitly: shared NAT for sandbox/development/staging only when external egress is needed, per-AZ NAT for production when external egress is needed, and disabled when private paths suffice. NAT is routing/NAT, not destination filtering; destination filtering requires an approved firewall/proxy. Select AZ IDs explicitly, enable VPC Flow Logs to an approved encrypted central destination for at least 90 days, and require workload owners to define service RTO/RPO.
- Q: What is the first delivery scope and how are public ingress, plans, and cost reviewed? → A: Deliver the reusable module and sandbox root only; later environments require separate roots, state keys, and roles. Public load balancers remain workload-owned; the workload owner records business need and exact source CIDRs/protocols/ports, and the Platform Network/Security CODEOWNER approves the change. Static PR checks use no AWS credentials; authenticated plans use protected OIDC roles and approval. CostCenter owners review Region-specific NAT and flow-log estimates; numeric budgets are supplied by them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Establish an isolated environment network (Priority: P1)

As a platform engineer, I need a network foundation for a selected AWS Region and environment, with public, private application, and private data subnet tiers distributed across multiple Availability Zones, so workloads can be deployed with clear separation and resilience boundaries.

**Why this priority**: All platform workloads depend on a correctly segmented network foundation.

**Independent Test**: Select a supported Region, environment, and at least two AZ IDs; review the resulting network inventory and confirm that each tier is represented in each selected AZ with no overlapping subnet ranges.

**Acceptance Scenarios**:

1. **Given** a valid Region, environment, and two or more selected AZ IDs, **When** the network is provisioned, **Then** public, private application, and private data subnets are available in every selected zone.
2. **Given** an invalid or overlapping subnet allocation, **When** the network configuration is reviewed, **Then** it is rejected with a clear explanation before it can be applied.
3. **Given** this feature's sandbox composition and any later environment composition, **When** their state boundaries are reviewed, **Then** each environment and Region uses a separate Terraform state key and authorized role; this feature does not claim to deliver later roots.

---

### User Story 2 - Control internet and AWS service routing (Priority: P1)

As a platform engineer, I need outbound internet access to follow an explicit NAT policy and supported AWS service traffic to use VPC endpoints, so private workloads do not depend on unnecessary public routing.

**Why this priority**: Controlled egress limits exposure and provides a clear path for private workloads to reach required destinations.

**Independent Test**: Review route intent for each subnet tier and confirm that private subnet egress uses only the selected NAT topology, default security-group egress is denied, each approved outbound rule names its destination/protocol/port, and selected endpoint traffic uses private or gateway endpoint paths.

**Acceptance Scenarios**:

1. **Given** private subnets and NAT access enabled, **When** outbound internet routing is inspected, **Then** private subnet default routes use only the configured NAT gateway policy and no private subnet has a direct route to an internet gateway.
2. **Given** a required AWS service with an enabled endpoint, **When** a workload accesses that service, **Then** the traffic has an endpoint route and does not require general internet egress.
3. **Given** NAT access is disabled for an environment, **When** its routes are reviewed, **Then** no private subnet has a NAT-based internet route.
4. **Given** an outbound workload connection, **When** its security-group rules are reviewed, **Then** it is permitted only by an explicit destination CIDR/prefix list, protocol, port, and rationale; universal destination ranges are rejected.
5. **Given** a requested endpoint service is unavailable or its policy is invalid, **When** the configuration is planned, **Then** planning fails clearly and does not silently route that service through NAT.

---

### User Story 3 - Connect workload and data tiers through explicit rules (Priority: P1)

As a workload owner, I need application and database connectivity to be explicitly authorized and discoverable, so application workloads can reach approved data services while other paths remain blocked.

**Why this priority**: Tier isolation is a core security boundary for platform workloads and data.

**Independent Test**: Review the documented allowed-flow set and compare it with the network rules: each permitted application-to-database flow must identify source, destination, protocol, and port, and all other tier-crossing flows must be denied by default.

**Acceptance Scenarios**:

1. **Given** an approved application-to-database flow, **When** its rule is defined, **Then** the rule identifies the application source, database destination, protocol, and port.
2. **Given** a flow absent from the approved rule set, **When** application and data tier boundaries are evaluated, **Then** that flow is denied by default.
3. **Given** a consumer deploying ECS, EKS, RDS, or a load balancer, **When** it reads the network outputs, **Then** it can identify the relevant VPC, subnet IDs by tier and Availability Zone, and network rule references without reconstructing the network topology.
4. **Given** a network for a named environment, **When** its managed resources are reviewed, **Then** their names follow the repository convention and they carry the required `Project`, `Environment`, `ManagedBy`, `Owner`, and `CostCenter` tags.
5. **Given** a workload or load balancer that requests public addressing, **When** its network placement is reviewed, **Then** workloads receive no direct public IP and a public load balancer is exposed only with the workload owner's documented need and ingress limits plus approval from the Platform Network/Security CODEOWNER.

---

### Edge Cases

- A requested Region has fewer eligible Availability Zones than the configured minimum.
- A subnet range is too small for the requested number of tiers and zones, overlaps another subnet, or falls outside the VPC range.
- NAT access is disabled while a workload requirement depends on public internet egress.
- A requested VPC endpoint is unavailable in the selected Region or cannot serve the required destination.
- A load balancer requires public placement while the environment policy permits only private exposure.
- An application-to-database rule omits its source, destination, protocol, or port.
- A zone-specific NAT gateway becomes unavailable; egress from that AZ may fail, while other AZs continue using their local NAT in per-AZ mode. No automatic cross-AZ failover is promised.
- A shared NAT gateway's AZ becomes unavailable; egress from all private AZs may fail until service recovery. Shared NAT is limited to non-production defaults and explicitly accepted sandbox use.
- A workload needs destination-filtered egress; NAT alone does not meet that requirement and an approved firewall/proxy path is required.
- An endpoint policy, IAM policy, or resource policy blocks an endpoint request; endpoint reachability does not override those authorization layers.
- A requested endpoint service is unavailable or its policy is invalid; planning fails clearly, and traffic does not silently fall back to NAT.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The network MUST accept an AWS account, AWS Region, and environment as explicit deployment configuration inputs; the reusable network definition MUST NOT select fixed account or Region values.
- **FR-002**: The network MUST accept VPC and subnet address ranges allocated and approved by organization IPAM, and reject invalid, overlapping, or insufficient allocations before apply.
- **FR-003**: The network MUST provide public, private application, and private data subnet tiers in each selected Availability Zone.
- **FR-004**: The network MUST support at least two Availability Zones and allow the selected zone count to be configured using AZ IDs available in the selected Region. Production compositions SHOULD use at least three AZs where supported by the Region and workload.
- **FR-005**: The network MUST keep private application and private data subnets without direct internet gateway routes.
- **FR-006**: The network MUST require each environment composition to explicitly select NAT mode (`disabled`, `shared`, or `per_az`); module inputs MUST NOT silently default to a paid NAT topology. Sandbox/development/staging SHOULD use shared NAT only when external IPv4 egress is needed; production SHOULD use one NAT gateway per selected AZ when external egress is needed.
- **FR-007**: When NAT egress is enabled, private subnet routes MUST use only the configured NAT placement policy; public subnet routing MUST be limited to explicitly approved edge resources. NAT MUST be documented as routing/address translation, not destination filtering. Workloads MUST have default-deny egress security groups and explicitly declare allowed destination CIDRs/prefix lists, protocols, ports, and rationale. Destination/domain filtering MUST use an approved firewall/proxy control.
- **FR-008**: The network MUST support workload-declared VPC endpoints for required AWS services, without imposing a fixed platform-wide endpoint set, and expose whether each selected service uses private endpoint routing.
- **FR-009**: Endpoint configuration MUST constrain interface endpoints to intended private subnets and workload security groups, and gateway endpoints to intended route tables. Endpoint policies MUST be least-privilege where supported and reviewed with workload IAM/resource policies; endpoint traffic MUST NOT require general internet routing when private access is supported.
- **FR-010**: Tier security groups MUST deny ingress and egress by default. Application-to-data communication MUST be permitted only by explicit stateful rules identifying source, destination, protocol, port range, and rationale.
- **FR-011**: The network MUST expose clear, stable outputs for VPC identity, CIDR, subnet IDs grouped by tier and Availability Zone, route-table associations, and relevant security rule references.
- **FR-012**: The network outputs MUST support consumers deploying ECS, EKS, RDS, and public or private load balancers without requiring consumers to infer subnet tiers or network boundaries.
- **FR-013**: Public exposure MUST be explicit and justified for each public-facing workload; private application and data tiers MUST remain private by default.
- **FR-014**: Network configuration and documentation MUST identify the configured environment, Region, Availability Zones, NAT policy, endpoint selection, and permitted application-to-data flows.
- **FR-015**: Managed network resources MUST follow the repository's documented naming convention and include the required `Project`, `Environment`, `ManagedBy`, `Owner`, and `CostCenter` tags.
- **FR-016**: This feature MUST deliver an independently stateful sandbox composition. Any development, staging, or production composition added later MUST use a distinct root/configuration and state key per environment and Region, with authorization scoped to that environment.
- **FR-017**: The network MUST use IPv4 addressing only, enable Amazon-provided DNS resolution and hostnames, assign no public IP addresses directly to workloads, and allow public load-balancer exposure only through a reviewed workload change recording approval, allowed source CIDRs, protocols, and ports. Load-balancer resources are owned by workload compositions, not this network module.
- **FR-018**: The network MUST enable VPC Flow Logs for all traffic and deliver them to an approved encrypted centralized logging destination with retention of at least 90 days; destination and ownership are deployment inputs.
- **FR-019**: Critical workload owners MUST define service-specific availability and recovery objectives in workload specifications before workload implementation. The network module MUST document AZ/NAT failure behavior and MUST NOT claim workload RTO/RPO guarantees.
- **FR-020**: Every authorized environment plan MUST include a Region/traffic-specific estimate for NAT and flow-log costs and be reviewed by its CostCenter owner; numeric budget thresholds are supplied by that owner, not assumed by this feature.
- **FR-021**: The workflow MUST run credential-free static checks for untrusted pull requests. Authenticated plans MUST use short-lived OIDC credentials, protected environment approval, a read-only infrastructure role plus narrowly scoped state/lock access, and short-lived access-controlled plan artifacts. Apply requires separate protected approval.
- **FR-022**: Security scan suppressions MUST identify the finding, scope, rationale, approver, and expiry/review date; suppressions without these fields MUST fail review.
- **FR-023**: Network CIDRs MUST come from organization IPAM allocations. Plan review MUST verify allocation ownership and non-overlap with connected networks; module validation MUST verify IPv4 syntax, VPC containment, subnet non-overlap, and capacity, without treating an unverified Boolean as proof of IPAM approval.
- **FR-024**: When NAT is enabled, the network MUST create per-gateway CloudWatch alarms: `ErrorPortAllocation` `Maximum` above zero for three consecutive five-minute periods, and the ratio `PacketsDropCount / (PacketsInFromSource + PacketsInFromDestination) * 100` above 0.01% for two of three one-minute periods. Notifications go to an operations-owned SNS topic supplied as an input.
- **FR-025**: The network MUST reject undeclared internet egress and broad `0.0.0.0/0` or `::/0` workload egress rules; workloads needing dynamic destinations MUST use private endpoints or an approved firewall/proxy policy.

### Key Entities *(include if feature involves data)*

- **Environment Network**: An isolated network boundary for one deployment environment and AWS Region, including its address range and routing intent.
- **Subnet Tier**: A public, private application, or private data network segment associated with an Availability Zone.
- **Egress Policy**: The environment-specific decision about NAT availability, placement, and permitted private subnet internet routes.
- **Service Endpoint**: A selected AWS service destination with an endpoint type, eligible subnet scope, and intended workload access boundary.
- **Network Flow Rule**: An explicitly permitted source, destination, protocol, and port relationship between workload tiers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For the delivered sandbox and each later environment composition, all three subnet tiers are present in 100% of selected AZ IDs, with no overlapping subnet ranges; production uses at least three AZs where the Region and workload support it.
- **SC-002**: Tier security groups have no default allow rules; every permitted cross-tier path specifies source, destination, protocol, port range, and rationale, and unlisted paths are denied.
- **SC-003**: Private subnets have zero direct internet gateway routes; when NAT is disabled, they have zero NAT-based internet routes.
- **SC-004**: For every enabled service endpoint, the required service traffic has an endpoint path that does not depend on general internet routing.
- **SC-005**: ECS, EKS, RDS, and load balancer consumers can each identify the VPC and required subnet tier and zone from documented outputs.
- **SC-006**: 100% of taggable managed network resources, including endpoints and flow-log resources, follow the naming convention and carry all five required governance tags.
- **SC-007**: Zero workload resources receive direct public IP addresses; each public load-balancer change includes an approval reference and exact ingress source CIDRs, protocols, and ports.
- **SC-008**: Every environment uses a distinct remote-state key and role; production cannot read or write non-production state unless separately authorized.
- **SC-009**: VPC Flow Logs capture accepted and rejected traffic and are retained for at least 90 days in the approved encrypted central destination.
- **SC-010**: Every authenticated plan uses a protected OIDC role, is reviewed before apply, and is stored only as a limited-retention access-controlled artifact.
- **SC-011**: DNS resolution and hostnames are enabled, IPv6 is absent, and no workload subnet auto-assigns public IPv4.
- **SC-012**: Every deployed VPC/subnet allocation has a recorded IPAM approval reference and reviewer confirmation of non-overlap with connected networks.
- **SC-013**: An unavailable endpoint service or invalid endpoint policy causes a clear plan/configuration failure; service traffic can use public NAT egress only when a separate explicit `allowed_egress` rule permits it.
- **SC-014**: Every NAT gateway has both required metric alarms with the specified threshold/window and approved operations notification topic; disabled NAT creates no NAT alarms.
- **SC-015**: Each authorized environment plan contains a Region/traffic-specific NAT and flow-log cost estimate with recorded CostCenter owner review.
- **SC-016**: Every workload internet egress rule maps to an explicit destination CIDR/prefix list, protocol, port, and rationale; no default or wildcard all-destination egress rule exists.

## Assumptions

- This feature delivers the reusable module and sandbox composition only. Later development, staging, and production roots use separate configurations, state keys, and role boundaries.
- All environments use at least two AZ IDs. Production targets at least three AZs where supported by the Region and workload; AZ choices are explicit and no Region-specific AZ is guessed.
- NAT mode has no module default. Sandbox/development/staging use shared NAT only when external IPv4 egress is required; production uses per-AZ NAT when external egress is required. Disable NAT when private endpoints and other private paths satisfy workload needs.
- Shared NAT has lower gateway cost but creates a single-AZ egress dependency and cross-AZ traffic. Per-AZ NAT improves zonal independence and avoids cross-AZ NAT processing but increases fixed and data-processing costs. No automatic cross-AZ failover is promised.
- NAT does not filter destinations. Workload security groups restrict protocol/port/destination where stable destinations exist; destination/domain filtering uses an approved AWS Network Firewall or proxy design, outside this module unless separately approved.
- Internet egress security-group rules use explicit destination CIDRs or managed prefix lists; universal IPv4/IPv6 destinations are rejected. Workloads with changing destination addresses use private AWS endpoints or the approved firewall/proxy pattern.
- AZ IDs are selected explicitly instead of deriving account-specific AZ letter names.
- VPC Flow Logs capture all traffic to an organization-approved encrypted central destination with at least 90-day retention. For each NAT gateway, alarm on `ErrorPortAllocation` `Maximum` above zero for three consecutive five-minute periods and dropped-packet ratio above 0.01% for two of three one-minute periods; notify an operations-owned SNS topic supplied at deployment.
- Workload specifications own service RTO/RPO and backup requirements. This feature defines zonal routing/failure behavior and state recovery, not application recovery objectives.
- Public load balancers are created by workload roots. Their reviewed change records business need, approval reference from the Platform Network/Security CODEOWNER, and exact source CIDRs, protocols, and ports. The module's `public_lb_ingress` input is empty by default and creates only the declared ingress rules on its LB security group; it does not create the load balancer.
- CostCenter owners review Region-specific NAT and flow-log estimates in plans. Numeric budget thresholds remain owner-provided because Region, traffic, and budgets are unknown.
- CI uses static checks without AWS credentials on untrusted PRs. A protected trusted workflow uses GitHub OIDC and short-lived credentials for a read-only infrastructure plan role plus least-privilege backend state/lock access. Apply has a separate protected approval and role. Plan artifacts are access controlled and short lived.
- Scan suppressions require finding ID, scoped rationale, approver, and expiry/review date.
- NAT gateways provide outbound connectivity only; inbound access to private subnets is not permitted through NAT.
- There is no fixed platform-wide endpoint baseline; each workload declares its required endpoint services per environment, and the feature does not assume every AWS service needs an endpoint.
- The initial network feature is IPv4-only and uses Amazon-provided DNS resolution and hostnames; workloads have no direct public IP addresses, and public load balancers require documented explicit approval.
- ECS and EKS workloads use private application subnets by default; RDS uses private data subnets; load balancer placement is selected according to explicit public or private exposure requirements.
- Network rules are stateful and deny unapproved flows by default; exact application ports are supplied by workload specifications.
- Organization IPAM owns assignment and approval of non-overlapping VPC and subnet CIDR ranges; the allocations for each environment are provided before implementation.
- Compliance obligations and service recovery objectives are supplied by the relevant workload specifications before workload implementation.
- The first AWS account and Region for deployment are TBD; each environment MUST supply its own account and Region values.
- Terraform state is managed remotely under the repository constitution; state backend details and state access roles are defined during planning for each environment.
