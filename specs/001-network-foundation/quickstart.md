# Quickstart: Network Module Validation

This guide defines validation steps for the implemented network module. It does not apply
infrastructure. Terraform-specific checks require Terraform CLI and provider downloads; no
authenticated AWS plan is permitted until deployment inputs and ownership are confirmed.

## Prerequisites for an Authenticated Plan

Before initializing the sandbox backend or running a real plan, obtain and review:

- The approved sandbox AWS account ID and AWS Region, with an authorized short-lived role.
- Organization IPAM-approved VPC and per-AZ subnet CIDRs that do not overlap other networks.
- Owner and CostCenter tag values.
- The separately managed S3 backend bucket, key, Region, KMS settings, and role. Confirm versioning,
  encryption, public-access blocking, TLS-only access, lockfile use, and path-scoped permissions.
- Confirmed ownership of any network resources already present in that account/Region.
- Workload declarations for required endpoints, endpoint policies, and permitted network flows.
- The approved encrypted central flow-log destination with at least 90-day retention.
- A Region-specific NAT and flow-log cost estimate reviewed by the environment CostCenter owner.
- Workload-specific RTO/RPO and backup/DR requirements before any critical workload is deployed.

No account IDs, CIDRs, resource owners, endpoint services, or backend names are supplied by this
guide. Do not substitute guessed values.

## Module-Only Checks

Run without contacting AWS or the remote state backend:

```bash
terraform -chdir=infra/modules/network fmt -check -recursive
terraform -chdir=infra/modules/network init -backend=false
terraform -chdir=infra/modules/network validate
terraform -chdir=infra/modules/network test
tflint --chdir=infra/modules/network
checkov -d infra/modules/network --framework terraform
```

Expected outcome: formatting, initialization, validation, and module tests pass; TFLint and Checkov
produce no unresolved blocking findings. Any accepted scanner exception has a narrow documented
reason and reviewer.

The same backend-free validation applies to the sandbox composition, but it still requires all
Terraform variables to be supplied before validate can complete. The checked-in
`sandbox.tfvars.example` is intentionally non-deployable. The module's synthetic tests verify
topology, NAT modes, endpoints, default-deny security groups, flow rules, and logging without AWS.

## Sandbox Composition Checks

After the environment-specific configuration and backend inputs are supplied securely:

```bash
terraform -chdir=infra/live/sandbox/network fmt -check -recursive
terraform -chdir=infra/live/sandbox/network init -backend-config=/secure/path/to/backend.hcl
terraform -chdir=infra/live/sandbox/network validate
tflint --chdir=infra/live/sandbox/network
checkov -d infra/live/sandbox/network --framework terraform
terraform -chdir=infra/live/sandbox/network plan -var-file=/secure/path/to/sandbox.tfvars
```

Expected plan properties:

- It targets the confirmed account and Region and shows the expected state key.
- It creates exactly public, private application, and private data subnets for every selected AZ,
  using only IPAM-approved CIDRs.
- Private subnets have no direct internet gateway route. NAT mode is an explicit input: disabled
  mode has no NAT default routes; shared mode uses one gateway and has shared-AZ outage/cross-AZ
  cost; per-AZ mode maps each private AZ to its local gateway. Use shared mode for non-production
  only when external egress is needed; use per-AZ mode for production when needed; disable NAT when
  private paths suffice.
- NAT is not a destination filter. Verify least-privilege workload security-group egress; if domain
  or destination filtering is required, the plan uses a separately approved firewall/proxy path.
- Verify outbound rules declare destination CIDR/prefix list, protocol, port, and rationale; no
  universal `0.0.0.0/0` or `::/0` security-group egress is present.
- Only workload-declared endpoints and explicit flow rules appear. Tier security groups have no
  default ingress or egress. Unlisted flows remain denied, with no unapproved internet ingress or
  direct public workload IP.
- Public load balancers are workload-owned; their change records approval, source CIDRs, protocols,
  and ports. The network module only exposes placement and security-group boundaries.
- Flow Logs capture all traffic to the approved encrypted central destination, which retains records
  for at least 90 days.
- Names and required tags are present on managed resources.
- The plan has no unexpected import, replacement, or destroy actions.

Untrusted pull requests run static checks without AWS credentials. Authenticated plans use a trusted
protected workflow with OIDC, a read-only infrastructure role, and only scoped state/lock access.
Review create/update/replace/destroy actions, public exposure, route tables, security-group
sources/ports, endpoint scopes/policies, NAT failure behavior and regional cost, flow-log
destination/retention, state changes, and tags. The CostCenter owner reviews the estimate. Re-run
the plan after changes and before protected apply approval. A saved plan may contain sensitive
values; do not commit it and store it only as a short-lived access-controlled artifact.

## Acceptance Scenarios for Automated Tests

1. Given two or more selected AZ IDs, verify the input subnet map contains all three tiers for each AZ.
2. Given overlapping, out-of-VPC, invalid, or insufficient CIDRs, verify validation rejects the
   configuration before apply.
3. Given each NAT mode (`disabled`, `shared`, `per_az`), inspect planned routes and gateway
   associations for the selected policy.
4. Given an egress rule, verify destination, protocol, port, and rationale; reject wildcard
   destinations and allow undeclared egress nowhere.
5. Given an endpoint declaration, verify only the requested service and intended private subnets or
   route tables are associated; verify a missing Region service is surfaced before apply.
6. Given no flow declaration, verify tier security groups have no ingress or egress allow rules;
   given an explicit flow, verify source, destination, protocol, port range, and rationale.
7. Verify DNS support and hostnames are enabled, no IPv6 ranges are present, and workloads receive
   no public IPv4 addresses.
8. Verify all required root outputs are documented and populated for the sandbox module call.
9. Verify required names/tags and the expected-account provider guard are represented in the plan.
10. Verify Flow Logs are configured for all traffic, and the destination's encryption and retention
   meet the 90-day requirement.
11. Verify authenticated plans use the protected OIDC role and state permissions are scoped to the
    target environment.
12. Verify every NAT gateway has both metric alarms, correct periods/thresholds, and the approved
    operations SNS topic; disabled NAT has none.
13. Verify endpoint SG ingress and workload egress are scoped to the declared interface endpoint;
    gateway endpoints add only their managed prefix-list egress to declared workload tiers.
14. Verify public load-balancer ingress is absent unless `public_lb_ingress` includes exact source
    CIDRs, protocols, ports, business need, and a CODEOWNER-verifiable approval reference; verify
    those values appear in `public_lb_ingress_approvals`.

## Apply and Recovery Boundary

This guide ends at the reviewed plan. Apply requires a separate explicit environment approval.
For an unexpected plan, do not apply; adjust configuration and produce a fresh plan. For adopted
resources, import only after ownership confirmation and a no-unintended-change import plan. For
state recovery, compare a versioned snapshot with live AWS resources before restoring it. Destroy is
not a routine rollback for a shared network.
