# Codex Global Config

Shared Codex CLI global configuration for local development workflows.

## Included in Git

- `config.toml`
- `skills/` (custom skills only)
- `.gitignore`
- `README.md`

## Excluded from Git

- `auth.json` (sensitive auth)
- runtime logs, sessions, cache, and temp files
- `skills/.system/` (system-managed skills)

See `.gitignore` for exact rules.

## Typical Setup

```bash
git clone <your-repo> ~/.codex
```

Then review `config.toml` and adjust project trust paths for your machine.
