/** Curated published resources. Post IDs are resolved against non-draft content at build time. */
export const toolGroups = [
  { id: "phone-changes", title: "Change phone configuration", description: "Explicit phone lists, preview first, and a record of what changed." },
  { id: "audits", title: "Audit and investigate", description: "Read-only CUCM queries to establish what is configured before making a change." },
  { id: "operations", title: "Backups and gateway operations", description: "Focused tools with platform-specific setup and operating limits." },
  { id: "agent-workflows", title: "Agent workflows", description: "Reference designs to adapt to your own projects and available models." }
] as const;

export type ToolSpec = {
  id: string;
  group: (typeof toolGroups)[number]["id"];
  title: string;
  version?: string;
  postureLabel: string;
  postureVariant: "verified" | "signal" | "neutral";
  description: string;
  requires: string;
  status: string;
  post: string;
  guideSection?: string;
  checksumKey?: string;
  zipHash?: { filename: string; sha256: string };
  downloads?: { label: string; href: string }[];
};

const cucmSqlDownloads = [
  { label: "ZIP Pack", href: "/assets/downloads/cucm-sql-2026-11-20/cucm-sql-2026-11-20.zip" },
  { label: "README", href: "/assets/downloads/cucm-sql-2026-11-20/README.md" },
  { label: "Examples", href: "/assets/downloads/cucm-sql-2026-11-20/EXAMPLES.md" },
  { label: "SHA256SUMS", href: "/assets/downloads/cucm-sql-2026-11-20/SHA256SUMS.txt" }
];

const cucmSqlZipHash = {
  filename: "cucm-sql-2026-11-20.zip",
  sha256: "168c21eb63f27d566dce702451505241981036234d5cc187fcafc7320d093973"
};

