# Arcane Realm — architecture, security, and operations blueprint

This is a target-state blueprint, not a claim that these services or protections are already implemented. Start small; introduce each component when the gameplay slice needs it.

## 1. Authority boundaries

### Client
The browser client is responsible for rendering, input collection, animation, audio, presentation, safe local feedback, sending player intentions to trusted services, and displaying server-confirmed state.

The client is not authoritative for Sigil balances, inventory ownership, item rarity, quest completion, reward eligibility, combat damage, drops, XP, cooldown completion, account identity, staff permissions, or moderation actions.

### Trusted service layer
When persistence/multiplayer is introduced, the trusted service layer validates and commits all valuable state transitions. It should enforce authorization, schema validation, rate limits, idempotency, transaction boundaries, and audit logging.

### Integrations
Discord identity/community integration may be considered later. It must not become the system of record for gameplay. The website and event bot remain separate repositories and services.

## 2. Data domains

Potential domains to model explicitly:
- Accounts and linked identities.
- Characters and character progression.
- Traditions/appearance selections.
- Inventory, item definitions, item instances, equipment, and ownership history.
- Sigil accounts and immutable ledger entries.
- Quests, objectives, claims, and completion history.
- Combat encounters, server-validated results, XP, and drops.
- Familiars and unlock/equip state.
- World/region/portal state.
- Staff roles, permissions, approvals, and audit events.
- Content definitions and versioned configuration.

Keep content definitions separate from player-owned instances. Use stable IDs and explicit schema versions.

## 3. Sigil Ledger

Use an append-only transaction ledger rather than treating a mutable balance field as the only truth.

Each transaction should include a unique transaction/operation ID, account/character identifier, amount and currency, transaction type (earn, spend, refund, adjustment), source/reason and related quest/shop/action identifier, actor or trusted service identity, server timestamp, idempotency key, and resulting balance or deterministic reconciliation method.

Requirements:
- Validate non-negative balances unless an explicitly approved debt model exists.
- Use atomic database transactions for ledger write and related reward/purchase state.
- Reject replayed idempotency keys.
- Do not accept a balance supplied by the client.
- Log staff adjustments with reason and approver.
- Reconcile ledger-derived balances against cached/read-model balances.

## 4. Inventory protection

- Distinguish item definitions from item instances.
- Give unique/valuable item instances stable IDs.
- Validate ownership on every equip, consume, trade, mail, drop, or transfer operation.
- Use atomic transfer semantics: remove from source and assign to destination in one transaction.
- Prevent duplicate reward claims and replayed requests.
- Validate stack bounds, item compatibility, capacity, binding rules, and trade restrictions.
- Preserve audit history for valuable items.
- Build safe recovery tools for accidental loss; never silently duplicate items to compensate.

## 5. Authentication and permissions

- Use a trusted identity provider or well-reviewed authentication mechanism; never roll custom password crypto.
- Secure sessions with appropriate expiry, rotation, CSRF protections where applicable, and secure cookie settings.
- Separate authentication (who the actor is) from authorization (what they may do).
- Use least privilege and scoped staff roles.
- Require explicit permission checks server-side for every admin action.
- Protect account linking against identity swapping and replay.
- Record security-sensitive account events.
- Provide a documented account recovery process.

## 6. API and abuse protection

- Validate all request schemas at the boundary.
- Apply rate limits and abuse controls by account, session, and network signals as appropriate.
- Use server timestamps for cooldowns and reward windows.
- Make state-changing operations idempotent.
- Protect against replay, race conditions, request flooding, forged identifiers, mass assignment, and authorization bypass.
- Avoid trusting client clocks, local save files, hidden fields, or UI-disabled buttons.
- Keep secrets server-side and rotate exposed credentials.
- Return safe errors; do not leak stack traces, secrets, or internal data.

## 7. Backups and recovery

- Define RPO/RTO targets before production.
- Back up databases and essential configuration; include asset/content manifests where needed.
- Encrypt backups and restrict access.
- Verify backup integrity and retention.
- Perform scheduled restore drills into an isolated environment.
- Document partial restore and point-in-time recovery procedures.
- After restoration, reconcile Sigil Ledger, inventory ownership, reward claims, and audit history.
- Record who initiated and approved recovery.

## 8. Monitoring and incident response

Monitor availability, latency, error rates, resource usage, authentication failures, suspicious linking, reward/ledger anomalies, inventory duplication or impossible transitions, quest/reward claim spikes, staff/admin actions, backup completion and restore readiness, and privacy-safe client crash/performance signals.

Incident workflow:
1. Detect and classify severity.
2. Contain abuse or faulty writes without destroying evidence.
3. Preserve relevant logs and transaction IDs.
4. Notify the authorized owner/staff.
5. Fix and validate in a safe environment.
6. Reconcile affected player state.
7. Restore only under an approved plan.
8. Write a postmortem with prevention actions.

## 9. Testing strategy

- Unit tests for rules and invariants.
- Integration tests for database transactions and authorization.
- End-to-end tests for onboarding, combat, quest completion, rewards, inventory, and reconnect.
- Concurrency tests for simultaneous claims, purchases, trades, and spending.
- Property/fuzz tests for malformed and boundary inputs.
- Adversarial tests for replay, duplicate requests, spoofed IDs, forged balances, and privilege escalation.
- Load/performance tests for expected player counts and mobile devices.
- Backup/restore drills and migration rehearsal.

## 10. Architecture evolution

Do not build a large distributed backend before the first fun playable slice exists. Begin with clean domain boundaries and local prototype state if appropriate. When online persistence is introduced, move valuable state transitions behind trusted services and migrate deliberately.

The initial engine/rendering choice remains open. Phaser is 2D and may be considered only if its 2.5D/isometric capabilities meet the target. If true 3D is required, evaluate a suitable browser 3D renderer before committing.
