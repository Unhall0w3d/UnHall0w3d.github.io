---
title: "AletheiaUC: Bringing UC Health to Light"
date: 2026-07-25T12:00:00-04:00
categories:
  - Cisco
  - Unified Communications
  - Automation
  - Python
tags:
  - AletheiaUC
  - Cisco
  - Cisco UC
  - Cisco Unified Communications Manager
  - Unity Connection
  - Automation
  - Python
  - Health Checks
  - Reports
description: "A look at what AletheiaUC is becoming: a read-only, evidence-led Cisco Collaboration assessment framework with normalized facts, conservative findings, and reports people can actually use."
image: "/assets/images/aletheiauc-current-state-social.jpg"
imageAlt: "Synthetic AletheiaUC Collaboration Health Assessment showing the report header and executive overview."
imageWidth: 1200
imageHeight: 630
draft: false
---

## There Has To Be A Better Way To Do This

A Cisco Collaboration health assessment can begin with a simple question.

Is the environment healthy?

It then becomes several browser tabs, a collection of CLI sessions, a few SOAP APIs, some SQL that should be approached with the correct amount of suspicion, screenshots named things like `final-actual-final-2.png`, and a spreadsheet that will eventually be asked to explain what all of it means.

The difficult part is not obtaining *some* data. Cisco UC systems are quite capable of producing data.

The difficult part is preserving where it came from, deciding what it actually proves, connecting related pieces across different interfaces, and turning the result into something useful without quietly upgrading an incomplete observation into a confident conclusion.

