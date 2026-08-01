---
title: "When an Analog Call Refuses to Die"
date: 2026-08-01T12:00:00-04:00
categories:
  - Cisco
  - IOS/XE
  - Unified Communications
  - Automation
tags:
  - Cisco
  - IOS XE
  - EEM
  - Tcl
  - Voice Gateway
  - FXO
  - FXS
  - Automation
  - Analog Voice
description: "Building a conservative IOS XE EEM guard that can identify a genuinely stuck analog call, recover one exact voice port, and prove what happened without turning a timer into a blind automation hammer."
draft: false
---

## The Call Ended. The Port Disagreed.

Analog voice ports occupy an interesting part of a modern collaboration environment.

They are usually quiet. They are frequently attached to something important. And when one decides that a call should continue existing long after everyone else has moved on, the failure can be both remarkably small and disproportionately annoying.

That was the problem here: a call could remain active on an analog FXS or FXO path after it should have cleared. From the gateway's perspective, the voice port and call leg remained off-hook. From an operational perspective, the line was now occupied by a call that no longer had any useful reason to exist.

The immediate fix was simple enough: reset the affected voice port.

The harder question was whether the gateway could recognize the condition, prove that it was looking at the correct port and call, recover it automatically, and leave enough evidence behind to explain exactly what happened.

Naturally, that became a Tcl policy.<!--more-->

## A Stuck Call Is Not Just A Long Call

A long-running call is not automatically broken.

An analog call may be expected to remain connected for an extended period. A port may also report one useful piece of state while another IOS surface is delayed, degraded, or describing a different layer of the same call.

That meant elapsed time could only be the beginning of the decision—not the decision itself.

The policy needed to distinguish between:

- a legitimately long call;
- an off-hook port without a qualifying active call;
- a long call on a different port;
- stale or partially inconsistent state;
- and the exact long-running analog call the recovery was designed to address.

There is another important boundary here: the validated implementation was built for an **FXO loop-start port**. The broader operational problem can occur on FXS and FXO interfaces, but their state vocabulary is not interchangeable. An FXS version should have its own exact state contract, fixtures, and maintenance-window validation rather than inheriting the FXO matchers and hoping the words are close enough.

## Make IOS Prove It Four Times

The final detector requires four observations to agree before a call can even become a recovery candidate.

1. IOS must report a `TELE` call leg older than the configured threshold using its native duration filter.
2. The full active-call detail must map that same **decimal CallID** to the exact analog port.
3. The voice-port summary must show the target port administratively up and off-hook.
4. The voice-call summary must report the expected FXO off-hook state for that same port.

In generalized form, the evidence comes from commands like these:

```text
show call active voice compact duration more <SECONDS>
show call active voice brief
show voice port summary
show voice call summary
```

The script does not maintain its own stopwatch and decide that a call is old because it remembers seeing it earlier. IOS's duration filter is the source of truth for the threshold.

It also does not stop at finding *a* long `TELE` leg. The full decimal CallID has to appear in the active-call brief and map back to the one configured voice port. This prevents a call elsewhere on the gateway from accidentally authorizing recovery here.

Only after all four surfaces agree does the policy log a match.

Then it does the impolite but necessary thing: it gathers the evidence again.

Immediately before any configuration change, the policy re-runs the detector and requires the same CallID and the same port state to survive revalidation. If the call cleared, changed, or stopped matching while the policy was deciding what to do, no action is taken.

That small second look is probably the most important part of the design.

## Observe First, Recover Later

The policy is observe-only by default.

Automatic recovery requires three separate settings:

- enforcement must be enabled;
- voice-port recovery must be explicitly allowed;
- and the operator must acknowledge the hardware boundary around the port and its module.

If any one of those is missing, the policy can identify and report the condition but cannot touch the configuration.

When recovery is fully authorized, the mutation is intentionally narrow:

```text
configure terminal
 voice-port <FXO_PORT>
 shutdown
 no shutdown
end
```

There is no call clearing by called number, no attempt to clear every analog leg, and no broad module reset.

The policy also records a cooldown using native EEM context. A second recovery cannot immediately follow the first, and invalid or unpreservable cooldown state fails closed. If something fails after `shutdown`, the error path makes a best-effort attempt to issue `no shutdown` and leave configuration mode before terminating.

Automation is allowed to be useful. It is not allowed to be casual.

## What The Evidence Looks Like

The following is a **sanitized, representative reconstruction** of the bounded syslog sequence. The gateway name, port, CallID, timestamps, and policy marker have been generalized; these are not customer logs.

```text
Aug 01 14:22:00 <GATEWAY> %HA_EM-4-LOG:
2026-08-01 14:22:00 UTC ANALOG_CALL_GUARD matched long off-hook FXO call call_id=<CALL_ID> direction=ANS port=<FXO_PORT> duration_gt=900s enforce=1

Aug 01 14:22:01 <GATEWAY> %HA_EM-3-LOG:
2026-08-01 14:22:01 UTC ANALOG_CALL_GUARD bouncing voice-port <FXO_PORT> after verified call_id=<CALL_ID> exceeded 900s

Aug 01 14:22:09 <GATEWAY> %HA_EM-5-LOG:
2026-08-01 14:22:09 UTC ANALOG_CALL_GUARD voice-port <FXO_PORT> returned from the verified off-hook state
```

That last line is deliberately conservative. The policy proves that the two surfaces no longer jointly report the same off-hook condition; it does not turn that absence into a more specific claim than the code actually tested.

