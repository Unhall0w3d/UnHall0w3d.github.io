#!/usr/bin/env node
/**
 * Deterministic taxonomy & frontmatter migration for NOC Thoughts ("Aftertone Telemetry").
 * - Consolidates 18 legacy categories -> 5 Operational Pillars (`pillar`) while preserving `legacyCategories`.
 * - Normalizes ~121 raw tags -> 31 canonical lowercase slugs (`^[a-z0-9-]+$`, max 6, zero pillar collisions).
 * - Preserves exact raw `date` -> `pubDate` (`updated` -> `updatedDate`) ISO strings so America/New_York URLs never shift.
 * - Marks `hasTool: true` (and structured `validation` metadata) for curated Field Toolbox guides.
 * - Backfills clean 1-sentence `description` summaries (10..240 chars) for all 2019-2023 posts missing one.
 * - Idempotent across repeated executions.
 */
import fs from "node:fs";
import path from "node:path";

const POSTS_DIR = path.resolve(process.cwd(), "src/content/posts");

const VALID_PILLARS = new Set([
  "unified-communications",
  "automation-tooling",
  "local-ai-agents",
  "systems-infrastructure",
  "field-log-craft"
]);

/** Explicit tag alias map -> 31 canonical slugs */
const TAG_ALIAS_MAP = new Map([
  // CUCM
  ["cisco unified communications manager", "cucm"],
  ["cucm", "cucm"],
  ["callmanager", "cucm"],
  ["cisco uc", "cucm"],
  ["call detail record", "cucm"],

  // Unity Connection
  ["cisco unity connection", "unity-connection"],
  ["unity connection", "unity-connection"],
  ["alternate extensions", "unity-connection"],
  ["voice mail profile", "unity-connection"],

  // Contact Center
  ["cisco unified contact center express", "uccx"],
  ["cisco unified contact center", "uccx"],
  ["uccx", "uccx"],

  // IM & Presence / Jabber
  ["cisco unified im & presence", "im-presence"],
  ["cisco jabber", "im-presence"],

  // VCS / Expressway / Telepresence
  ["cisco vcs", "expressway"],
  ["cisco expressway", "expressway"],
  ["telepresence", "expressway"],

  // IOS XE / Voice Gateways
  ["ios/xe", "ios-xe"],
  ["ios xe", "ios-xe"],
  ["cisco unified border element", "ios-xe"],
  ["voice gateway", "ios-xe"],
  ["analog voice", "ios-xe"],
  ["fxo", "ios-xe"],
  ["fxs", "ios-xe"],
  ["eem", "ios-xe"],
  ["tcl", "ios-xe"],
  ["sccp", "ios-xe"],
  ["media resource", "ios-xe"],

  // Emergency Responder
  ["cisco emergency responder", "emergency-responder"],
  ["emergency responder", "emergency-responder"],

  // Dial Plan & Call Routing
  ["calling search space", "dial-plan"],
  ["route pattern", "dial-plan"],
  ["directory number", "dial-plan"],
  ["forced authorization code", "dial-plan"],

  // Phone Endpoints & BLF / Auto-Answer
  ["cisco phone", "phone-config"],
  ["blf", "phone-config"],
  ["blf speed dial", "phone-config"],
  ["speed dial", "phone-config"],
  ["auto-answer", "phone-config"],
  ["csv", "phone-config"],

  // Scripting & Queries
  ["axl", "axl"],
  ["sql", "sql"],
  ["database", "sql"],
  ["informix", "sql"],
  ["python", "python"],
  ["paramiko", "python"],
  ["powershell", "powershell"],

  // Backups & Health Checks & AletheiaUC
  ["backup", "backups"],
  ["disaster recovery system", "backups"],
  ["sftp", "backups"],
  ["health checks", "health-checks"],
  ["log review", "health-checks"],
  ["aletheiauc", "aletheia-uc"],
  ["aletheia-uc", "aletheia-uc"],

  // Local AI & Agents
  ["local llm", "local-llm"],
  ["local-llm", "local-llm"],
  ["artificial intelligence", "local-llm"],
  ["voice", "local-llm"],
  ["computer vision", "local-llm"],
  ["privacy", "local-llm"],
  ["llama.cpp", "llama-cpp"],
  ["llama-cpp", "llama-cpp"],
  ["gpu", "gpu-tuning"],
  ["gpu-tuning", "gpu-tuning"],
  ["amd", "gpu-tuning"],
  ["nvidia", "gpu-tuning"],
  ["codex", "codex"],
  ["subagents", "agent-workflows"],
  ["skills", "agent-workflows"],
  ["mcp", "agent-workflows"],
  ["openclaw", "agent-workflows"],
  ["opencode", "agent-workflows"],
  ["software development", "agent-workflows"],
  ["agent-workflows", "agent-workflows"],
  ["soul slash", "soul-slash"],
  ["soul-slash", "soul-slash"],
  ["music production", "soul-slash"],

  // Systems, Virtualization & Hardware
  ["vmware", "virtualization"],
  ["vmware esxi", "virtualization"],
  ["vcenter", "virtualization"],
  ["vcsa", "virtualization"],
  ["proxmox", "virtualization"],
  ["storage", "virtualization"],
  ["data center", "virtualization"],
  ["virtualization", "virtualization"],
  ["cisco ucs", "cisco-ucs"],
  ["cisco ucs-c", "cisco-ucs"],
  ["cisco-ucs", "cisco-ucs"],
  ["linux", "linux"],
  ["arch", "linux"],
  ["debian", "linux"],
  ["endeavoros", "linux"],
  ["hyprland", "linux"],
  ["zsh", "linux"],
  ["paru", "linux"],
  ["git", "linux"],
  ["ssh", "linux"],
  ["openssh", "linux"],
  ["dns", "linux"],
  ["nixos", "nixos"],
  ["nix", "nixos"],
  ["ruckus", "smartzone"],
  ["smartzone", "smartzone"],
  ["vsz", "smartzone"],
  ["security", "security"],
  ["certificates", "security"],
  ["psirt", "security"],
  ["lab", "lab"],

  // Craft & Engines
  ["astro", "astro"],
  ["github pages", "astro"],
  ["noc thoughts", "astro"],
  ["website", "astro"],
  ["unreal engine", "unreal-engine"],
  ["unreal-engine", "unreal-engine"],
  ["game development", "unreal-engine"],
  ["gaming", "unreal-engine"],

  // Dropped umbrella/noise tags (mapped to null -> omitted from tags array)
  ["cisco", null],
  ["unified communications", null],
  ["automation", null],
  ["general", null],
  ["action plan", null],
  ["reports", null]
]);

