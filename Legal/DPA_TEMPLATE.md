# Data Processing Addendum — TEMPLATE (DRAFT)

> **NOT LEGAL ADVICE.** This file is a starting-point template engineered to mirror
> the behavior of the LuciaMetricsSDK (tiered collection, region gating, retention
> TTL, AES-GCM at-rest encryption, no person-level merging, on-device consent
> receipts). It is **not** a binding contract. Before using this with any client,
> have it reviewed and adapted by qualified privacy counsel (e.g., the firm
> already engaged via Kat Esquire / DLA Piper). Once finalized, store the
> negotiated version per-client outside this repository.

---

## 1. Parties

This Data Processing Addendum (**"DPA"**) supplements the master agreement (the
**"Agreement"**) between:

- **Lucia / ClickInsights** (**"Processor"**), and
- _\[Client legal entity\]_ (**"Controller"**)

(each a **"Party"** and together the **"Parties"**).

## 2. Definitions

Capitalized terms not defined here have the meaning given in GDPR (Regulation
(EU) 2016/679), the UK GDPR, and the California Consumer Privacy Act / California
Privacy Rights Act (collectively, **"Data Protection Laws"**).

- **"Personal Data"** — any information processed under this DPA that relates to
  an identified or identifiable natural person, as defined by Data Protection
  Laws.
- **"Processing"** — any operation performed on Personal Data, whether or not by
  automated means.
- **"Sub-processor"** — any third party engaged by Processor to process Personal
  Data on behalf of Controller.

## 3. Roles and Scope

3.1 The Parties acknowledge that Controller is the **data controller** of the
Personal Data processed under this DPA, and Processor is the **data processor**
(or **service provider** under CCPA).

3.2 Processor will only Process Personal Data on documented instructions from
Controller, including the instructions embedded in the SDK configuration
(`DataCollectionTier`, `RegionPolicy`, `DataMinimizationOverrides`,
`RetentionPolicy`, `RateLimitPolicy`).

## 4. Categories of Data and Data Subjects

The categories of Personal Data and the data subjects are determined by
Controller's chosen `DataCollectionTier`:

| Tier  | Category                           | Data Points                                                                       |
| ----- | ---------------------------------- | --------------------------------------------------------------------------------- |
| 1+    | Identifiers                        | IDFA (post-ATT only) or IDFV, Lucia ID, optional username, session ID (SHA-256)   |
| 1+    | Coarse Device                      | Model, OS version                                                                 |
| 2+    | Product Interaction (touch events) | Coordinates, pressure, size, velocity, distance, event type, timestamp            |
| 3     | Network                            | IP address (IPv4)                                                                 |
| 3     | Extended Device                    | CPU cores, memory, device pixel ratio                                             |
| 3     | Screen / Locale                    | Width, height, orientation, color depth, color gamut, timezone, language          |

Data subjects: end users of Controller's mobile application.

## 5. Purpose of Processing

Processor will Process Personal Data only to: (a) provide the analytics and
fraud-signal services described in the Agreement; (b) maintain, secure, and
debug the service; and (c) comply with applicable law. Processor will not
Process Personal Data for advertising, profiling for advertising, or sale (as
defined under CCPA).

## 6. Lawful Basis and Consent

6.1 Controller is responsible for establishing the lawful basis for Processing
under Data Protection Laws (typically consent or legitimate interest).

6.2 The SDK records a `ConsentReceipt` on every ATT decision capturing the
active tier, scope, and timestamp. Controller is entitled to audit these
receipts on Controller's devices on reasonable notice.

## 7. Sub-processors

7.1 Controller authorizes Processor to engage the Sub-processors listed in
Annex A. Processor will give Controller at least **30 days** advance notice of
any new Sub-processor and will ensure each Sub-processor is bound by terms no
less protective than this DPA.

## 8. Security Measures

Processor will implement and maintain the technical and organizational measures
described in Annex B, which include at minimum:

