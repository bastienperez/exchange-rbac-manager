# Exchange RBAC Manager

A PowerShell module providing a Windows GUI to **explore and manage** Role-Based Access Control (RBAC) in **Exchange Online**.

Instead of stitching together `Get-RoleGroup`, `Get-ManagementRoleAssignment`, `Get-ManagementScope`, `Search-AdminAuditLog` and friends by hand, you browse and act on them through a single Fluent-style window organised by RBAC concept.

---

## RBAC Visualizer — the headline feature

![RBAC Visualizer](docs/screenshots/rbac-visualizer.png)

Pick any role assignment and the Visualizer turns it into a hub-and-spoke diagram so you can answer the three RBAC questions at a glance:

- **Centre (purple)** — the assignment itself
- **Top-left (green)** — the *Role* it grants (the **what**)
- **Top-right (yellow)** — the *Assignee* it applies to (the **who**)
- **Bottom (pink)** — the *Scope* it is restricted to (the **where**)

Buttons:

- **Pick assignment…** — choose any assignment from a searchable picker
- **Refit / Center** — re-renders if you resized the window
- **Export PNG** — saves the canvas to a PNG for tickets, reviews or documentation

---

## What else it does

The module wraps Exchange Online RBAC cmdlets in a native WPF interface with eight sections in the left navigation:

| # | Section | Underlying cmdlet(s) | What you see |
|---|---|---|---|
| 1 | Role Groups | `Get-RoleGroup` | Names, origin (Built-in / Custom), member counts, role counts, descriptions |
| 2 | Roles | `Get-ManagementRole` | Name, type, Built-in / Custom origin, parent, description |
| 3 | Role Assignments | `Get-ManagementRoleAssignment` | Assignment name, role, assignee, type, read/write scopes |
| 4 | Scopes | `Get-ManagementScope` | Scope name, restriction type, recipient root, filter |
| 5 | User Rights | computed from assignments + `Get-RoleGroup` membership | Effective roles for a given user (UPN or alias) |
| 6 | Command Lookup | `Get-ManagementRole -Cmdlet` | Roles that grant a given cmdlet |
| 7 | RBAC Visualizer | derived from selected assignment | Hub-and-spoke graph (see above) |
| 8 | Audit Log | `Search-AdminAuditLog` | Recent admin changes (last 7 / 30 / 90 days) — *coming in a future release* |

![Role Groups](docs/screenshots/role-groups.png)

![Role Assignments](docs/screenshots/role-assignments.png)

![Roles](docs/screenshots/roles.png)

![Scopes](docs/screenshots/scopes.png)

---

## Installation

```powershell
git clone https://github.com/bastienperez/exchange-rbac-manager.git
Import-Module .\exchange-rbac-manager\ExchangeRBACManager.psd1

# or, install permanently for the current user:
Copy-Item -Path .\exchange-rbac-manager `
          -Destination "$($env:PSModulePath.Split(';')[0])\ExchangeRBACManager" `
          -Recurse -Force
```

### Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- [`ExchangeOnlineManagement`](https://www.powershellgallery.com/packages/ExchangeOnlineManagement) (auto-installed on first launch if missing)
- An Exchange Online tenant and an account with the appropriate Exchange RBAC role (at minimum **View-Only Organization Management** for read scenarios, **Organization Management** for write actions)

---

## Usage

```powershell
Invoke-ExchangeRBACManager
```

A single window opens. Click **Connect to Exchange Online** in the sidebar to authenticate; the tenant block then turns green and the active section loads its data.

### Workflow primer

1. **Connect** — sidebar → *Connect to Exchange Online*. The module piggy-backs on the standard `Connect-ExchangeOnline` flow (modern auth, MFA-aware, optional WAM toggle).
2. **Pick a section** — one click in the sidebar; the title, breadcrumbs, columns and contextual actions adapt.
3. **Filter** — type in the toolbar search box to filter live across all visible columns.
4. **Inspect a row** — selecting a single row opens the **details panel** on the right, showing every field of the underlying object (with text wrapping for long scopes / parameter lists). Column labels and detail labels are kept in sync.
5. **Act on selection** — when you select one or more rows, a **floating contextual action bar** appears at the bottom of the data area, carrying selection-dependent actions (Edit, Copy, Visualize, Preview members, Delete…). View-level actions (Refresh, Export CSV, `+ New …`) live permanently in the toolbar.
6. **Refresh** — toolbar *Refresh* re-queries Exchange Online for the current section.
7. **Export** — every section has *Export CSV* in the toolbar.

---

## Scope membership preview

In the *Scopes* section, select a scope and click **Preview members** in the floating action bar.

The module calls `Get-Recipient -RecipientPreviewFilter <scope filter>` and shows you exactly which recipients fall inside that scope's recipient filter — so you can validate a custom `RecipientRestrictionFilter` before assigning a role to it. Results are capped to a safe number of rows and labelled as *truncated* if the scope matches more than the cap.

This is the read-only equivalent of asking *"who would actually be affected if I attached this scope to a role assignment?"*.

![Scope members preview](docs/screenshots/scope-preview-members.png)

---

## User Rights lookup

In the *User Rights* section, type a UPN or alias and press *Enter*. The module:

1. Walks every cached `Get-ManagementRoleAssignment`
2. For each `RoleGroup` assignee, expands `Get-RoleGroup -Identity … | Members`
3. Returns every effective role + how it was granted (direct / via group) + read & write scopes

Useful before/after onboarding, offboarding, or to answer *"why does this user have access to X?"*.

![User Rights](docs/screenshots/user-rights.png)

---

## Command Lookup

Type a cmdlet name (`Set-Mailbox`, `New-MailboxExportRequest`, …) and press *Enter*. The module calls `Get-ManagementRole -Cmdlet <cmdlet>` and returns every role that grants it, with type, origin (Built-in / Custom) and description.

![Command Lookup](docs/screenshots/command-lookup.png)

---

## Audit Log

Planned for a future release. Clicking the *Audit Log* section currently shows a "coming soon" notice. The implementation will call `Search-AdminAuditLog` over the last 7 / 30 / 90 days (limit imposed by Exchange Online).

---

## Public commands

- `Invoke-ExchangeRBACManager` — launches the GUI
- `Invoke-ExchangeRBACRelationship` — generates a standalone HTML diagram of role-group → role → assignment relationships (separate from the embedded Visualizer)

---

## Author

Bastien Perez — [clidsys.com](https://www.clidsys.com)