/** Clean 1-sentence descriptions for the 50 legacy 2019-2023 posts missing frontmatter descriptions */
const DESCRIPTION_BACKFILL = {
  "2019-06-20-is-home-cluster-enabled-what-service-profile-is-used":
    "Query CUCM via SQL to list end users with Home Cluster enabled alongside their assigned UC Service Profiles.",
  "2019-06-21-identifying-static-phone-loads":
    "Use a CUCM SQL query to identify IP phones pinned to static firmware load names before running cluster-wide upgrades.",
  "2019-06-22-pulling-device-defaults-like-a-pro":
    "Pull active CUCM Device Default firmware assignments via SQL for phone models currently deployed in the cluster.",
  "2019-06-24-vcs-87-and-old-host-keys":
    "Resolve OpenSSH host key algorithm rejections when connecting from modern Linux jump hosts to legacy Cisco VCS and Expressway nodes.",
  "2019-06-26-and-boom-goes-the-storage-controller":
    "Field post-mortem on recovering virtual machines after an unscheduled Cisco UCS-C RAID controller failure.",
  "2019-06-27-health-checks-cube-vgw-ios-xe":
    "Pre- and post-change CLI health check commands for Cisco Unified Border Element (CUBE) and IOS XE voice gateways.",
  "2019-07-05-do-you-hear-that-its-a-dial-plan-overlap":
    "Diagnosing inter-site call failures caused by overlapping CUCM translation patterns and interdigit timeouts on Cisco IP Phones.",
  "2019-07-08-check-call-forward-all-faster-using-sql":
    "Inspect Call Forward All, Busy, and No Answer destinations and Calling Search Spaces directly from the CUCM CLI with SQL.",
  "2019-07-17-mobile-agents-ctios-and-service-crashes-oh-my":
    "Troubleshooting Severity-1 Contact Center CTIOS service crashes triggered by mobile agent configuration edge cases.",
  "2019-07-21-dial-plan-dump-using-sql":
    "Export assigned directory numbers, route patterns, and partition mappings from CUCM Informix tables using read-only SQL.",
  "2019-07-25-cdr-export-to-billing-server-failing":
    "Diagnosing and clearing stuck CUCM CDR Repository Manager billing exports to third-party SFTP accounting servers.",
  "2019-07-29-basic-commands-to-know-for-managing-esxi-on-ucs":
    "Essential ESXi CLI commands for host maintenance, CIMC preparation, and hardware inspection on Cisco UCS servers.",
  "2019-08-02-uc-ucc-best-practice-large-receive-offload-and-interrupt-remapping-esxi":
    "Verify and tune VMware ESXi Large Receive Offload (LRO) and Interrupt Remapping settings for Cisco UC and Contact Center VMs.",
  "2019-08-09-vmware-esxi-vcsa-lab-setup":
    "Step-by-step guide to building a home Cisco Collaboration lab on VMware ESXi, vCenter Server Appliance, and Windows DNS.",
  "2019-08-14-making-isos-bootable-lab-use":
    "Convert non-bootable Cisco Unified Communications patch ISOs into bootable lab installation media on Windows.",
  "2019-08-21-call-block-reject-ios-xe-sip-h323":
    "Configure inbound call blocking and translation reject rules on Cisco IOS XE SIP and H.323 voice gateways.",
  "2019-09-04-importance-of-documentation-where-is-this-vm":
    "Why accurate host-to-VM inventory documentation matters when locating critical workloads across standalone ESXi hosts during an outage.",
  "2019-10-20-health-checks-cucm-callmanager":
    "Baseline CLI health checks to capture replication, service, DB, and NTP state on CUCM clusters before maintenance windows.",
  "2019-11-06-finding-orphaned-devices-and-device-profiles":
    "Locate unassigned Cisco IP Phones and orphaned Extension Mobility Device Profiles in CUCM using SQL queries.",
  "2019-11-18-securing-sccp-media-resource-in-ios":
    "Configure an IOS certificate authority and TLS trustpoint to register secure SCCP DSP media resources with CUCM.",
  "2019-11-25-health-checks-cuc-unity-connection":
    "Operational CLI checklist for verifying Cisco Unity Connection cluster status, replication, ports, and diagnostics around changes.",
  "2019-12-15-why-windows-ntp-is-unsupported-for-cisco-uc-deployments":
    "Why Windows W32Time NTP servers cause clock drift and unsupported synchronization failures on Cisco UC VOS appliances.",
  "2020-01-19-ccm-synced-end-users-and-how-to-delete-them":
    "Convert orphaned CUCM-synced Unity Connection mailboxes back to local users via SQL so stale accounts can be cleanly removed.",
  "2020-01-27-updating-accept-and-relay-addresses-en-masse":
    "Bulk-update SMTP Proxy and Relay address actions across Cisco Unity Connection users with targeted Informix SQL statements.",
  "2020-02-06-updating-primary-extension-the-fun-way":
    "Inspect and update CUCM End User Primary Extension mappings via SQL when standard GUI workflows hit association snags.",
  "2020-02-20-call-drops-after-uccx-option-selected-call-sent-to-agent":
    "Root-cause analysis of UCCX calls dropping upon agent transfer due to region codec and Calling Search Space mismatches.",
  "2020-04-07-sql-query-cisco-jabber-video-calling-enabled-option":
    "Audit Cisco Jabber device configurations in CUCM via SQL to verify whether Video Calling is enabled or disabled per endpoint.",
  "2020-05-01-using-beautifulsoup-to-parse-cisco-phone-gui-python":
    "Use Python and BeautifulSoup to scrape Cisco IP Phone web interfaces for serial numbers, firmware loads, and network details.",
  "2020-05-14-building-a-toolbelt-for-unified-communications-using-python":
    "Expand a Python phone-scraping script into a multi-tool UC utility with error handling and structured CSV reporting.",
  "2020-06-01-python-checking-device-registration-cucm":
    "Check Cisco IP Phone registration status at scale using Python and CUCM RISPort SOAP queries instead of manual GUI pagination.",
  "2020-06-14-health-checks-imp-cups-im-presence":
    "Pre- and post-maintenance CLI health check procedure for Cisco Unified IM and Presence (IM&P) clusters.",
  "2020-06-15-vmware-esxi-boot-device-discovery":
    "Identify backing storage media and boot bank devices on VMware ESXi hosts using esxcli storage commands.",
  "2020-07-27-check-phone-and-sip-trunk-registration-with-zeep":
    "Query CUCM phone and SIP trunk registration state cleanly in Python using the Zeep SOAP client against RISPort70.",
  "2020-08-30-calculating-virtual-memory-usage-on-ucvos-using-snmp":
    "Calculate real vs. virtual memory utilization accurately on Linux-based Cisco UC VOS appliances when interpreting SNMP alerts.",
  "2020-10-22-verify-trace-levels-using-sql-cisco-unified-communications":
    "Audit elevated SDI/SDL service trace levels across CUCM and Cisco UC VOS nodes via SQL before disk I/O degrades.",
  "2021-01-08-verifying-memory-usage-cisco-vcs-using-python":
    "Automate SSH memory utilization checks across Cisco VCS Control and Expressway appliances using Python and Paramiko.",
  "2021-02-12-automating-memory-checks-cisco-vcs-python":
    "Refactor the Cisco VCS and Expressway Python memory checker for unattended scheduled runs and cleaner alerting.",
  "2022-02-27-vm-profile-sql-queries":
    "Audit CUCM directory numbers and Voice Mail Profile assignments with SQL to catch misrouted voicemail pilot configurations.",
  "2022-12-09-health-checks-vcs-expressway":
    "Standardized CLI and status checks for Cisco VCS and Expressway-C/E traversal pairs before upgrades or certificate renewals.",
  "2022-12-14-cisco-cve-2022-20968-validation":
    "Use Python to inventory Cisco 7800 and 8800 IP Phone firmware and CDP state when validating exposure to CVE-2022-20968.",
  "2022-12-20-uc-syslog-parsing-script":
    "Parse exported Cisco Unified Communications Manager syslog files with Python to surface recurring errors and device events.",
  "2023-01-06-vmware-esxi-toolkit-script":
    "Build an interactive Python SSH toolkit to collect host diagnostics and storage details from standalone VMware ESXi servers.",
  "2023-02-13-health-checks-uccx":
    "Pre-change CLI verification commands for Cisco Unified Contact Center Express (UCCX) engines, replication, and subsystems.",
  "2023-04-16-ccnp-collab-clcor-post-mortem":
    "Reflections on passing the Cisco CCNP Collaboration CLCOR exam, study focus areas, and planning a daily-driver move to Linux.",
  "2023-04-27-arch-linux-virt-manager-and-firewalld":
    "Fix missing libvirt firewalld zone errors when setting up KVM and Virt-Manager on Arch-based Linux desktops.",
  "2023-04-30-modding-fallout4-on-linux":
    "Configure Steam Proton, Mod Organizer 2, and F4SE to run a modded Fallout 4 installation cleanly on Arch Linux.",
  "2023-05-16-automating-ssl-cert-install-linux":
    "Automate internal CA certificate chain import and system trust store updates across Arch and Debian Linux hosts with Bash.",
  "2023-05-23-automating-mremoteng-putty-session-creation":
    "Generate bulk SSH connection configs for mRemoteNG and PuTTY from device inventories using a Python automation script.",
  "2023-05-29-nocthoughts-dot-files-for-hyprland":
    "Touring a reproducible Arch Linux and Hyprland Wayland desktop configuration managed with Git, Zsh, and helper scripts.",
  "2023-08-13-nixos-and-my-configs":
    "Migrating a daily-driver Linux workstation to declarative NixOS configurations for reproducible packages and rollbacks."
};

