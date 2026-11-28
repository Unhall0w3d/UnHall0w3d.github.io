export const PILLARS = [
  "unified-communications",
  "automation-tooling",
  "local-ai-agents",
  "systems-infrastructure",
  "field-log-craft"
] as const;

export type Pillar = (typeof PILLARS)[number];

export const PILLAR_META: Record<
  Pillar,
  { title: string; shortTitle: string; description: string }
> = {
  "unified-communications": {
    title: "Unified Communications",
    shortTitle: "Unified Comms",
    description:
      "CUCM, Unity Connection, UCCX, IM & Presence, Expressway, and IOS XE voice gateway operations."
  },
  "automation-tooling": {
    title: "Automation & Tooling",
    shortTitle: "Automation",
    description:
      "Python, PowerShell, AXL, and read-only SQL workflows engineered for preview-first network operations."
  },
  "local-ai-agents": {
    title: "Local AI & Agents",
    shortTitle: "Local AI",
    description:
      "Local LLM orchestration, multi-GPU inference, Soul/, and bounded Codex subagent execution systems."
  },
  "systems-infrastructure": {
    title: "Systems & Infrastructure",
    shortTitle: "Infrastructure",
    description:
      "Linux workstations and servers, NixOS, VMware ESXi, Proxmox, Cisco UCS, and network platform administration."
  },
  "field-log-craft": {
    title: "Field Log & Craft",
    shortTitle: "Field Log",
    description:
      "Engineering post-mortems, certification notes, static web architecture, and Linux gaming craft."
  }
};

export const CANONICAL_TAG_LABELS: Record<string, string> = {
  "agent-workflows": "Agent Workflows",
  "aletheia-uc": "AletheiaUC",
  astro: "Astro",
  axl: "AXL",
  backups: "Backups & DRS",
  "cisco-ucs": "Cisco UCS",
  codex: "Codex",
  cucm: "CUCM",
  "dial-plan": "Dial Plan",
  "emergency-responder": "Emergency Responder",
  expressway: "Expressway & VCS",
  "gpu-tuning": "GPU Tuning",
  "health-checks": "Health Checks",
  "im-presence": "IM & Presence",
  "ios-xe": "IOS XE & Gateways",
  lab: "Lab Builds",
  linux: "Linux",
  "llama-cpp": "llama.cpp",
  "local-llm": "Local LLM",
  nixos: "NixOS",
  "phone-config": "Phone Config",
  powershell: "PowerShell",
  python: "Python",
  security: "Security & Certs",
  smartzone: "RUCKUS SmartZone",
  "soul-slash": "Soul/",
  sql: "SQL & Informix",
  uccx: "UCCX",
  "unity-connection": "Unity Connection",
  "unreal-engine": "Unreal Engine",
  virtualization: "Virtualization"
};

/** Retired /categories/<slug>.html -> canonical destination */
export const RETIRED_CATEGORY_REDIRECTS: Record<string, string> = {
  arch: "/categories/systems-infrastructure.html",
  automation: "/categories/automation-tooling.html",
  cisco: "/categories/unified-communications.html",
  "cisco-ucs": "/categories/systems-infrastructure.html",
  "cisco-unified-contact-center": "/categories/unified-communications.html",
  debian: "/categories/systems-infrastructure.html",
  gaming: "/categories/field-log-craft.html",
  general: "/categories/field-log-craft.html",
  "ios-xe": "/categories/unified-communications.html",
  linux: "/categories/systems-infrastructure.html",
  "microsoft-windows": "/categories/systems-infrastructure.html",
  powershell: "/categories/automation-tooling.html",
  python: "/categories/automation-tooling.html",
  ruckus: "/categories/systems-infrastructure.html",
  sql: "/categories/automation-tooling.html",
  vmware: "/categories/systems-infrastructure.html",
  "web-development": "/categories/field-log-craft.html"
};