During validation, the post-recovery operational checks confirmed the expected idle state:

```text
<FXO_PORT>  --  fxo-ls  up  dorm  idle  on-hook  y
<FXO_PORT>  -   -       -                 FXOLS_ONHOOK
```

So the complete evidence chain was:

1. identify the aged call;
2. correlate it to the exact port;
3. confirm both off-hook surfaces;
4. revalidate the same candidate;
5. record the recovery action;
6. confirm the off-hook condition cleared;
7. and verify the port returned to its expected on-hook state.

The policy emits only bounded status messages to IOS syslog. It does not create its own log files, copy command output to flash, or leave a growing forensic novel on the gateway.

## How We Validated It

The first tests were intentionally boring.

The policy was registered with every mutation setting disabled. The duration threshold was temporarily reduced for an approved test call, and debug logging was enabled so a failed detector would identify the first evidence stage that did not match.

That let us verify the important pieces without permitting recovery:

- the correct decimal CallID was discovered;
- the call mapped to the intended port;
- the two off-hook state surfaces agreed;
- and the policy reported `observe-only` instead of changing configuration.

We then ended the call normally and confirmed the port returned idle.

Only after that dry run did we enable the three recovery gates during an approved test window. The test call exceeded the reduced threshold, the policy detected and revalidated it, the port bounce cleared the call, and the post-action checks returned to on-hook.

The production threshold and non-debug logging were restored after validation.

## Lessons Learned Along The Way

### Call IDs Were More Complicated Than They Looked

The most tempting approach was to find the call and clear it directly by ID.

The available command paths did not give us a safe, consistent contract for doing that with the full active-call identifier. Truncated or differently represented IDs introduce exactly the kind of ambiguity an automated recovery should not tolerate.

The safer approach was to use the full decimal CallID for **correlation**, then recover only the already-known physical port.

### One State Surface Was Not Enough

Requiring only `off-hook` from the port summary would have been easy. Requiring only an active call older than a threshold would have been easier.

Neither proved enough by itself.

The useful confidence came from joining the duration-filtered call, full CallID-to-port mapping, port state, and call state. A stuck call may lose an operational `up` or connected state while remaining genuinely stuck, so the detector avoids requiring transient fields that can disappear during the failure it is meant to catch.

### IOS Output Is Still CLI Output

IOS command output commonly arrives with CRLF line endings, which matters when Tcl is using exact line-anchored regular expressions. Normalizing carriage returns before matching removed an entire class of almost-correct failures.

We also confirmed that a CLI helper can receive IOS rejection text without Tcl necessarily raising an exception. The wrapper therefore treats messages such as invalid input, ambiguous command, incomplete command, and command-authorization failure as real failures.

If the router says no, the automation does not get to reinterpret that as maybe.

### Native State Beat Private Files

Earlier design directions considered marker or log files for cooldown and evidence. The final version uses native EEM context for the cooldown and IOS syslog for evidence.

That reduced filesystem behavior, eliminated private policy files that would need their own lifecycle, and made failure behavior easier to reason about. If the cooldown cannot be preserved, recovery is skipped.

### Exact Verification Language Matters

There is a meaningful difference between “the port is no longer jointly off-hook” and “the port is definitely on-hook.”

The current policy logs the first statement because that is what its immediate post-action detector proves. The accompanying operational validation confirms the second. A future revision could add an explicit exact on-hook matcher and a separate success message, but it should only do so after that state contract is tested across the intended platforms.

## Where I Would Take It Next

The policy solves one bounded failure mode on one explicitly configured FXO port. That limitation is a feature.

Useful next steps would be:

- add an exact on-hook post-recovery matcher and distinct verification syslog;
- build separate, validated state contracts for FXS ports;
- package representative IOS output as offline detector fixtures;
- expose an operator-readable reason when each detector stage fails;
- and document platform or release differences as they are actually observed.

What I would not do is turn the port into a list, loosen the regular expressions, and call the result universal.

Every additional port type or IOS variation should earn its way into the policy through evidence and testing.

## Download The Sanitized Reference Files

<details class="code-preview" data-code-preview="/assets/downloads/analog-stuck-call-guard-deployment-v1.0.6.md">
  <summary>
    <span>Preview the deployment and validation notes</span>
    <small>MARKDOWN // V1.0.6</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the sanitized Markdown file.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/analog-stuck-call-guard-v1.0.6.tcl">
  <summary>
    <span>Preview the IOS XE EEM Tcl policy</span>
    <small>TCL // V1.0.6</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the sanitized Tcl policy.</code></pre>
</details>

- <a href="/assets/downloads/analog-stuck-call-guard-v1.0.6.tcl" download>Download the IOS XE EEM Tcl policy</a>
- <a href="/assets/downloads/analog-stuck-call-guard-deployment-v1.0.6.md" download>Download the sanitized deployment and validation notes</a>

The distributed Tcl sample remains intentionally scoped to one FXO loop-start port. Review its `pa_port` value, change it for the intended gateway, and repeat observe-only and enforced validation before production use. FXS adaptation requires a separately validated state contract.

## A Small Automatic Hammer

There is nothing especially glamorous about resetting a voice port.

The interesting part is building enough restraint around that reset that it can be trusted to happen without a person watching the console at the exact moment a call decides not to die.

Observe first. Correlate the full identity. Require independent evidence. Revalidate before mutation. Recover one thing. Verify afterward. Leave a useful trail.

That is a lot of ceremony for `shutdown` and `no shutdown`.

It is also the reason I would let the gateway do it by itself.