/** Tool posts mapped from src/config/tools.ts + structured validation scope */
const TOOL_POST_VALIDATION = {
  "2026-09-11-updating-cucm-blf-labels-with-python": {
    posture: "preview-first",
    testedOn: "Python 3.10+, CUCM 14 lab (single + batch), CUCM 15 offline schema",
    limits: "Requires AXL credentials and explicit phone CSV; verify shared-appearance expectations before apply."
  },
  "2026-09-11-updating-cucm-auto-answer-from-a-phone-list-with-python": {
    posture: "preview-first",
    testedOn: "Python 3.10+, CUCM 15 lab (CIPC Line 1 apply + journal readback)",
    limits: "AXL 15.0 supports apply; AXL 14.0 is preview-only; shared lines are flagged during preflight."
  },
  "2026-08-09-finding-cucm-speed-dials-and-blf-speed-dials-using-sql": {
    posture: "read-only",
    testedOn: "CUCM 15 Informix CLI & AXL executeSQLQuery",
    limits: "Inspects configured speed-dial and DN-backed BLF tables only; does not modify phone button templates."
  },
  "2026-08-25-finding-active-phone-extensions-and-voicemail-profiles-using-cucm-sql": {
    posture: "read-only",
    testedOn: "CUCM 15 Informix CLI & AXL executeSQLQuery",
    limits: "Reports configured phone-class line appearances; live RISPort registration requires a separate check."
  },
  "2026-08-25-auditing-local-and-long-distance-calling-access-with-cucm-sql": {
    posture: "read-only",
    testedOn: "CUCM 15 Informix CLI & AXL executeSQLQuery",
    limits: "Evaluates CSS-to-route-pattern partition reachability and FAC flags; translation hops require review."
  },
  "2026-11-14-standardizing-cisco-uc-backup-configuration-with-powershell": {
    posture: "preview-first",
    testedOn: "PowerShell 7.7.0, CUCM 15 lab (0 preview writes, 12 verified CLI writes, 306 offline checks)",
    limits: "v1.6.2-r5 testing candidate; non-CUCM apply, scheduled execution, and DRS restore remain unqualified."
  },
  "2026-07-01-ruckus-smartzone-backup-retriever": {
    posture: "read-only",
    testedOn: "Windows PowerShell against RUCKUS SmartZone / vSZ HTTPS API",
    limits: "Downloads controller backup archives over HTTPS; verify external repository revision before scheduling."
  },
  "2026-08-01-when-an-analog-call-refuses-to-die": {
    posture: "observe-default",
    testedOn: "Cisco IOS XE EEM / Tcl v1.0.6 on FXO loop-start voice port",
    limits: "Defaults to observe-only; state matchers must be validated per gateway and FXS ports are not equivalent."
  },
  "2026-09-22-from-a-codex-prompt-to-an-agent-execution-system": {
    posture: "reference",
    testedOn: "Codex CLI 0.166.0 across 5 scoped role/model pairs",
    limits: "Reference multi-agent configuration; confirm model availability and sandbox permissions in your client."
  }
};

