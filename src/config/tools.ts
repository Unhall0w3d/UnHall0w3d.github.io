/** Curated published resources. Post IDs are resolved against non-draft content at build time. */
export const toolGroups = [
  { id: "phone-changes", title: "Change phone configuration", description: "Explicit phone lists, preview first, and a record of what changed." },
  { id: "audits", title: "Audit and investigate", description: "Read-only CUCM queries to establish what is configured before making a change." },
  { id: "operations", title: "Backups and gateway operations", description: "Focused tools with platform-specific setup and operating limits." },
  { id: "agent-workflows", title: "Agent workflows", description: "Reference designs to adapt to your own projects and available models." },
] as const;

type Tool = {
  id: string;
  group: typeof toolGroups[number]["id"];
  title: string;
  description: string;
  requires: string;
  status: string;
  post: string;
  guideSection?: string;
  downloads?: { label: string; href: string }[];
};

export const tools: Tool[] = [
  {
    id: "blf-labels", group: "phone-changes", title: "CUCM BLF label updater",
    description: "Change a destination's label across a CSV list of phones while preserving each phone's complete BLF collection.",
    requires: "Python 3.10+, requests, Zeep, AXL access, and a phone CSV.",
    status: "Single-phone and batch testing completed on CUCM 14. CUCM 15 has offline coverage only.",
    post: "2026-09-11-updating-cucm-blf-labels-with-python",
    downloads: [
      { label: "Python script", href: "/assets/downloads/cucm-blf-label/blf-label-update.py" },
      { label: "README", href: "/assets/downloads/cucm-blf-label/README.md" },
      { label: "Example CSV", href: "/assets/downloads/cucm-blf-label/phones.example.csv" },
    ],
  },
  {
    id: "auto-answer", group: "phone-changes", title: "CUCM primary-line auto answer (0.2.0-rc4)",
    description: "Check selected phones and set their primary directory numbers to speakerphone auto answer. Shared-line checks are part of preflight.",
    requires: "Python 3.10+, requests, CUCM AXL access, and a phone CSV. AXL 15.0 supports apply. AXL 14.0 is preview-only.",
    status: "CUCM 15 lab: one CIPC Line 1 update verified. A repeat preview returned ALREADY_OK and an inbound call auto-answered on speakerphone.",
    post: "2026-09-11-updating-cucm-auto-answer-from-a-phone-list-with-python",
    downloads: [
      { label: "Python script", href: "/assets/downloads/cucm-auto-answer-candidate/auto-answer-update.py" },
      { label: "README", href: "/assets/downloads/cucm-auto-answer-candidate/README.txt" },
      { label: "Example CSV", href: "/assets/downloads/cucm-auto-answer-candidate/devlist.example.csv" },
    ],
  },
  {
    id: "journal-summary", group: "phone-changes", title: "CUCM journal summary (0.2.0-rc1)",
    description: "Read a saved auto-answer or BLF label journal offline. Check verified updates and unresolved writes in text or JSON.",
    requires: "Python 3.10+ and a saved updater JSONL file.",
    status: "Both formats matched three CUCM 15 auto-answer journals. Legacy auto-answer and BLF coverage uses synthetic fixtures.",
    post: "2026-09-11-updating-cucm-auto-answer-from-a-phone-list-with-python",
    guideSection: "read-the-journal",
    downloads: [
      { label: "Python script", href: "/assets/downloads/cucm-journal-summary-candidate/journal_summary.py" },
      { label: "README", href: "/assets/downloads/cucm-journal-summary-candidate/README.txt" },
    ],
  },
  {
    id: "speed-dial-audit", group: "audits", title: "Find speed dials and BLFs",
    description: "Locate phones monitoring a particular extension and compare labels before and after an ownership change.",
    requires: "CUCM administrative CLI access and the destination to investigate.",
    status: "Read-only SQL, with query examples and interpretation in the guide.",
    post: "2026-08-09-finding-cucm-speed-dials-and-blf-speed-dials-using-sql",
  },
  {
    id: "extension-audit", group: "audits", title: "Extensions and voice mail profiles",
    description: "Inventory directory numbers assigned to phone-class devices, including partitions and voice mail profiles.",
    requires: "CUCM administrative CLI access.",
    status: "Reports configured assignments; it does not establish registration or successful calls.",
    post: "2026-08-25-finding-active-phone-extensions-and-voicemail-profiles-using-cucm-sql",
  },
  {
    id: "calling-access", group: "audits", title: "Local and long-distance calling access",
    description: "Inspect configured route-pattern reachability and authorization-code requirements instead of relying on CSS names.",
    requires: "CUCM administrative CLI access and environment-specific route/partition inputs.",
    status: "Configuration analysis, not proof that an end-to-end call will succeed.",
    post: "2026-08-25-auditing-local-and-long-distance-calling-access-with-cucm-sql",
  },
  {
    id: "uc-drs", group: "operations", title: "Cisco UC DRS backup configuration",
    description: "Prepare a local Windows SFTP destination, preview an ordered cleanup and creation plan, then apply the saved selections for each managed network.",
    requires: "Windows PowerShell 5.1 or PowerShell 7 on Windows; Posh-SSH for UC operations; appliance SSH/OS credentials.",
    status: "v1.6.2 revision 5 testing candidate. PowerShell 7.7.0 / CUCM 15 lab preview and replacement passed: zero preview writes and 12 writes verified through available CLI readback. 253 core and 53 local-setup checks passed offline. Revision 4 manual backups passed separately. Other-product apply, native Windows SFTP setup, scheduled firing and restore are not qualified.",
    post: "2026-11-14-standardizing-cisco-uc-backup-configuration-with-powershell",
    downloads: [
      { label: "v1.6.2 revision 5 testing package", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/UC-DRS-v1.6.2-testing.zip" },
      { label: "PowerShell script", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/Set-UC-DRSBackupSchedules-v1.6.2.ps1" },
      { label: "README", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/README.txt" },
      { label: "Changelog", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/CHANGELOG.txt" },
      { label: "Validation results", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/VALIDATION.txt" },
      { label: "Checksums", href: "/assets/downloads/uc-drs-backups-v1.6.2-candidate/SHA256SUMS.txt" },
    ],
  },
  {
    id: "ruckus-backups", group: "operations", title: "RUCKUS SmartZone backup retriever",
    description: "Retrieve SmartZone backup files through a repeatable PowerShell workflow.",
    requires: "Windows PowerShell and HTTPS access to SmartZone; see the repository for setup.",
    status: "Source is hosted in an external repository. Review its current revision before use.",
    post: "2026-07-01-ruckus-smartzone-backup-retriever",
  },
  {
    id: "analog-guard", group: "operations", title: "Analog stuck-call guard",
    description: "Observe one FXO port and, when explicitly enabled, recover a qualifying stuck call using correlated state checks.",
    requires: "Cisco IOS XE EEM / Tcl and one validated FXO loop-start port.",
    status: "v1.0.6 defaults to observe-only. State matchers need validation on the target; FXS is not equivalent.",
    post: "2026-08-01-when-an-analog-call-refuses-to-die",
    downloads: [
      { label: "Tcl policy", href: "/assets/downloads/analog-stuck-call-guard-v1.0.6.tcl" },
      { label: "Deployment notes", href: "/assets/downloads/analog-stuck-call-guard-deployment-v1.0.6.md" },
    ],
  },
  {
    id: "codex-workflows", group: "agent-workflows", title: "Codex roles and execution workflow",
    description: "Explore scoped delegation, policy boundaries, and evidence checks, with links to the configuration's evolution.",
    requires: "A Codex setup and a review of the models and capabilities available to you.",
    status: "November 2026 configuration. Five role/model pairs verified on CLI 0.166.0; bounded coding and UI fixtures passed. Confirm support and permissions in your client.",
    post: "2026-09-22-from-a-codex-prompt-to-an-agent-execution-system",
    downloads: [
      { label: "November configuration ZIP", href: "/assets/downloads/codex-routing-2026-11-15/codex-routing-2026-11-15.zip" },
      { label: "Setup notes", href: "/assets/downloads/codex-routing-2026-11-15/README.txt" },
      { label: "SHA-256 checksums", href: "/assets/downloads/codex-routing-2026-11-15/SHA256SUMS.txt" },
    ],
  },
];
