<!--
Sync Impact Report
- Version change: unratified scaffold → 1.0.0
- Modified principles: replaced template examples with eight AWS Terraform engineering principles
- Added sections: environment and operational constraints; delivery and review workflow
- Removed sections: none
- Follow-up TODOs: none
-->

# AWS Infrastructure Repository Constitution

## Core Principles

### I. Security and Data Protection
All infrastructure designs MUST apply least-privilege IAM, encrypt data at rest and in transit,
and keep secrets out of source control. Specifications and plans MUST identify sensitive data,
access boundaries, and encryption requirements where applicable. Public access and exceptions to
least privilege require explicit justification and review.

### II. Terraform as the Source of Truth
All changes to infrastructure managed by this repository MUST be made through reviewed Terraform
code. Console changes and other out-of-band modifications MUST NOT become an alternate management
path; emergency changes MUST be reconciled into Terraform through a reviewed follow-up change.

### III. Remote State Protection
Terraform state MUST be remote, encrypted, versioned where supported, and protected by locking.
Access MUST be restricted to authorized roles and separated by environment. State and plan files
MUST NOT be committed to source control because they can contain sensitive values.

### IV. Environment Isolation
Development, staging, and production MUST use separate configurations and separate state. Production
access and changes MUST have stricter authorization and review than non-production changes. Shared
resources MUST have documented ownership and environment boundaries.

### V. Private Networking by Default
Workloads and databases SHOULD run in private subnets. Every public endpoint or route MUST have a
documented workload need, an explicit exposure boundary, and appropriate access controls. Network
plans MUST describe ingress, egress, and trust boundaries relevant to the change.

### VI. Reliability and Recovery
Critical services MUST have availability, backup, and disaster recovery requirements defined before
implementation. Designs MUST document recovery objectives and dependencies when they affect service
restoration. Backup retention and recovery procedures MUST be appropriate to the data and workload.

### VII. Evidence Before Apply
Terraform changes MUST pass formatting, validation, and security scanning, and their execution plan
MUST be reviewed before apply. Applying changes requires the approvals defined for the target
environment. A successful tool run alone does not replace review of the plan and its impact.

### VIII. Consistent Governance
Infrastructure MUST use documented naming and tagging conventions, including required ownership and
environment metadata. Changes MUST include documentation needed to review, operate, and recover the
affected capability. Exceptions to this constitution MUST be recorded with rationale and approval.

## Environment and Operational Constraints

- Reusable modules MUST expose typed, documented inputs and outputs with safe defaults.
- Account identifiers, credentials, CIDRs, ARNs, and environment-specific values MUST NOT be
  hard-coded in reusable modules.
- Existing resources MUST have an ownership or import plan before Terraform assumes management.
- Availability, backup, and recovery requirements MUST reflect the workload's criticality and data
  classification.
- The repository MUST keep production and non-production state and access boundaries distinct.

## Delivery and Review Workflow

- Infrastructure changes MUST be specified, planned, implemented, and reviewed as small, traceable
  changes.
- Pull request review MUST cover the Terraform diff, security scan results, plan output, state impact,
  and operational documentation relevant to the change.
- Changes that affect shared or production infrastructure MUST receive the required environment
  approval before apply.
- Reviewers MUST identify any deviation from these principles and require an approved exception or
  remediation before merge or apply.

## Governance

This constitution governs specifications, plans, Terraform code, and operational guidance in this
repository. Amendments MUST be reviewed and documented with a version update. Versioning follows
semantic versioning: MAJOR for incompatible governance changes, MINOR for added or materially expanded
principles, and PATCH for clarifications that do not change obligations. Compliance MUST be reviewed
for each infrastructure change through the applicable specification, pull request, and plan review.
Any exception MUST name its scope, rationale, approver, and expiration or review condition.

**Version**: 1.0.0 | **Ratified**: 2026-10-28 | **Last Amended**: 2026-10-28