/** Explicit Pillar assignment rules per Spec 3.2 */
function resolvePillar(stem, legacyCats, rawTags) {
  const explicit = {
    // Field Log & Craft (Web Dev, Gaming, Post-mortems, Documentation craft)
    "2019-09-04-importance-of-documentation-where-is-this-vm": "field-log-craft",
    "2023-04-16-ccnp-collab-clcor-post-mortem": "field-log-craft",
    "2023-04-30-modding-fallout4-on-linux": "field-log-craft",
    "2026-07-13-noc-thoughts-rewired": "field-log-craft",

    // Local AI & Agents (Soul/, Codex, Local LLMs, Unreal Codex loop)
    "2026-07-15-why-i-am-building-soul-slash": "local-ai-agents",
    "2026-07-17-soul-slash-is-taking-shape": "local-ai-agents",
    "2026-07-19-soul-slash-has-more-than-one-brain-now": "local-ai-agents",
    "2026-07-24-how-soul-slash-turns-an-idea-into-a-song": "local-ai-agents",
    "2026-08-05-soul-learned-to-hear-see-and-speak": "local-ai-agents",
    "2026-08-06-five-cores-one-soul": "local-ai-agents",
    "2026-08-08-souls-skills-became-real": "local-ai-agents",
    "2026-08-08-what-happens-after-soul-finishes-a-song": "local-ai-agents",
    "2026-08-09-administration-without-autonomy": "local-ai-agents",
    "2026-08-17-giving-codex-a-playwright-style-loop-for-unreal-engine": "local-ai-agents",
    "2026-08-19-one-architect-several-workers-how-i-use-codex-sol": "local-ai-agents",
    "2026-08-20-the-cheapest-adequate-worker-re-evaluating-my-codex-subagent-strategy": "local-ai-agents",
    "2026-09-22-from-a-codex-prompt-to-an-agent-execution-system": "local-ai-agents",
    "2026-11-16-running-local-llms-on-a-ryzen-5800x-navi-21-and-a-gtx-1070": "local-ai-agents",
    "2026-11-23-evaluating-15-ai-skills-against-my-existing-codex-setup": "local-ai-agents",

    // Systems & Infrastructure (ESXi, UCS, Proxmox, Linux, Arch, Debian, NixOS, Hyprland)
    "2019-06-26-and-boom-goes-the-storage-controller": "systems-infrastructure",
    "2019-07-29-basic-commands-to-know-for-managing-esxi-on-ucs": "systems-infrastructure",
    "2019-08-02-uc-ucc-best-practice-large-receive-offload-and-interrupt-remapping-esxi": "systems-infrastructure",
    "2019-08-09-vmware-esxi-vcsa-lab-setup": "systems-infrastructure",
    "2019-08-14-making-isos-bootable-lab-use": "systems-infrastructure",
    "2020-06-15-vmware-esxi-boot-device-discovery": "systems-infrastructure",
    "2023-04-27-arch-linux-virt-manager-and-firewalld": "systems-infrastructure",
    "2023-05-16-automating-ssl-cert-install-linux": "systems-infrastructure",
    "2023-05-29-nocthoughts-dot-files-for-hyprland": "systems-infrastructure",
    "2023-08-13-nixos-and-my-configs": "systems-infrastructure",
    "2026-11-19-cucm-15su5-bootable-iso-proxmox": "systems-infrastructure",

    // Automation & Tooling (Python, PowerShell, AletheiaUC, RUCKUS backup, UC DRS, SQL audits/scripts)
    "2023-01-06-vmware-esxi-toolkit-script": "automation-tooling",
    "2023-05-23-automating-mremoteng-putty-session-creation": "automation-tooling",
    "2026-07-01-ruckus-smartzone-backup-retriever": "automation-tooling",
    "2026-07-25-aletheiauc-bringing-uc-health-to-light": "automation-tooling",
    "2026-08-01-when-an-analog-call-refuses-to-die": "unified-communications",
    "2026-11-14-standardizing-cisco-uc-backup-configuration-with-powershell": "automation-tooling",

    // Core Unified Communications troubleshooting post that happened to mention SQL
    "2019-07-17-mobile-agents-ctios-and-service-crashes-oh-my": "unified-communications"
  };

  if (explicit[stem]) return explicit[stem];

  const catSet = new Set(legacyCats.map((c) => c.toLowerCase()));
  if (catSet.has("automation") || catSet.has("python") || catSet.has("powershell") || catSet.has("sql")) {
    return "automation-tooling";
  }
  if (
    catSet.has("unified communications") ||
    catSet.has("cisco") ||
    catSet.has("cisco unified contact center") ||
    catSet.has("ios/xe")
  ) {
    return "unified-communications";
  }
  if (
    catSet.has("linux") ||
    catSet.has("arch") ||
    catSet.has("debian") ||
    catSet.has("vmware") ||
    catSet.has("cisco ucs") ||
    catSet.has("ruckus") ||
    catSet.has("microsoft windows")
  ) {
    return "systems-infrastructure";
  }
  const tagLower = rawTags.map((t) => t.toLowerCase());
  if (tagLower.some((t) => ["local llm", "codex", "soul slash", "artificial intelligence"].includes(t))) {
    return "local-ai-agents";
  }
  return "field-log-craft";
}

