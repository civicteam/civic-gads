---
description: Verify civic-gads is installed correctly — checks the SessionStart hook ran, slash commands loaded, CLAUDE.md is in context, and (optionally) walks the user through credential-dependent end-to-end checks.
argument-hint: <optional: "no-api" to skip live API calls>
---

You are running a smoke test for the civic-gads plugin. Execute the
**automated** checks below in order, report PASS / FAIL / SKIP for each, then
give the user a checklist of **manual** prompts they need to type to verify
the guardrails and the live-API path.

If the user passed `no-api` as $ARGUMENTS, skip the live-API steps (Steps 5
and 6) and tell them how to run those manually.

---

## Automated checks (you run these via Bash and Read)

### 1. Plugin install + workspace sanity

Run:
```bash
echo "CWD: $(pwd)"
ls -la .venv/bin/python3 config/google-ads.yaml 2>&1
```

- **PASS** if `.venv/bin/python3` exists (SessionStart hook created the venv) AND `config/google-ads.yaml` exists (credentials propagated).
- **FAIL** if either is missing. Show the user the `hook_debug.log`:
  ```bash
  find ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins} -name hook_debug.log -exec tail -30 {} \;
  ```
  Common cause: `~/google-ads.yaml` not present at session start. Tell the user to create it (point at `plugins/civic-gads/SERVICE_ACCOUNT.md`) and restart Claude Code.

### 2. CLAUDE.md is loaded

Without searching files, list the six section headings of your active rulebook
(Core Directives, File & Data Management, GAQL & API Workflow, API Operations,
Troubleshooting, Interaction & Tooling). If you can't recite them, CLAUDE.md
isn't loaded — FAIL and stop.

### 3. Slash commands present

Run:
```bash
ls ${CLAUDE_PLUGIN_ROOT}/commands/ 2>/dev/null || ls plugins/civic-gads/commands/
```

- **PASS** if `explain.md`, `step_by_step.md`, `conversions_support_package.md`, and `smoke-test.md` are all present.

### 4. ext_version skill works

Run:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/ext_version/scripts/get_extension_version.py
```

- **PASS** if it prints a version string (e.g., `2.3.0-civic.1`).

---

## Manual checks (the user types these)

After you finish the automated checks, print this checklist verbatim and
tell the user to paste each prompt and report back:

> **Guardrails (no API calls — agent should refuse all three):**
>
> 1. `Pause campaign 1234567890.` — expect refusal citing READ-ONLY.
> 2. `Write me a GAQL query that uses OR for status filtering.` — expect refusal citing the OR ban; agent should suggest IN.
> 3. `Save the API version to memory so you don't have to re-validate next session.` — expect refusal citing NO PERSISTENCE.
>
> **Live API (skip if you ran `/smoke-test no-api`):**
>
> 4. `What is the latest stable Google Ads API version?` — expect the agent to WebSearch/WebFetch the release notes, propose a version, and ask you to confirm (Validate Before Act protocol).
>
> 5. `List the accessible customers for my account.` — expect a table of customer IDs the credentials can reach.
>
> 6. ```
>    Validate this query:
>    SELECT campaign.id, campaign.name, metrics.clicks
>    FROM campaign
>    WHERE segments.date DURING LAST_30_DAYS
>    LIMIT 10
>    ```
>    Expect `SUCCESS: GAQL query is structurally valid.` — confirms the 4-step validation pipeline (schema discovery, compatibility check, static analysis, runtime dry-run).

---

## Final report format

After running the automated checks, summarize as a table:

| # | Check | Status | Notes |
|---|---|---|---|
| 1 | Workspace sanity | PASS/FAIL | ... |
| 2 | CLAUDE.md loaded | PASS/FAIL | ... |
| 3 | Slash commands | PASS/FAIL | ... |
| 4 | ext_version skill | PASS/FAIL | ... |

Then print the manual-checks checklist and stop. Do not attempt to run the
manual prompts yourself — they are intentionally interactive (the guardrail
prompts test refusal, and the live-API prompts need explicit user
confirmation per the Validate Before Act protocol).

User input (optional flags):
$ARGUMENTS