- TLS for all data in transit, with optional SPKI certificate pinning.
- AES-256-GCM encryption for touch events at rest on the device.
- Per-install key stored in iOS Keychain
  (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- Tiered data minimization, per-field overrides, and regional auto-disable.
- Rate limiting and quota enforcement to bound exposure from a misbehaving
  client.
- Retention TTL with automatic purge of expired touch events.
- HTTPS-only communication.
- Access controls and least-privilege access for Processor personnel.

## 9. International Transfers

For transfers from the EEA, UK, or Switzerland to a country not deemed
adequate, the Parties will execute the EU Standard Contractual Clauses
(Decision 2021/914) and any required UK addendum or Swiss equivalent.

## 10. Data Subject Requests

10.1 Processor will, on Controller's reasonable request and at Controller's
expense, assist Controller in responding to data-subject requests under Data
Protection Laws, including access, rectification, erasure, restriction,
portability, and objection.

10.2 Because the SDK operates at the device level and does not maintain a
person-level join, deletion of a specific data subject's records can be
performed by deleting all records associated with the relevant Lucia ID(s).

## 11. Retention and Deletion

11.1 On-device touch events are retained no longer than
`RetentionPolicy.touchEventTTL` (default 7 days) and are auto-purged.

11.2 On termination of the Agreement, Processor will, at Controller's choice,
delete or return all Personal Data within **30 days**, unless retention is
required by law.

## 12. Audits

Once per year and on reasonable notice, Controller may audit Processor's
compliance with this DPA, by either (a) reviewing Processor's most recent
SOC 2 Type II report (if available) or (b) submitting a written questionnaire.
On-site audits are permitted only where required by Data Protection Laws and
will be at Controller's cost.

## 13. Personal Data Breach

Processor will notify Controller without undue delay (and in any event within
**72 hours**) after becoming aware of a Personal Data breach affecting
Controller's data, and will provide Controller with sufficient information to
meet its own notification obligations.

## 14. CCPA / CPRA Specific Terms

14.1 Processor is a "service provider" as defined by CCPA. Processor will not
(a) sell or share Personal Data, (b) retain, use, or disclose Personal Data
outside the direct business relationship between the Parties, or (c) combine
Personal Data received from Controller with Personal Data from any other
source, except as permitted by CCPA Reg. § 7050(b).

14.2 Where Controller's app is distributed in California, Controller must use
the SDK's `RegionPolicy` to gate or downgrade collection unless Controller has
a CCPA-compliant consent flow in place.

## 15. Term

This DPA is effective on the Effective Date of the Agreement and continues for
the longer of (a) the term of the Agreement and (b) the period during which
Processor processes any Personal Data on Controller's behalf.

---

## Annex A — Authorized Sub-processors

| Name                    | Role                                | Location |
| ----------------------- | ----------------------------------- | -------- |
| _\[Cloud provider\]_    | Hosting / storage                   | _\[…\]_  |
| _\[Email vendor\]_      | Transactional notifications        | _\[…\]_  |
| _\[Monitoring vendor\]_ | Application performance monitoring | _\[…\]_  |

> Replace placeholders with the actual Lucia infrastructure stack before
> execution. Add or remove rows as the architecture evolves; client must be
> notified of changes per Section 7.1.

## Annex B — Technical and Organizational Measures (TOMs)

1. **Transport security** — TLS 1.2+ for all SDK→backend traffic. SPKI
   certificate pinning available via `LuciaSDKPinnedCertHashes` Info.plist key.
2. **Storage security** — Touch events encrypted at rest with AES-256-GCM. Key
   material held in iOS Keychain with
   `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
3. **Data minimization** — Default `DataCollectionTier.tier1Metrics`. Tier 3
   requires affirmative client opt-in plus signed DPA. Per-field exclusions via
   `DataMinimizationOverrides`.
4. **Region gating** — `RegionPolicy.disableInRestrictedRegions` is the default
   posture; EU and California traffic is dropped before any ATT prompt or
   network call unless Controller explicitly opts into a higher tier.
5. **Retention** — `RetentionPolicy.touchEventTTL` defaults to 7 days; consent
   receipts default to 24 months.
6. **Rate limiting** — Per-session and rolling-24-hour caps via
   `RateLimitPolicy` (defaults: 10,000 / session, 100,000 / 24h).
7. **Identifiers** — Device-level only. The SDK does not perform cross-device
   identity merging. The Lucia ID is a server-issued opaque string.
8. **Access control** — Role-based access to production systems; MFA required;
   audit logs retained for 12 months.
9. **Vulnerability management** — Dependencies tracked and patched on a regular
   cadence. Critical CVEs patched within 30 days.
10. **Incident response** — Documented runbook; 72-hour breach notification per
    Section 13.

## Annex C — Schedule of Processing

- **Subject matter**: The Agreement.
- **Duration**: For the term of the Agreement plus the post-termination
  retention period.
- **Nature and purpose**: Mobile-app analytics and behavioral fraud signals.
- **Type of personal data**: As listed in Section 4 above.
- **Categories of data subjects**: Controller's app users.
