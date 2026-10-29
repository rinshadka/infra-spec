# Network foundation migration and operations

This runbook covers the initial sandbox composition in `infra/live/sandbox/network`. The reusable
module owns only resources declared in its Terraform state. Confirm AWS account, Region, IPAM
allocations, existing VPC/route/subnet ownership, owner, cost center, and change approvers before
backend initialization or an authenticated plan.

## Before the first plan

The environment owner and Platform Network/Security reviewer must record:

- Confirmed AWS account and Region, AZ IDs, IPAM-approved VPC/subnet CIDRs, and allocation ticket.
- Existing VPC, subnet, route, gateway, endpoint, security-group, and flow-log ownership. Resolve
  overlaps and ownership conflicts before changing Terraform configuration.
- The central S3 Flow Logs destination, its resource policy, encryption, access controls, lifecycle
  of at least 90 days, and accountable operations owner. The module does not own that bucket.
- NAT mode, estimate for gateway-hours/data processing/cross-AZ transfer, and CostCenter owner
  review. Shared NAT has one-AZ egress dependency and cross-AZ traffic; per-AZ NAT costs more fixed
  gateway-hours and keeps egress local; disabled NAT is appropriate only when private paths satisfy
  workload dependencies.
- Endpoint service policy, service availability in the selected Region, workload tier scopes, and
  allowed tier flows/egress. NAT is not a destination filter.
- Workload RTO/RPO and backup/recovery requirements before onboarding critical services.

## State and ownership

Use the central encrypted/versioned S3 state bucket, SSE-KMS, S3 native lockfile, public access
block, TLS-only policy, and environment-specific state key. Grant the OIDC plan role read-only
resource access and only the scoped state/lock permissions needed for its key. Apply uses a
separate role and protected environment approval. Do not store backend values or credentials in
Git. Preserve prior state versions and audit state access.

For an existing resource, first obtain written ownership confirmation and a reviewed migration
plan. Use a protected change to add the resource address to configuration, import it with the
approved Terraform version and backend, and immediately inspect a fresh plan. The plan must show no
unintended replacement, destroy, or modification before apply. Do not import resources owned by
another stack or team, and do not use `terraform state mv/rm` as a drift workaround.

Scanner suppressions are exceptional: keep them resource-scoped and record the exact Checkov rule,
the reason the finding does not apply or the compensating control, an issue/change reference, and
the approving security owner next to the suppression. Do not add global skipped rules to scanner
configuration.

## Apply, rollback, and recovery

Apply only the exact reviewed saved plan from a trusted workflow run after the environment approval.
If a plan includes unexpected route, address, security-group, endpoint, or gateway changes, stop,
reconcile configuration/state ownership, and create a new plan. Do not improvise with console edits.

Rollback triggers include loss of required private reachability, unexpected public exposure,
unapproved routes/rules, loss of required AZ coverage, or a destructive state/resource action. Stop
promotion, notify the network owner and security approver, preserve the plan/state version, and use a
reviewed forward fix. Destroy is not a routine rollback for shared networking. If state recovery
is needed, compare a candidate version with live AWS resources and have the state owner approve the
restore; preserve the current state version before recovery.

## Operations ownership

The environment `Owner` owns topology and workload coordination. `CostCenter` owns cost review.
`flow_log_operations_owner` owns Flow Logs access/retention and telemetry use. The supplied SNS
topic owner receives per-NAT alarms: `ErrorPortAllocation` maximum greater than zero for three
consecutive five-minute periods, and dropped packet ratio above 0.01 percent in two of three
one-minute periods. The feature does not invent team names or account resources; map these roles to
the organization before enabling an authenticated plan.
