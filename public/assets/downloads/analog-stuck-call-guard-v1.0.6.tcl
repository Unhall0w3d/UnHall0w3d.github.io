# Cisco IOS XE EEM Tcl policy: analog voice-port off-hook guard
# Version: 1.0.6
#
# Distribution note: this sample is scoped to one FXO loop-start voice port.
# Review and change pa_port for the intended gateway, then validate every state
# matcher on that platform and IOS XE release before enabling recovery.
#
# A candidate must simultaneously have:
#   - a TELE call leg older than the configured threshold;
#   - a full brief record mapping that decimal CallID to the configured port;
#   - voice-port summary state: admin up, idle, off-hook;
#   - voice-call summary state: FXOLS_OFFHOOK.
#
# The policy is observe-only by default. It never uses the unsupported
# 16-bit show/clear-by-ID path. When explicitly enabled, its sole recovery
# action is shutdown/no shutdown on the configured voice port.

::cisco::eem::event_register_timer watchdog time 60 maxrun 55

namespace import ::cisco::eem::*
namespace import ::cisco::lib::*

# IOS EEM injects configured environment variables as Tcl globals with the
# exact configured names. Leading underscores are a Cisco naming convention,
# not an automatic transformation. Accept an underscored alias defensively,
# but prefer the exact unprefixed names used by this deployment. Missing values
# retain safe defaults.
if {[info exists pa_guard_enforce]} {
    set pa_cfg_enforce $pa_guard_enforce
} elseif {[info exists _pa_guard_enforce]} {
    set pa_cfg_enforce $_pa_guard_enforce
} else { set pa_cfg_enforce 0 }
if {[info exists pa_guard_allow_port_bounce]} {
    set pa_cfg_allow_port_bounce $pa_guard_allow_port_bounce
} elseif {[info exists _pa_guard_allow_port_bounce]} {
    set pa_cfg_allow_port_bounce $_pa_guard_allow_port_bounce
} else { set pa_cfg_allow_port_bounce 0 }
if {[info exists pa_guard_bounce_shared_nim_ack]} {
    set pa_cfg_shared_nim_ack $pa_guard_bounce_shared_nim_ack
} elseif {[info exists _pa_guard_bounce_shared_nim_ack]} {
    set pa_cfg_shared_nim_ack $_pa_guard_bounce_shared_nim_ack
} else { set pa_cfg_shared_nim_ack NO }
if {[info exists pa_guard_timeout_seconds]} {
    set pa_cfg_timeout $pa_guard_timeout_seconds
} elseif {[info exists _pa_guard_timeout_seconds]} {
    set pa_cfg_timeout $_pa_guard_timeout_seconds
} else { set pa_cfg_timeout 900 }
if {[info exists pa_guard_bounce_cooldown_seconds]} {
    set pa_cfg_cooldown $pa_guard_bounce_cooldown_seconds
} elseif {[info exists _pa_guard_bounce_cooldown_seconds]} {
    set pa_cfg_cooldown $_pa_guard_bounce_cooldown_seconds
} else { set pa_cfg_cooldown 1800 }
if {[info exists pa_guard_debug]} {
    set pa_cfg_debug $pa_guard_debug
} elseif {[info exists _pa_guard_debug]} {
    set pa_cfg_debug $_pa_guard_debug
} else { set pa_cfg_debug 0 }

# Distribution sample only. Change this one value for the intended FXO port,
# then repeat observe-only and enforced validation before production use.
set pa_port "0/2/2"
set pa_timeout $pa_cfg_timeout
set pa_enforce $pa_cfg_enforce
set pa_allow_port_bounce $pa_cfg_allow_port_bounce
set pa_shared_nim_ack $pa_cfg_shared_nim_ack
set pa_cooldown $pa_cfg_cooldown
set pa_debug $pa_cfg_debug

proc pa_syslog {priority message} {
    global _cerrno _cerr_sub_num _cerr_sub_err _cerr_posix_err _cerr_str
    action_syslog priority $priority msg $message
    if {[info exists _cerrno] && $_cerrno != 0} {
        error [format "action_syslog failed: component=%s subsystem=%s posix=%s %s" \
            $_cerr_sub_num $_cerr_sub_err $_cerr_posix_err $_cerr_str]
    }
}

proc pa_log {priority message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
    set line "$timestamp PA_STUCK_CALL_GUARD $message"
    pa_syslog $priority $line
}

proc pa_fail {message} {
    pa_log err $message
    exit 1
}

