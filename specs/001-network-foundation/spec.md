# Feature Specification: AWS Network Foundation

**Feature Branch**: `001-network-foundation`

**Created**: 2026-10-28

**Status**: Draft

**Input**: User description: "Create the AWS network foundation for the infrastructure platform. Support configurable AWS Regions and environments; public, private application and private data subnets; multiple Availability Zones; controlled internet access through NAT gateways; VPC endpoints; explicit application and database network rules; clear ECS, EKS, RDS and load balancer outputs; and acceptance criteria for network isolation and routing. The feature must comply with the project constitution."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Establish an isolated environment network (Priority: P1)

As a platform engineer, I need a network foundation for a selected AWS Region and environment, with public, private application, and private data subnet tiers distributed across multiple Availability Zones, so workloads can be deployed with clear separation and resilience boundaries.

**Why this priority**: All platform workloads depend on a correctly segmented network foundation.

**Independent Test**: Select a supported Region, environment, and at least two Availability Zones; review the resulting network inventory and confirm that each tier is represented in each selected zone with no overlapping subnet ranges.

**Acceptance Scenarios**:

1. **Given** a valid Region, environment, and two or more selected Availability Zones, **When** the network is provisioned, **Then** public, private application, and private data subnets are available in every selected zone.
2. **Given** an invalid or overlapping subnet allocation, **When** the network configuration is reviewed, **Then** it is rejected with a clear explanation before it can be applied.
3. **Given** development, staging, and production network configurations, **When** their state boundaries are reviewed, **Then** each environment uses separate Terraform state with access restricted to its authorized roles.

---

### User Story 2 - Control internet and AWS service routing (Priority: P1)

As a platform engineer, I need outbound internet access to follow an explicit NAT policy and supported AWS service traffic to use VPC endpoints, so private workloads do not depend on unnecessary public routing.

**Why this priority**: Controlled egress limits exposure and provides a clear path for private workloads to reach required destinations.

**Independent Test**: Review route intent for each subnet tier and confirm that private subnet internet egress uses only the configured NAT gateways, while selected endpoint traffic uses private or gateway endpoint paths.

**Acceptance Scenarios**:

1. **Given** private subnets and NAT access enabled, **When** outbound internet routing is inspected, **Then** private subnet default routes use only the configured NAT gateway policy and no private subnet has a direct route to an internet gateway.
2. **Given** a required AWS service with an enabled endpoint, **When** a workload accesses that service, **Then** the traffic has an endpoint route and does not require general internet egress.
3. **Given** NAT access is disabled for an environment, **When** its routes are reviewed, **Then** no private subnet has a NAT-based internet route.

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

---

### Edge Cases

