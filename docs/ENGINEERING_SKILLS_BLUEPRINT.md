# Arcane Realm — engineering skills blueprint

## Purpose

This is the internal engineering playbook for Claude, ChatGPT, and human collaborators building and operating Arcane Realm. These are reusable development skills and operational procedures—not player-facing game features.

The user asked for a 20-skill framework. The core names and domains below consolidate names recovered from prior project context. Where an exact historic title was not preserved, the title is marked as a working name; the responsibility is the important part and should not be silently treated as a previously approved brand name.

## The 20 reusable skills

| # | Skill | Responsibility |
|---|---|---|
| 1 | **Arcane Shield** | Threat modeling, secure defaults, input validation, exploit prevention, abuse cases, and security review. |
| 2 | **Sigil Ledger** | Authoritative currency ledger; immutable transaction history; idempotent grants/spends; reconciliation and anti-duplication. |
| 3 | **Inventory Guardian** | Item ownership, stack rules, transfer/equip/consume validation, unique item identity, duplication prevention, and recovery. |
| 4 | **Identity Guardian** | Authentication, account linking, session safety, authorization, role boundaries, and account recovery. |
| 5 | **Chronos Backup** | Scheduled, verified backups with retention, encryption, integrity checks, and backup health reporting. |
| 6 | **Realm Restore** | Controlled restoration, point-in-time recovery where supported, restore verification, and post-restore reconciliation. |
| 7 | **World Snapshot** | Consistent snapshots of world/player/configuration state for releases, migrations, and incident recovery. |
| 8 | **Data Integrity Scanner** | Detect orphaned records, invalid references, impossible values, ledger mismatches, duplicate ownership, and corruption. |
| 9 | **Migration Guardian** | Safe schema/data migrations, compatibility checks, dry runs, rollback plans, and migration verification. |
| 10 | **Recovery Simulator** | Game-day exercises for backup failure, partial writes, service outages, corruption, and recovery-time objectives. |
| 11 | **Arcane Watchtower** | Monitoring, metrics, structured logs, alert thresholds, service health, and operational dashboards. |
| 12 | **Realm Inspector** | Read-only diagnostics for world/player state, quest progression, inventory, economy, and configuration anomalies. |
| 13 | **Testwright** *(working title)* | Unit, integration, end-to-end, regression, property-based, and adversarial testing. |
| 14 | **Release & Rollback Guardian** *(working title)* | Build provenance, release checks, staged rollout, rollback criteria, and deployment verification. |
| 15 | **Incident Response Warden** *(working title)* | Incident triage, containment, evidence preservation, communication, remediation, and postmortems. |
| 16 | **Admin Toolsmith** *(working title)* | Safe staff utilities, scoped permissions, approval flows, reason codes, audit trails, and reversible actions. |
| 17 | **Realm Sentinel** | Continuous integrity/security watch: detect suspicious behavior, flag anomalies, and route sensitive actions for review. |
| 18 | **Content Consistency Checker** *(working title)* | Validate quests, items, NPC dialogue, rewards, progression references, localization keys, and asset references. |
| 19 | **Economy Balance Oracle** *(working title)* | Simulate reward sources/sinks, progression pacing, inflation, exploit incentives, and item/currency balance. |
| 20 | **Version Control Guardian** *(working title)* | Branch hygiene, change review, dependency/license checks, release tags, provenance, and repository boundary enforcement. |

## Skill execution contract

Every skill should:
1. State its purpose and when to invoke it.
2. List required inputs and authoritative sources.
3. Define preconditions and safety checks.
4. Produce a predictable output (report, patch, test result, or approved action).
5. Identify destructive or high-impact operations.
6. Require explicit approval for production-impacting actions.
7. Log decisions and evidence without leaking secrets or private player data.
8. Include tests or verification appropriate to its responsibility.

## Mandatory approval boundaries

- No production deploy, live migration, account ban, currency grant/removal, item deletion, rollback, restore, or bulk player mutation without explicit authorized approval.
- Dangerous admin actions should use least privilege, reason codes, confirmation, audit records, and where appropriate a second-person approval.
- Diagnostics default to read-only.
- Never let an AI agent grant itself permissions or bypass approval gates.
- Never expose internal skill interfaces to ordinary players.

## Quality gates

Before a release:
- Type checks and lint pass.
- Unit and integration tests pass.
- Critical gameplay flows pass end-to-end checks.
- Currency and inventory invariants pass.
- Authorization and abuse tests pass.
- Migration and restore rehearsal pass when data/schema changes.
- Dependency and license review is complete.
- Mobile input, responsive UI, and performance are checked.
- Rollback plan and monitoring are ready.
- Release notes and known limitations are recorded.

## Core invariants to enforce

- A Sigil cannot be spent twice.
- A reward cannot be claimed more than once unless explicitly repeatable.
- An item cannot be owned by two players simultaneously unless the item model explicitly supports shared ownership.
- A client cannot choose its own authoritative reward, balance, rarity, ownership, combat result, or permission.
- Every valuable mutation has a traceable actor, reason, timestamp, and unique operation ID.
- Retries must not duplicate effects.
- A restore must not silently reintroduce already-consumed rewards or duplicate inventory.
- Staff tools must not bypass the same integrity rules enforced for player actions.

## Working-name note

The recovered project history preserves the names Arcane Shield, Sigil Ledger, Inventory Guardian, Identity Guardian, Chronos Backup, Realm Restore, World Snapshot, Data Integrity Scanner, Migration Guardian, Recovery Simulator, Arcane Watchtower, Realm Inspector, and Realm Sentinel. Other labels above are practical working names to complete the requested 20-skill catalog; retain or rename them with the user rather than pretending their exact earlier names are known.