function normalizeTags(stem, pillar, legacyCats, rawTags) {
  const result = [];
  const add = (slug) => {
    if (!slug) return;
    if (slug === pillar) return;
    if (!result.includes(slug)) result.push(slug);
  };

  for (const raw of rawTags) {
    const key = raw.trim().toLowerCase();
    if (TAG_ALIAS_MAP.has(key)) {
      add(TAG_ALIAS_MAP.get(key));
    } else if (/^[a-z0-9-]+$/.test(key)) {
      add(key);
    } else {
      throw new Error(`Unmapped tag "${raw}" in ${stem}`);
    }
  }

  // Enrich from legacy categories where specific technical signal would otherwise be lost
  for (const cat of legacyCats) {
    const key = cat.trim().toLowerCase();
    if (key === "sql") add("sql");
    if (key === "python") add("python");
    if (key === "powershell") add("powershell");
    if (key === "ios/xe") add("ios-xe");
    if (key === "vmware") add("virtualization");
    if (key === "cisco ucs") add("cisco-ucs");
    if (key === "ruckus") add("smartzone");
    if (key === "cisco unified contact center") add("uccx");
  }

  // Ensure dial-plan posts carry `dial-plan` where appropriate
  if (
    stem === "2019-07-05-do-you-hear-that-its-a-dial-plan-overlap" ||
    stem === "2019-07-08-check-call-forward-all-faster-using-sql" ||
    stem === "2019-07-21-dial-plan-dump-using-sql"
  ) {
    add("dial-plan");
  }

  // Guarantee at least 1 canonical tag on every post
  if (result.length === 0) {
    if (stem === "2023-04-16-ccnp-collab-clcor-post-mortem") {
      add("cucm");
      add("lab");
    } else if (pillar === "unified-communications") {
      add("cucm");
    } else if (pillar === "systems-infrastructure") {
      add("linux");
    }
  }

  return result.slice(0, 6);
}