That is what [AletheiaUC](https://github.com/Unhall0w3d/aletheiauc) is being built to do.

The name comes from *Aletheia*: truth, disclosure, or unconcealedness. The idea is not that a script can descend from the mountain carrying perfect knowledge of every Collaboration environment. It is that the tool should make the evidence visible, keep its reasoning traceable, and be honest about what it could not collect.

This is where the project stands now.<!--more-->

## What AletheiaUC Is

AletheiaUC is a CLI-first, read-only, evidence-led health-assessment tool for Cisco Collaboration systems.

Its primary assessment coverage is Cisco Unified Communications Manager, including Session Management Edition, and Cisco Unity Connection. An assessment profile can combine multiple clusters—even multiple clusters of the same technology—while keeping each target's credentials, facts, and artifacts separate. Initial bounded diagnostic collection also exists for IM and Presence and Cisco Emergency Responder.

It is not intended to be another monitoring dashboard. It does not sit in the environment waiting to page someone at 3:00 AM. It does not make configuration changes, restart services, repair replication, upgrade firmware, or decide that a finding grants it permission to become helpful in exciting new ways.

It performs a bounded assessment, records what it observed, evaluates conservative rules, and produces evidence that an engineer can review.

The core path is intentionally simple:

```text
Collectors -> Normalized Facts -> Health Rules -> Reports
```

Collectors speak to the individual Cisco interfaces. Facts translate their various response shapes into a common model. Rules decide what those facts support. Report builders present the result for different audiences.

That separation matters.

An API response is evidence. A parsed value is a fact derived from that evidence. A warning is an interpretation made under a stated rule. Those are related things, but they are not interchangeable.

## What It Can See Today

On CUCM, the baseline begins with AXL and Publisher reachability. AletheiaUC can discover the cluster, identify nodes and versions, collect bounded phone inventory, inspect configured Device Default loads, and retain the underlying request and response evidence when diagnostic artifacts are enabled.

Diagnostic mode reaches further:

- RISPort registration and active firmware state.
- Control Center service status.
- PerfMon processor, memory, and CallManager counters.
- Per-node certificate-management snapshots and X.509 normalization.
- Bounded UCOS CLI evidence for NTP, database replication, DRS backup history, disk capacity, versions, services, and active core files.
- Call-routing and dial-plan relationships.
- Hunt pilots, hunt lists, line groups, and their directory-number membership.
- SIP trunks, destinations, route lists, route groups, and route-pattern relationships.
- LDAP, phone-security, SIP-security, media-resource, MRG, and MRGL configuration.
- Configured phone-load overrides, runtime firmware populations, and explicit download failures.

Some of that information arrives through ordinary AXL objects. Some requires bounded relationship reads. Some CUCM responses provide UUIDs where the useful value ought to be, so fixed, server-bounded read-only SQL is used to recover specific relationships without opening a general query surface.

The bounds are part of the feature.

AletheiaUC does not request every line in a large cluster because it would make the report more impressive. If an API ignores a requested page size or the configured maximum is reached, the result is marked partial or server-unbounded. “We received 500 records” and “there are exactly 500 records” are not the same statement.

Unity Connection follows the same philosophy through CUPI and bounded platform collection. The current implementation can inspect telephony integrations, ports, routing rules, schedules, mailbox stores, message-aging policy, Unified Messaging, SMTP security, cluster state, DRS evidence, service state, and selected platform health.

There are also three deliberately fixed experimental Unity Connection SQL probes for duplicate extensions and potentially important call-handler transfer paths. They are not a general-purpose database console. If a probe does not complete cleanly, AletheiaUC reports the limitation instead of guessing what the schema probably meant.

## The Report Is Part Of The Collection

Reporting is not the decorative stage at the end of this project.

A collector is not considered finished merely because it obtained a response. The raw evidence must be captured, parsed into normalized facts, interpreted by appropriate rules, exposed in JSON, and shown meaningfully in the HTML report.

Otherwise the feature exists mainly for the person reading the source code.

<span class="image fit"><a href="/assets/images/aletheiauc-generic-report-overview.jpg" target="_blank" rel="noopener"><img src="/assets/images/aletheiauc-generic-report-overview.jpg" alt="Synthetic generic AletheiaUC report showing its title and executive overview metric cards" loading="lazy" /></a></span>

*The generic report is intentionally unbranded and self-contained. Every environment name, address, device, count, and finding shown in these screenshots comes from AletheiaUC's built-in synthetic SampleCollector—not a customer assessment.*

The report currently has a generic dark template that ships with the project. It contains no company logo, remote imagery, analytics, web fonts, or external scripts. Additional presentation can be installed as a local data-only template pack without changing collection logic, findings, or customer-data policy.

Every guided assessment produces two editions:

- The **engineering report** retains collection coverage, evidence references, reconciliation detail, collector notes, and the technical mechanics needed to review the assessment itself.
- The **customer-facing report** retains the operational names, devices, dial-plan values, configuration, and actionable findings needed to understand the environment while omitting private artifact paths and engineering-only collection detail.

The customer report is not a vague executive brochure where every technical detail has been translated into a colored circle and a reassuring sentence. The intended audience still includes customer engineers who need to know *which* trunk, device, service, certificate, route pattern, or mailbox policy requires attention.

Both editions can be rendered as self-contained HTML and local PDF. JSON output remains available for development and automation. Diagnostic runs can also assemble a private review ZIP containing logs, artifacts, and report variants for deeper engineering review.

Nothing needs to be uploaded to a report service.

## Findings Need To Explain Themselves

A finding should answer three questions:

1. What did we observe?
2. Why does it matter?
3. What should someone do next?

<span class="image fit"><a href="/assets/images/aletheiauc-generic-report-findings.jpg" target="_blank" rel="noopener"><img src="/assets/images/aletheiauc-generic-report-findings.jpg" alt="Synthetic AletheiaUC priority finding showing lifecycle evidence, operational impact, and a recommended next step" loading="lazy" /></a></span>

*A synthetic lifecycle finding demonstrates the current finding structure: severity, observed facts, impact, supporting detail, and an actionable recommendation.*

This sounds obvious until a report says “database replication warning” with no state, node, collection time, or indication of whether the check actually completed.

AletheiaUC distinguishes:

- Healthy from unhealthy.
- Unavailable from failed.
- Skipped from unsupported.
- Partial from complete.
- Informational context from an actionable warning.
- A stale trust-store certificate from an active service-certificate failure.
- A service that stopped unexpectedly from one that was never activated by design.

That last category of distinction is where much of the real work lives.

For example, a phone with a configured load is not necessarily misconfigured; it may be pinned intentionally. A static override still deserves visibility because it will remain pinned through later Device Default changes. An unregistered object may be a phone, a SIP trunk, a media resource, or a non-runtime configuration object. An old certificate in a trust store is not proof that a live service is broken.

The tool should report the condition it can demonstrate, not the most alarming story that could be assembled from the same nouns.

## Inventory Is Only Useful When It Reconciles

Configured inventory and runtime registration are different views of the environment.

AXL can describe what should exist. RISPort can describe what registered during the captured runtime snapshot. A useful assessment has to reconcile the two without forcing unrelated objects into the same category.

<span class="image fit"><a href="/assets/images/aletheiauc-generic-report-device-health.jpg" target="_blank" rel="noopener"><img src="/assets/images/aletheiauc-generic-report-device-health.jpg" alt="Synthetic AletheiaUC device inventory and registration summaries grouped by model and runtime category" loading="lazy" /></a></span>

*The synthetic device section separates configured inventory from registration state, then groups runtime objects into phones, gateways or endpoints, and SIP trunks.*

That reconciliation now feeds dedicated views for phone models, device pools, locations, registration nodes, firmware, trunks, gateways, media resources, and other known runtime-capable objects.

It also retains an engineering appendix for the records that do not reconcile cleanly. That is not report debris. It is how the next parser gap or classification problem becomes visible.

One of the recurring lessons from building AletheiaUC has been that the awkward records at the bottom of a report are often trying to explain what the collector does not understand yet.

## Safety Is An Architectural Requirement

The project stores connection profiles locally with encrypted credentials. Multi-cluster, multi-technology assessment profiles reference those connections without copying passwords into the grouping file.

HTTPS behavior is explicit because Cisco UC environments commonly use self-signed or privately issued certificates. By default, AletheiaUC warns and proceeds; verification can be required with system trust or a supplied CA bundle.

SSH host keys are enrolled sequentially before bounded parallel collection begins. Interactive runs show the host, algorithm, and fingerprint and require explicit approval before saving the key. Later connections verify it, and a changed key stops collection instead of being quietly accepted because the assessment had already developed momentum.

Raw artifacts receive private filesystem permissions where the platform supports them. Structured evidence is scrubbed for common secrets before storage, but diagnostic bundles are still treated as customer-sensitive engineering material.

This is also why the customer-facing report and the diagnostic review bundle are different things.

The report is a deliverable.

The bundle is evidence custody.

## Where It Is Now

AletheiaUC has moved beyond the early API-collector skeleton and is now being hardened for production CUCM and Unity Connection reporting.

That is not the same as claiming universal production readiness.

Every collector and finding still needs to be validated against the customer-approved UC release, deployment model, credentials, topology, and maintenance constraints in which it will be used. CUCM 14 and 15 have now been validated. Other paths are implemented and covered by fixtures but still need broader field validation, particularly certificate and trust normalization, bounded relationship enrichment, and several Unity Connection variations.

CUCM 12 and 11.5 remain pending validation. So do additional Unity Connection releases and deployment shapes. Cisco APIs have a long and distinguished tradition of returning approximately the same information in creatively different forms.

The project can also build a portable bootstrap ZIP for Windows or Linux operators who cannot use Git. It creates its own local Python environment and installs the report dependencies, including a local Chromium runtime when PDF export is available. HTML-only reporting remains an option where browser installation is blocked.

That is a much more complete system than the original collector skeleton.

It is also not finished.

## What Is Still On The List

The next phase is less about adding every available Cisco interface and more about strengthening the boundaries around the ones already present.

Current priorities include:

- **Cross-version and multi-cluster validation.** With CUCM 14 and 15 validated, continue with CUCM 12 and 11.5, additional Unity Connection releases, and mixed assessments containing multiple clusters of the same technology.
- **Certificate and trust validation.** Complete fresh CUCM 15 testing for parsed chains, trust-store coverage, deduplication, and optional phone trust stores.
- **Deeper Unity Connection validation.** Confirm CUPI field variants, message-aging child resources, SMTP availability differences, platform output, and experimental fixed-query behavior across versions.
- **Shared UCOS collection.** Continue refining the common bounded Publisher baseline already used by IM&P and CER, while preserving the richer role-aware discovery, parsing, and health policy required by CUCM and CUC.
- **First-class IM&P and CER assessment.** Move beyond the current diagnostic scaffolding into validated collectors, normalized facts, and technology-specific health rules.
- **Stable report architecture.** Preserve the shared reader-oriented chapter sequence and treat plugin-owned report sections as an optional future refactor—not a prerequisite for useful reporting.
- **Policy depth.** Promote carefully validated runtime observations into independent baseline collectors and named service, topology, and capacity policies.
- **Windows hardening.** Validate private-file behavior and the review-bundle workflow on the platform where many field assessments will actually run.
- **Module decomposition.** Break apart several responsibility-dense application, configuration, rules, and report modules without destabilizing current behavior.

There is a GUI somewhere beyond that horizon.

It can remain there for now.

The engine needs to know the difference between evidence and assumption before it needs a prettier button for running the same assumption.

## More Light, Fewer Mysteries

The eventual goal is not to replace the engineer performing the assessment.

It is to remove the repetitive collection work, preserve the evidence, expose the relationships, and make the remaining engineering judgment better informed.

AletheiaUC should be able to say:

- This is what the environment reported.
- This is how the data was collected.
- This is the rule that interpreted it.
- This is why the condition matters.
- This is what we recommend doing next.
- This part could not be evaluated.

That last sentence is as important as the others.

There are already enough systems capable of generating confidence.

I would rather build one that earns it.