/** Retired /tags/<slug>.html -> canonical destination */
export const RETIRED_TAG_REDIRECTS: Record<string, string> = {
  "action-plan": "/tags/health-checks.html",
  aletheiauc: "/tags/aletheia-uc.html",
  "alternate-extensions": "/tags/unity-connection.html",
  amd: "/tags/gpu-tuning.html",
  "analog-voice": "/tags/ios-xe.html",
  arch: "/tags/linux.html",
  "artificial-intelligence": "/tags/local-llm.html",
  "auto-answer": "/tags/phone-config.html",
  automation: "/categories/automation-tooling.html",
  backup: "/tags/backups.html",
  blf: "/tags/phone-config.html",
  "blf-speed-dial": "/tags/phone-config.html",
  "call-detail-record": "/tags/cucm.html",
  "calling-search-space": "/tags/dial-plan.html",
  callmanager: "/tags/cucm.html",
  certificates: "/tags/security.html",
  cisco: "/categories/unified-communications.html",
  "cisco-emergency-responder": "/tags/emergency-responder.html",
  "cisco-expressway": "/tags/expressway.html",
  "cisco-jabber": "/tags/im-presence.html",
  "cisco-phone": "/tags/phone-config.html",
  "cisco-uc": "/tags/cucm.html",
  "cisco-ucs-c": "/tags/cisco-ucs.html",
  "cisco-unified-border-element": "/tags/ios-xe.html",
  "cisco-unified-communications-manager": "/tags/cucm.html",
  "cisco-unified-contact-center": "/tags/uccx.html",
  "cisco-unified-contact-center-express": "/tags/uccx.html",
  "cisco-unified-im-and-presence": "/tags/im-presence.html",
  "cisco-unity-connection": "/tags/unity-connection.html",
  "cisco-vcs": "/tags/expressway.html",
  "computer-vision": "/tags/local-llm.html",
  csv: "/tags/phone-config.html",
  "data-center": "/tags/virtualization.html",
  database: "/tags/sql.html",
  debian: "/tags/linux.html",
  "directory-number": "/tags/dial-plan.html",
  "disaster-recovery-system": "/tags/backups.html",
  dns: "/tags/linux.html",
  eem: "/tags/ios-xe.html",
  endeavoros: "/tags/linux.html",
  "forced-authorization-code": "/tags/dial-plan.html",
  fxo: "/tags/ios-xe.html",
  fxs: "/tags/ios-xe.html",
  "game-development": "/tags/unreal-engine.html",
  gaming: "/tags/unreal-engine.html",
  general: "/categories/field-log-craft.html",
  git: "/tags/linux.html",
  "github-pages": "/tags/astro.html",
  gpu: "/tags/gpu-tuning.html",
  hyprland: "/tags/linux.html",
  informix: "/tags/sql.html",
  "log-review": "/tags/health-checks.html",
  mcp: "/tags/agent-workflows.html",
  "media-resource": "/tags/ios-xe.html",
  "music-production": "/tags/soul-slash.html",
  nix: "/tags/nixos.html",
  "noc-thoughts": "/tags/astro.html",
  nvidia: "/tags/gpu-tuning.html",
  openclaw: "/tags/agent-workflows.html",
  opencode: "/tags/agent-workflows.html",
  openssh: "/tags/linux.html",
  paramiko: "/tags/python.html",
  paru: "/tags/linux.html",
  privacy: "/tags/local-llm.html",
  proxmox: "/tags/virtualization.html",
  psirt: "/tags/security.html",
  reports: "/posts.html",
  "route-pattern": "/tags/dial-plan.html",
  ruckus: "/tags/smartzone.html",
  sccp: "/tags/ios-xe.html",
  sftp: "/tags/backups.html",
  skills: "/tags/agent-workflows.html",
  "software-development": "/tags/agent-workflows.html",
  "speed-dial": "/tags/phone-config.html",
  ssh: "/tags/linux.html",
  storage: "/tags/virtualization.html",
  subagents: "/tags/agent-workflows.html",
  tcl: "/tags/ios-xe.html",
  telepresence: "/tags/expressway.html",
  "unified-communications": "/categories/unified-communications.html",
  vcenter: "/tags/virtualization.html",
  vcsa: "/tags/virtualization.html",
  vmware: "/tags/virtualization.html",
  "vmware-esxi": "/tags/virtualization.html",
  voice: "/tags/local-llm.html",
  "voice-gateway": "/tags/ios-xe.html",
  "voice-mail-profile": "/tags/unity-connection.html",
  vsz: "/tags/smartzone.html",
  website: "/tags/astro.html",
  zsh: "/tags/linux.html"
};

export function pillarTitle(pillar: Pillar): string {
  return PILLAR_META[pillar]?.title ?? pillar;
}

export function tagLabel(slug: string): string {
  return CANONICAL_TAG_LABELS[slug] ?? slug;
}
