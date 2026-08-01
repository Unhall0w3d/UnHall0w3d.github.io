# Analog Voice-Port Off-Hook Guard — Deployment Notes

Policy version: 1.0.6

Target: Cisco IOS XE gateway with one validated FXO loop-start voice port

This public guide uses placeholders for deployment-specific values. The
downloadable policy contains a sample `pa_port` value; change that value to the
intended FXO port and validate every state matcher on the target hardware and
IOS XE release before enabling recovery.

Version 1.0.6 uses bounded IOS syslog for evidence and native EEM context for
cooldown state. It performs no policy filesystem operations.

## Intended behavior

Every 60 seconds the policy checks whether the configured FXO voice port has a
`TELE` call leg older than the configured threshold. The default threshold is
15 minutes. A candidate must satisfy all four observations:

1. `show call active voice compact duration more <SECONDS>` contains an aged
   `TELE` call leg;
2. the complete brief output maps that same decimal CallID to
   `Tele <FXO_PORT> (<CALL_ID>)`;
3. the exact port row is administratively up with output status `off-hook`;
4. the exact call row reports `FXOLS_OFFHOOK`.

The policy rechecks the same decimal CallID and both port states immediately
before acting. It does not use `show call active voice brief id`, `clear call
voice ... id`, truncated identifiers, called-number clearing, or a private
elapsed-time estimate.

When all explicit mutation settings are enabled, the only recovery is:

```text
configure terminal
 voice-port <FXO_PORT>
 shutdown
 no shutdown
end
```

## Observed state contract

Expected idle state on the validated FXO loop-start path:

```text
<FXO_PORT>  --  fxo-ls  up  dorm  idle  on-hook  y
<FXO_PORT>  -   -       -                 FXOLS_ONHOOK
```

Representative connected state:

```text
<FXO_PORT>  --         fxo-ls  up  up  idle  off-hook  y
<FXO_PORT>  <CODEC>    y       S_CONNECT  FXOLS_OFFHOOK
```

The policy intentionally does not require `OPER up` or `S_CONNECT`: a genuinely
stuck leg may have degraded to a different operational or VTSP state. The
long-duration active-call evidence, exact decimal CallID-to-port mapping, and
both off-hook surfaces remain mandatory.

This state contract was validated for FXO loop-start. Do not assume that an FXS
port exposes equivalent state. Build and validate a separate FXS contract before
adapting the policy to that interface type.

## Safety behavior

- Observe-only by default.
- One exact configured port; no other port can qualify.
- IOS's duration filter is the source of the threshold decision.
- Full decimal CallID correlation prevents unrelated `TELE` legs from qualifying.
- Evidence is revalidated immediately before mutation.
- Enforcement, bounce permission, and shared-module acknowledgement are separate.
- Native EEM context must be saved before recovery; invalid or unpreservable
  cooldown state fails closed.
- Default cooldown is 30 minutes.
- If an error occurs after `shutdown`, the policy makes a best-effort
  `no shutdown` and `end` recovery before terminating.
- IOS CLI rejection text is treated as failure even when `cli_exec` does not
  raise a Tcl exception.
- Evidence is emitted through bounded IOS syslog; the policy creates no private
  log or marker files.
- IOS CRLF command output is normalized before exact line matching.
- Optional debug logging identifies the first unmatched detector stage.
- EEM syslog failures fail the policy visibly rather than being silently swallowed.

## Prepare the public sample

Open `analog-stuck-call-guard-v1.0.6.tcl` and change this line to the intended
FXO port:

```tcl
set pa_port "<FXO_PORT>"
```

Do not use a list or a broad pattern. The policy is intentionally scoped to one
exact port. If more than one port needs protection, validate and register a
separate, deliberately scoped policy for each intended recovery boundary.

## Deployment configuration

Copy `analog-stuck-call-guard-v1.0.6.tcl` to the configured EEM user-policy
directory and register it with mutation disabled:

```text
configure terminal
 event manager directory user policy bootflash:
 event manager environment pa_guard_enforce 0
 event manager environment pa_guard_allow_port_bounce 0
 event manager environment pa_guard_bounce_shared_nim_ack NO
 event manager environment pa_guard_timeout_seconds 900
 event manager environment pa_guard_bounce_cooldown_seconds 1800
 event manager environment pa_guard_debug 0
 event manager policy analog-stuck-call-guard-v1.0.6.tcl type user
end
```

Confirm the exact environment names and registration:

```text
show event manager environment all | include pa_guard
show event manager policy registered
```

If AAA command authorization is enabled, configure an EEM CLI session identity
authorized for the required `show` and voice-port configuration commands.

## Activation and validation

1. Register v1.0.6 with all mutation settings disabled.
2. Temporarily set `pa_guard_timeout_seconds` to a small approved test value and
   set `pa_guard_debug 1`.
3. Place an approved test call through `<FXO_PORT>` beyond that threshold.
4. Confirm syslog records the correct decimal CallID and all four qualifying
   surfaces while reporting `observe-only`.
5. Hang up and confirm the expected idle and on-hook states return.
6. Restore `pa_guard_timeout_seconds 900` and `pa_guard_debug 0`.
7. During an approved maintenance window, enable the three settings below and
   repeat the test. Confirm the test call drops and the port returns on-hook.
8. Return to observe-only if any evidence differs from the expected contract.

Enable automatic recovery only after dry-run review:

```text
configure terminal
 event manager environment pa_guard_enforce 1
 event manager environment pa_guard_allow_port_bounce 1
 event manager environment pa_guard_bounce_shared_nim_ack YES
end
```

## Operational checks

```text
show event manager environment all | include pa_guard
show event manager policy registered
show event manager history events
show logging | include PA_STUCK_CALL_GUARD
show voice port summary | include <FXO_PORT>
show voice call summary | include <FXO_PORT>
show call active voice compact duration more 900
```

Return to observe-only mode:

```text
configure terminal
 event manager environment pa_guard_enforce 0
 event manager environment pa_guard_allow_port_bounce 0
 event manager environment pa_guard_bounce_shared_nim_ack NO
end
```

Disable and unregister:

```text
configure terminal
 no event manager policy analog-stuck-call-guard-v1.0.6.tcl type user
end
```

## Public-distribution boundary

This guide and policy are sanitized reference material, not a universal support
statement. They contain no gateway name, IP address, telephone number, customer
identifier, production CallID, or raw operational log. Operators remain
responsible for platform compatibility, AAA authorization, maintenance approval,
rollback planning, and validation of the exact port-state contract before
enforcement is enabled.
