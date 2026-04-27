# civic-gads — Google Ads API Developer Assistant for Claude Code

A Claude Code plugin that turns your terminal into a Google Ads API expert. Ask
questions in natural language, generate validated GAQL and Python (or PHP /
Ruby / Java / .NET) code against the official client libraries, and execute
read-only API calls — all with strict guardrails.

This is a Civic-internal port of [`googleads/google-ads-api-developer-assistant`](https://github.com/googleads/google-ads-api-developer-assistant)
from a Gemini CLI extension to a Claude Code plugin. See `NOTICE` for the
attribution and a list of port changes.

## What it can do

- **Natural-language Q&A** about API concepts, fields, and usage.
- **GAQL generation** with a 4-step validation pipeline: schema discovery →
  compatibility check → static analysis → runtime dry-run via
  `validate_only=True`.
- **Code generation** in Python (default), PHP, Ruby, Java, or C#. Python /
  PHP / Ruby code can be executed directly from the chat; Java and C# are
  generated for you to compile separately.
- **Direct API execution** inside a managed `.venv/` so the host system stays
  clean.
- **CSV export** of tabular results to `saved/csv/`.
- **Conversion troubleshooting** via `/conversions_support_package`, which
  produces a single-file diagnostic bundle for gTech support.
- **GAQL validation on demand** — paste any query after `validate:` and the
  agent will run it against the strict rule set.

## Hard guardrails (preserved verbatim from upstream)

- **Read-only.** No `mutate`, `create`, `update`, or `delete` API calls.
- **No `OR` in GAQL.** The agent uses `IN` or executes multiple queries.
- **No `FROM` in metadata queries.** `GoogleAdsFieldService` queries are
  enforced bare.
- **Mandatory ruff lint** on every generated Python script before write/exec.
- **Mandatory `validate_only=True` dry-run** on every GAQL query before exec.
- **No client library mutations.** `client_libs/` is read-only context.
- **No secrets in chat.** Developer tokens, OAuth secrets, and PII are never
  printed or persisted.
- **No version persistence.** The confirmed Google Ads API version is
  per-session and never written to Claude Code's auto-memory.

## Supported languages

| Language | Generation | Direct execution |
| --- | --- | --- |
| Python (default) | ✓ | ✓ |
| PHP | ✓ | ✓ |
| Ruby | ✓ | ✓ |
| Java | ✓ | (compile separately) |
| C# (.NET) | ✓ | (compile separately) |

To generate code in a non-default language, tell the agent:
`write saved code examples in <language>`. For C#, use `in dotnet` to set the
context.

## Prerequisites

1. Familiarity with Google Ads API concepts and authentication.
2. A Google Ads API developer token.
3. A configured credentials file in your home directory:
   - Python: `~/google-ads.yaml`
   - PHP: `~/google_ads_php.ini`
   - Ruby: `~/google_ads_config.rb`
   - Java: `~/ads.properties`
4. [Claude Code](https://claude.com/claude-code) installed.
5. Python ≥ 3.10 on your `PATH` (used by the SessionStart hook to provision
   `.venv/`).
6. `git`. The Bash installer drops the upstream `jq` dependency.

For service-account / impersonation setups, see `SERVICE_ACCOUNT.md`.

## Setup

```bash
git clone <civic-internal-url>/civic-gads.git
cd civic-gads
./install.sh                     # Python only (default)
./install.sh --php --ruby        # add other languages as needed
```

Then open the directory in Claude Code:

```bash
claude
```

The first time you start a session, the `SessionStart` hook will:

1. Create `./.venv/` and install `google-ads` + `ruff` into it.
2. Copy your credentials from `~/google-ads.yaml` (or a fallback) into
   `./config/google-ads.yaml`, appending the plugin version for telemetry.
3. Inject the deterministic venv path and `GOOGLE_ADS_CONFIGURATION_FILE_PATH`
   into the session via Claude Code's `additionalContext` channel.

When the session ends, the `SessionEnd` hook removes `./.venv/` and clears
`./config/`, so credentials never linger on disk.

## Try it

```
> What are the available campaign types?
> Show me campaigns with the most conversions in the last 30 days.
> Get all ad groups for customer '123-456-7890'.
> Find disapproved ads across all campaigns.
> Save results to a csv file
> Troubleshoot my conversions for customer '123-456-7890'.
```

Slash commands:

- `/explain <code or concept>` — fast plain-language explainer with analogies.
- `/step_by_step <task>` — turns a request into an ordered, verifiable plan.
- `/conversions_support_package` — produces the gTech-ready single-file
  diagnostic.

## Project layout

```
civic-gads/
├── .claude-plugin/plugin.json     # plugin manifest
├── .claude/
│   ├── settings.json              # SessionStart/SessionEnd hooks
│   ├── commands/                  # slash commands (Markdown + frontmatter)
│   ├── skills/ext_version/        # version skill
│   └── hooks/                     # configure_environment.py, cleanup_environment.py, check_github_version.py
├── CLAUDE.md                      # the agent's persistent rulebook
├── conversions/CLAUDE.md          # @-imported troubleshooting reference
├── api_examples/                  # vetted Python scripts incl. gaql_validator.py
├── client_libs/                   # cloned by install.sh (gitignored)
├── config/                        # populated by SessionStart hook (gitignored)
├── saved/
│   ├── code/                      # all generated/modified scripts
│   ├── csv/                       # tabular output
│   └── data/                      # diagnostic reports
├── customer_id.txt                # default customer ID for prompts
├── install.sh / install.ps1       # clones client libraries
├── update.sh / update.ps1         # updates project + libraries
└── uninstall.sh / uninstall.ps1   # removes the project directory
```

## Project context for your code

To let the assistant read your application logic when generating saved code
examples, add the path to `additionalDirectories` in `.claude/settings.json`,
or symlink your project under `civic-gads/` so it sits inside the agent's
default working tree. Claude Code's `Read`/`Grep` will pick it up natively.

(The upstream's `--context_dir` flag was a thin wrapper around
`.gemini/settings.json.context.includeDirectories`; with no equivalent file
to mutate in this port, settings are now edited directly.)

## Known follow-ons

- `tests/` was carried over from the upstream and targets the original
  `.gemini/`-flavored `install.sh`, `update.sh`, and `configure_environment.py`.
  These tests will not pass against the Claude Code port until rewritten —
  the entry points still exist but the behavior they assert (jq-mediated
  `.gemini/settings.json` mutation, `gemini extensions install`, save_memory
  policy file management) has been replaced. Treat them as TODO.
- The SessionStart hook output uses Claude Code's `additionalContext`
  channel to inform the agent of the venv path and
  `GOOGLE_ADS_CONFIGURATION_FILE_PATH`. Verify on first use that the agent
  is correctly prepending the env var to Bash invocations.
- `CIVIC_GADS_REMOTE_PLUGIN_JSON_URL` is currently unset, so the
  remote-version check in `check_github_version.py` is silently skipped.
  Set it once a Civic-internal hosting URL is decided.

## License & attribution

Apache 2.0. See `LICENSE` and `NOTICE`. Original work by Google LLC; port and
Civic adaptations by Civic Technologies, Inc.