- A requested Region has fewer eligible Availability Zones than the configured minimum.
- A subnet range is too small for the requested number of tiers and zones, overlaps another subnet, or falls outside the VPC range.
- NAT access is disabled while a workload requirement depends on public internet egress.
- A requested VPC endpoint is unavailable in the selected Region or cannot serve the required destination.
- A load balancer requires public placement while the environment policy permits only private exposure.
- An application-to-database rule omits its source, destination, protocol, or port.
- A zone-specific NAT gateway becomes unavailable; private egress behavior follows the selected NAT resilience policy.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The network MUST accept an AWS Region and environment as explicit configuration inputs.
- **FR-002**: The network MUST provide configurable VPC and subnet address ranges and reject invalid, overlapping, or insufficient allocations before apply.
- **FR-003**: The network MUST provide public, private application, and private data subnet tiers in each selected Availability Zone.
- **FR-004**: The network MUST support at least two Availability Zones and allow the selected zone count to be configured within the Region's available zones.
- **FR-005**: The network MUST keep private application and private data subnets without direct internet gateway routes.
- **FR-006**: The network MUST allow NAT-based internet egress to be enabled or disabled per environment and MUST support a configurable NAT placement policy, including one NAT gateway per selected zone and a shared NAT gateway policy.
- **FR-007**: When NAT egress is enabled, private subnet routes MUST use only the configured NAT placement policy; public subnets MUST provide the routing required for their explicitly approved public-facing purpose.
- **FR-008**: The network MUST support configurable VPC endpoints for required AWS services and expose whether each selected service uses private endpoint routing.
- **FR-009**: Endpoint configuration MUST allow endpoint access to be constrained to intended subnets and workloads, and endpoint traffic MUST NOT require general internet routing when the selected endpoint supports private access.
- **FR-010**: Application-to-data communication MUST be denied by default and permitted only by explicit rules that identify source, destination, protocol, and port.
- **FR-011**: The network MUST expose clear, stable outputs for VPC identity, CIDR, subnet IDs grouped by tier and Availability Zone, route-table associations, and relevant security rule references.
- **FR-012**: The network outputs MUST support consumers deploying ECS, EKS, RDS, and public or private load balancers without requiring consumers to infer subnet tiers or network boundaries.
- **FR-013**: Public exposure MUST be explicit and justified for each public-facing workload; private application and data tiers MUST remain private by default.
- **FR-014**: Network configuration and documentation MUST identify the configured environment, Region, Availability Zones, NAT policy, endpoint selection, and permitted application-to-data flows.
- **FR-015**: Managed network resources MUST follow the repository's documented naming convention and include the required `Project`, `Environment`, `ManagedBy`, `Owner`, and `CostCenter` tags.
- **FR-016**: Development, staging, and production network configurations MUST use separate Terraform state, with access restricted according to the target environment.

### Key Entities *(include if feature involves data)*

- **Environment Network**: An isolated network boundary for one deployment environment and AWS Region, including its address range and routing intent.
- **Subnet Tier**: A public, private application, or private data network segment associated with an Availability Zone.
- **Egress Policy**: The environment-specific decision about NAT availability, placement, and permitted private subnet internet routes.
- **Service Endpoint**: A selected AWS service destination with an endpoint type, eligible subnet scope, and intended workload access boundary.
- **Network Flow Rule**: An explicitly permitted source, destination, protocol, and port relationship between workload tiers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every supported environment, all three subnet tiers are present in 100% of its selected Availability Zones, with no overlapping subnet ranges.
- **SC-002**: The approved network flow set has zero undocumented application-to-data paths, and every permitted path specifies source, destination, protocol, and port.
- **SC-003**: Private subnets have zero direct internet gateway routes; when NAT is disabled, they have zero NAT-based internet routes.
- **SC-004**: For every enabled service endpoint, the required service traffic has an endpoint path that does not depend on general internet routing.
- **SC-005**: ECS, EKS, RDS, and load balancer consumers can each identify the VPC and required subnet tier and zone from documented outputs.
- **SC-006**: 100% of managed network resources follow the documented naming convention and carry all five required governance tags.

## Assumptions

- Development, staging, and production are distinct environments with separate network configurations and state, as required by the project constitution.
- At least two Availability Zones are the default for a production network; non-production environments may select fewer zones when explicitly configured.
- A per-zone NAT policy is the default for production to avoid a single-zone egress dependency; a shared NAT policy is available when cost is prioritized and the trade-off is documented.
- NAT gateways provide outbound connectivity only; inbound access to private subnets is not permitted through NAT.
- The required endpoint service list depends on workload needs and is configured per environment; the feature does not assume every AWS service needs an endpoint.
- ECS and EKS workloads use private application subnets by default; RDS uses private data subnets; load balancer placement is selected according to explicit public or private exposure requirements.
- Network rules are stateful and deny unapproved flows by default; exact application ports are supplied by workload specifications.
- Account structure, CIDR ranges, compliance obligations, and required recovery objectives are supplied by the relevant platform or workload specifications.
- Terraform state is managed remotely under the repository constitution; state backend details and state access roles are defined during planning for each environment.