export const tools: ToolSpec[] = [
  {
    id: "blf-labels",
    group: "phone-changes",
    title: "CUCM BLF label updater",
    version: "v1.0.0",
    postureLabel: "PREVIEW + APPLY",
    postureVariant: "signal",
    description: "Change a destination's label across a CSV list of phones while preserving each phone's complete BLF collection.",
    requires: "Python 3.10+, requests, Zeep, AXL access, and a phone CSV.",
    status: "Single-phone and batch testing completed on CUCM 14. CUCM 15 has offline coverage only.",
    post: "2026-09-11-updating-cucm-blf-labels-with-python",
    downloads: [
      { label: "Script", href: "/assets/downloads/cucm-blf-label/blf-label-update.py" },
      { label: "README", href: "/assets/downloads/cucm-blf-label/README.md" },
      { label: "Example CSV", href: "/assets/downloads/cucm-blf-label/phones.example.csv" }
    ]
  },
  {
    id: "auto-answer",
    group: "phone-changes",
    title: "CUCM primary-line auto answer",
    version: "v0.2.0-rc4",
    postureLabel: "PREVIEW + APPLY",
    postureVariant: "signal",
    description: "Check selected phones and set their primary directory numbers to speakerphone auto answer. Shared-line checks are part of preflight.",
    requires: "Python 3.10+, requests, CUCM AXL access, and a phone CSV. AXL 15.0 supports apply. AXL 14.0 is preview-only.",
    status: "CUCM 15 lab: one CIPC Line 1 update verified. A repeat preview returned ALREADY_OK and an inbound call auto-answered on speakerphone.",
    post: "2026-09-11-updating-cucm-auto-answer-from-a-phone-list-with-python",
    downloads: [
      { label: "Script", href: "/assets/downloads/cucm-auto-answer-candidate/auto-answer-update.py" },
      { label: "README", href: "/assets/downloads/cucm-auto-answer-candidate/README.txt" },
      { label: "Example CSV", href: "/assets/downloads/cucm-auto-answer-candidate/devlist.example.csv" }
    ]
  },
  {
    id: "journal-summary",
    group: "phone-changes",
    title: "CUCM journal summary",
    version: "v0.2.0-rc1",
    postureLabel: "READ-ONLY",
    postureVariant: "verified",
    description: "Read a saved auto-answer or BLF label journal offline. Check verified updates and unresolved writes in text or JSON.",
    requires: "Python 3.10+ and a saved updater JSONL file.",
    status: "Both formats matched three CUCM 15 auto-answer journals. Legacy auto-answer and BLF coverage uses synthetic fixtures.",
    post: "2026-09-11-updating-cucm-auto-answer-from-a-phone-list-with-python",
    guideSection: "read-the-journal",
    downloads: [
      { label: "Script", href: "/assets/downloads/cucm-journal-summary-candidate/journal_summary.py" },
      { label: "README", href: "/assets/downloads/cucm-journal-summary-candidate/README.txt" }
    ]
  },
  {
    id: "speed-dial-audit",
    group: "audits",
    title: "Find speed dials and BLFs",
    version: "2026-11-20",
    postureLabel: "READ-ONLY",
    postureVariant: "verified",
    description: "Locate phones monitoring a particular extension and compare labels before and after an ownership change.",
    requires: "CUCM publisher CLI or AXL SQL query access.",
    status: "CUCM 15 AXL test found regular speed-dial and DN-backed BLF references to the same extension.",
    post: "2026-08-09-finding-cucm-speed-dials-and-blf-speed-dials-using-sql",
    checksumKey: "cucm-sql-2026-11-20",
    zipHash: cucmSqlZipHash,
    downloads: cucmSqlDownloads
  },
  {
    id: "extension-audit",
    group: "audits",
    title: "Extensions and voice mail profiles",
    version: "2026-11-20",
    postureLabel: "READ-ONLY",
    postureVariant: "verified",
    description: "Inventory directory numbers assigned to phone-class devices, including partitions and voice mail profiles.",
    requires: "CUCM publisher CLI or AXL SQL query access.",
    status: "CUCM 15 AXL test returned four configured line appearances. Registration requires a separate check.",
    post: "2026-08-25-finding-active-phone-extensions-and-voicemail-profiles-using-cucm-sql",
    checksumKey: "cucm-sql-2026-11-20",
    zipHash: cucmSqlZipHash,
    downloads: cucmSqlDownloads
  },
  {
    id: "calling-access",
    group: "audits",
    title: "Local and long-distance calling access",
    version: "2026-11-20",
    postureLabel: "READ-ONLY",
    postureVariant: "verified",
    description: "Inspect configured route-pattern reachability and authorization-code requirements instead of relying on CSS names.",
    requires: "CUCM publisher CLI or AXL SQL query access.",
    status: "CUCM 15 AXL test returned one primary line and two lines across all appearances for the same pattern and partition.",
    post: "2026-08-25-auditing-local-and-long-distance-calling-access-with-cucm-sql",
    checksumKey: "cucm-sql-2026-11-20",
    zipHash: cucmSqlZipHash,
    downloads: cucmSqlDownloads
  },
  {
    id: "uc-drs",
    group: "operations",
    title: "Cisco UC DRS backup configuration",
    version: "v1.6.2-r5",
    postureLabel: "PREVIEW + APPLY",
    postureVariant: "signal",
    description: "Prepare a local Windows SFTP destination, preview an ordered cleanup and creation plan, then apply the saved selections for each managed network.",
    requires: "Windows PowerShell 5.1 or PowerShell 7 on Windows; Posh-SSH for UC operations; appliance SSH/OS credentials.",
    status: "PowerShell 7.7.0 / CUCM 15 lab preview and replacement passed: zero preview writes and 12 writes verified through CLI readback. 253 core and 53 local-setup checks passed offline.",
    post: "2026-11-14-standardizing-cisco-uc-backup-configuration-with-powershell",
    checksumKey: "uc-drs-backups-v1.6.2-candidate",
    zipHash: {
      filename: "UC-DRS-v1.6.2-testing.zip",
      sha256: "b4b105d79517be80704417e999458a32202eda86c76fa6fc788597e00ffabfdc"
    },
    downloads: [
      { label: "ZIP", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/UC-DRS-v1.6.2-testing.zip" },
      { label: "Script", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/Set-UC-DRSBackupSchedules-v1.6.2.ps1" },
      { label: "README", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/README.txt" },
      { label: "Changelog", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/CHANGELOG.txt" },
      { label: "Validation", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/VALIDATION.txt" },
      { label: "SHA256SUMS", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/SHA256SUMS.txt" }
    ]
  },
  {
    id: "ruckus-backups",
    group: "operations",
    title: "RUCKUS SmartZone backup retriever",
    version: "v1.3",
    postureLabel: "READ-ONLY",
    postureVariant: "verified",
    description: "Retrieve SmartZone backup files through a repeatable PowerShell workflow.",
    requires: "Windows PowerShell and HTTPS access to SmartZone; see the repository for setup.",
    status: "Source is hosted in an external repository. Review its current revision before use.",
    post: "2026-07-01-ruckus-smartzone-backup-retriever"
  },
  {
    id: "analog-guard",
    group: "operations",
    title: "Analog stuck-call guard",
    version: "v1.0.6",
    postureLabel: "OBSERVE DEFAULT",
    postureVariant: "verified",
    description: "Observe one FXO port and, when explicitly enabled, recover a qualifying stuck call using correlated state checks.",
    requires: "Cisco IOS XE EEM / Tcl and one validated FXO loop-start port.",
    status: "v1.0.6 defaults to observe-only. State matchers need validation on the target; FXS is not equivalent.",
    post: "2026-08-01-when-an-analog-call-refuses-to-die",
    downloads: [
      { label: "Script", href: "/assets/downloads/analog-stuck-call-guard-v1.0.6.tcl" },
      { label: "README", href: "/assets/downloads/analog-stuck-call-guard-deployment-v1.0.6.md" }
    ]
  },
  {
    id: "codex-workflows",
    group: "agent-workflows",
    title: "Codex roles and execution workflow",
    version: "2026-11-15",
    postureLabel: "REFERENCE",
    postureVariant: "neutral",
    description: "Explore scoped delegation, policy boundaries, and evidence checks, with links to the configuration's evolution.",
    requires: "A Codex setup and a review of the models and capabilities available to you.",
    status: "November 2026 configuration. Five role/model pairs verified on CLI 0.166.0; bounded coding and UI fixtures passed.",
    post: "2026-09-22-from-a-codex-prompt-to-an-agent-execution-system",
    checksumKey: "codex-routing-2026-11-15",
    zipHash: {
      filename: "codex-routing-2026-11-15.zip",
      sha256: "cddff58ad22b1d22c1ebbd22a86c66e460c13a1b8d907478d9eaedcfc3473b9c"
    },
    downloads: [
      { label: "ZIP", href: "/assets/downloads/codex-routing-2026-11-15/codex-routing-2026-11-15.zip" },
      { label: "README", href: "/assets/downloads/codex-routing-2026-11-15/README.txt" },
      { label: "SHA256SUMS", href: "/assets/downloads/codex-routing-2026-11-15/SHA256SUMS.txt" }
    ]
  }
];