proc pa_validate_integer {name value minimum maximum} {
    if {![regexp {^[0-9]+$} $value]} {
        pa_fail "$name must be an integer from $minimum through $maximum"
    }
    if {$value < $minimum || $value > $maximum} {
        pa_fail "$name must be an integer from $minimum through $maximum"
    }
}

proc pa_validate_settings {} {
    global pa_timeout pa_cooldown pa_enforce pa_allow_port_bounce pa_shared_nim_ack pa_debug
    pa_validate_integer "pa_guard_timeout_seconds" $pa_timeout 1 604800
    pa_validate_integer "pa_guard_bounce_cooldown_seconds" $pa_cooldown 60 604800
    if {[string compare $pa_enforce "0"] != 0 && [string compare $pa_enforce "1"] != 0} {
        pa_fail "pa_guard_enforce must be 0 or 1"
    }
    if {[string compare $pa_allow_port_bounce "0"] != 0 && [string compare $pa_allow_port_bounce "1"] != 0} {
        pa_fail "pa_guard_allow_port_bounce must be 0 or 1"
    }
    if {[string compare $pa_shared_nim_ack "NO"] != 0 && [string compare $pa_shared_nim_ack "YES"] != 0} {
        pa_fail "pa_guard_bounce_shared_nim_ack must be NO or YES"
    }
    if {[string compare $pa_debug "0"] != 0 && [string compare $pa_debug "1"] != 0} {
        pa_fail "pa_guard_debug must be 0 or 1"
    }
}

proc pa_cli {fd command} {
    if {[catch {cli_exec $fd $command} output]} {
        error "CLI command failed <$command>: $output"
    }
    if {[regexp -line -- {^[ \t]*%[ \t]*(Invalid input detected|Ambiguous command|Incomplete command|Authorization failed|Command authorization failed|Unrecognized command)} $output]} {
        error "IOS rejected CLI command <$command>: $output"
    }
    # IOS CLI output is commonly CRLF terminated. Normalize it before exact
    # line-anchored matching.
    return [string map [list "\r" ""] $output]
}

proc pa_debug_log {message} {
    global pa_debug
    if {[string compare $pa_debug "1"] == 0} {
        pa_log info "debug: $message"
    }
}

proc pa_port_reports_offhook {port_summary call_summary} {
    global pa_port
    set port_pattern [format {^[ \t]*%s[ \t]+--[ \t]+fxo-ls[ \t]+up[ \t]+[^ \t]+[ \t]+idle[ \t]+off-hook[ \t]+y[ \t]*$} $pa_port]
    set call_pattern [format {^[ \t]*%s[ \t]+.*[ \t]+FXOLS_OFFHOOK[ \t]*$} $pa_port]
    return [expr {
        [regexp -nocase -line -- $port_pattern $port_summary] &&
        [regexp -nocase -line -- $call_pattern $call_summary]
    }]
}

proc pa_find_long_offhook_candidate {fd} {
    global pa_port pa_timeout
    set port_summary [pa_cli $fd "show voice port summary"]
    set call_summary [pa_cli $fd "show voice call summary"]
    if {![pa_port_reports_offhook $port_summary $call_summary]} {
        pa_debug_log "port-state surfaces do not jointly report target FXO port off-hook"
        return {}
    }

    set compact [pa_cli $fd "show call active voice compact duration more $pa_timeout"]
    set brief [pa_cli $fd "show call active voice brief"]
    set saw_tele 0
    foreach line [split $compact "\n"] {
        if {![regexp {^[ \t]*([0-9]+)[ \t]+(ANS|ORG)[ \t]+T[0-9]+[ \t]+.*[ \t]+TELE([ \t]+.*)?$} $line -> call_id direction]} {
            continue
        }
        set saw_tele 1
        set header_pattern [format {^[ \t]*[0-9A-Fa-f]+[ \t]*:[ \t]*%s[ \t]+.*[ \t]+active[ \t]*$} $call_id]
        set tele_pattern [format {^[ \t]*Tele[ \t]+%s[ \t]+[(]%s[)][ \t]+.*$} $pa_port $call_id]
        if {[regexp -line -- $header_pattern $brief] && [regexp -line -- $tele_pattern $brief]} {
            return [list $call_id $direction $compact $brief $port_summary $call_summary]
        }
    }
    if {$saw_tele} {
        pa_debug_log "long TELE leg exists but exact decimal CallID-to-port brief mapping did not match"
    } else {
        pa_debug_log "off-hook port has no TELE leg older than ${pa_timeout}s"
    }
    return {}
}