function parseYamlArray(fm, key) {
  const inline = fm.match(new RegExp(`^${key}:\\s*\\[(.*?)\\]\\s*$`, "m"));
  if (inline) {
    if (!inline[1].trim()) return [];
    return inline[1]
      .split(",")
      .map((s) => s.trim().replace(/^["']|["']$/g, ""))
      .filter(Boolean);
  }
  const block = fm.match(new RegExp(`^${key}:\\s*\\r?\\n((?:\\s*-\\s*.+(?:\\r?\\n|$))*)`, "m"));
  if (block) {
    return block[1]
      .split(/\r?\n/)
      .map((l) => l.replace(/^\s*-\s*/, "").trim().replace(/^["']|["']$/g, ""))
      .filter(Boolean);
  }
  return null;
}

function parseScalar(fm, key) {
  const m = fm.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  if (!m) return null;
  return m[1].trim();
}

function unquoteScalar(raw) {
  if (!raw) return "";
  if ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'"))) {
    return raw.slice(1, -1).replace(/\\"/g, '"').replace(/''/g, "'");
  }
  return raw;
}

function yamlQuote(str) {
  return JSON.stringify(str);
}

const files = fs
  .readdirSync(POSTS_DIR)
  .filter((f) => /\.mdx?$/.test(f))
  .sort();

let updatedCount = 0;
const pillarCounts = {};
const canonicalTagSet = new Set();

for (const file of files) {
  const fullPath = path.join(POSTS_DIR, file);
  const stem = file.replace(/\.(md|mdx)$/i, "");
  const raw = fs.readFileSync(fullPath, "utf8");
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---(\r?\n[\s\S]*)$/);
  if (!match) throw new Error(`Missing YAML frontmatter in ${file}`);

  const [, fm, rest] = match;

  const titleRaw = parseScalar(fm, "title");
  if (!titleRaw) throw new Error(`Missing title in ${file}`);
  const title = unquoteScalar(titleRaw);

  const pubDateRaw = parseScalar(fm, "pubDate") ?? parseScalar(fm, "date");
  if (!pubDateRaw) throw new Error(`Missing date/pubDate in ${file}`);
  const pubDateStr = unquoteScalar(pubDateRaw);

  const updatedDateRaw = parseScalar(fm, "updatedDate") ?? parseScalar(fm, "updated");
  const updatedDateStr = updatedDateRaw ? unquoteScalar(updatedDateRaw) : null;

  const existingDescRaw = parseScalar(fm, "description");
  let description = existingDescRaw ? unquoteScalar(existingDescRaw) : "";
  if (!description || DESCRIPTION_BACKFILL[stem]) {
    description = DESCRIPTION_BACKFILL[stem] || description;
  }
  if (!description || description.length < 10 || description.length > 240) {
    throw new Error(
      `Invalid description length (${description?.length ?? 0}) in ${file}: "${description}"`
    );
  }

  const legacyCats =
    parseYamlArray(fm, "legacyCategories") ?? parseYamlArray(fm, "categories") ?? [];
  const rawTags = parseYamlArray(fm, "tags") ?? [];

  const existingPillarRaw = parseScalar(fm, "pillar");
  const existingPillar = existingPillarRaw ? unquoteScalar(existingPillarRaw) : null;
  const pillar =
    existingPillar && VALID_PILLARS.has(existingPillar)
      ? resolvePillar(stem, legacyCats, rawTags)
      : resolvePillar(stem, legacyCats, rawTags);

  const tags = normalizeTags(stem, pillar, legacyCats, rawTags);
  for (const t of tags) canonicalTagSet.add(t);
  pillarCounts[pillar] = (pillarCounts[pillar] ?? 0) + 1;

  const hasTool = Boolean(TOOL_POST_VALIDATION[stem]);
  const validation = TOOL_POST_VALIDATION[stem] ?? null;

  const draftRaw = parseScalar(fm, "draft");
  const draft = draftRaw ? unquoteScalar(draftRaw) === "true" : false;

  const imageRaw = parseScalar(fm, "image");
  const imageAltRaw = parseScalar(fm, "imageAlt");
  const imageWidthRaw = parseScalar(fm, "imageWidth");
  const imageHeightRaw = parseScalar(fm, "imageHeight");
  const excerptSepRaw = parseScalar(fm, "excerpt_separator");

  const lines = ["---"];
  lines.push(`title: ${yamlQuote(title)}`);
  lines.push(`description: ${yamlQuote(description)}`);
  lines.push(`pubDate: ${pubDateStr}`);
  if (updatedDateStr) lines.push(`updatedDate: ${updatedDateStr}`);
  lines.push(`pillar: ${yamlQuote(pillar)}`);
  lines.push(`tags: [${tags.map((t) => yamlQuote(t)).join(", ")}]`);
  if (legacyCats.length > 0) {
    lines.push(`legacyCategories: [${legacyCats.map((c) => yamlQuote(c)).join(", ")}]`);
  }
  if (hasTool) lines.push("hasTool: true");
  if (draft) lines.push("draft: true");
  if (validation) {
    lines.push("validation:");
    lines.push(`  posture: ${yamlQuote(validation.posture)}`);
    lines.push(`  testedOn: ${yamlQuote(validation.testedOn)}`);
    if (validation.limits) {
      lines.push(`  limits: ${yamlQuote(validation.limits)}`);
    }
  }
  if (imageRaw) lines.push(`image: ${yamlQuote(unquoteScalar(imageRaw))}`);
  if (imageAltRaw) lines.push(`imageAlt: ${yamlQuote(unquoteScalar(imageAltRaw))}`);
  if (imageWidthRaw) lines.push(`imageWidth: ${unquoteScalar(imageWidthRaw)}`);
  if (imageHeightRaw) lines.push(`imageHeight: ${unquoteScalar(imageHeightRaw)}`);
  if (excerptSepRaw) lines.push(`excerpt_separator: ${yamlQuote(unquoteScalar(excerptSepRaw))}`);
  lines.push("---");

  const next = lines.join("\n") + rest;
  if (next !== raw) {
    fs.writeFileSync(fullPath, next, "utf8");
    updatedCount++;
  }
}

console.log(`Processed ${files.length} posts (${updatedCount} updated).`);
console.log("Pillar distribution:", pillarCounts);
console.log(
  `Canonical tags emitted (${canonicalTagSet.size}):`,
  [...canonicalTagSet].sort().join(", ")
);