proc pa_bounce_is_on_cooldown {} {
    global pa_cooldown
    if {[catch {set saved_time [context_retrieve PA_STUCK_CALL_GUARD pa_last_bounce]} retrieve_error]} {
        return 0
    }
    if {![regexp {^[0-9]+$} $saved_time]} {
        set pa_last_bounce [clock seconds]
        catch {context_save PA_STUCK_CALL_GUARD pa_last_bounce}
        pa_log warning "bounce skipped; EEM cooldown context was invalid"
        return 1
    }
    if {[clock seconds] - $saved_time < $pa_cooldown} {
        set pa_last_bounce $saved_time
        if {[catch {context_save PA_STUCK_CALL_GUARD pa_last_bounce} save_error]} {
            pa_log err "bounce skipped; cannot preserve EEM cooldown context: $save_error"
        }
        return 1
    }
    return 0
}

proc pa_set_bounce_marker {} {
    set pa_last_bounce [clock seconds]
    if {[catch {context_save PA_STUCK_CALL_GUARD pa_last_bounce} write_error]} {
        pa_log err "could not save EEM bounce cooldown context: $write_error"
        return 0
    }
    return 1
}

proc pa_bounce_port {fd} {
    global pa_port
    set bounce_failed [catch {
        pa_cli $fd "configure terminal"
        pa_cli $fd "voice-port $pa_port"
        pa_cli $fd "shutdown"
        after 3000
        pa_cli $fd "no shutdown"
        pa_cli $fd "end"
    } bounce_error]
    if {$bounce_failed} {
        # Best-effort recovery if any command after shutdown failed. These
        # cleanup commands intentionally bypass pa_cli so the original error is
        # retained while IOS is given every chance to restore the port.
        catch {cli_exec $fd "no shutdown"}
        catch {cli_exec $fd "end"}
        error "voice-port recovery sequence failed: $bounce_error"
    }
}

pa_validate_settings

if {[catch {cli_open} cli_open_result]} {
    pa_log err "cli_open failed: $cli_open_result"
    exit 1
}
array set cli $cli_open_result
set fd $cli(fd)

if {[catch {
    pa_cli $fd "enable"
    set candidate [pa_find_long_offhook_candidate $fd]
    if {[llength $candidate] > 0} {
        set call_id [lindex $candidate 0]
        set direction [lindex $candidate 1]
        set compact_before [lindex $candidate 2]
        set brief_before [lindex $candidate 3]
        set port_summary_before [lindex $candidate 4]
        set call_summary_before [lindex $candidate 5]
        pa_log warning "matched long off-hook FXO call call_id=$call_id direction=$direction port=$pa_port duration_gt=${pa_timeout}s enforce=$pa_enforce"

        if {[string compare $pa_enforce "1"] != 0} {
            pa_log notice "observe-only; no port recovery issued for call_id=$call_id"
        } elseif {[string compare $pa_allow_port_bounce "1"] != 0 || [string compare $pa_shared_nim_ack "YES"] != 0} {
            pa_log err "port recovery not authorized; both bounce settings remain required"
        } elseif {[pa_bounce_is_on_cooldown]} {
            pa_log err "port recovery skipped; cooldown remains in effect"
        } else {
            # Revalidate the same long-running decimal CallID and both exact
            # port-state surfaces immediately before mutation.
            set revalidated [pa_find_long_offhook_candidate $fd]
            if {[llength $revalidated] == 0 || [string compare [lindex $revalidated 0] $call_id] != 0} {
                pa_log notice "candidate changed or disappeared before port recovery; no action"
            } elseif {![pa_set_bounce_marker]} {
                pa_log err "port recovery skipped; could not establish cooldown marker"
            } else {
                pa_log err "bouncing voice-port $pa_port after verified call_id=$call_id exceeded ${pa_timeout}s"
                pa_bounce_port $fd
                after 5000

                set port_summary_after [pa_cli $fd "show voice port summary"]
                set call_summary_after [pa_cli $fd "show voice call summary"]

                if {[pa_port_reports_offhook $port_summary_after $call_summary_after]} {
                    pa_log err "voice-port $pa_port remains off-hook after recovery; manual investigation required"
                } else {
                    pa_log notice "voice-port $pa_port returned from the verified off-hook state"
                }
            }
        }
    }
} policy_error]} {
    catch {pa_log err "policy execution failed: $policy_error"}
    catch {cli_close $fd}
    exit 1
}

catch {cli_close $fd}
exit 0
