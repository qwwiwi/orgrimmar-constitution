# Weekly ideas cleanup (source of truth)

Canonical schedule for idea TTL cleanup.

- Name: `Weekly ideas cleanup (7d TTL)`
- Schedule: `0 7 * * 0` (UTC)
- Command:
  - `cd /home/openclaw/.openclaw/workspaces/kaelthas && bash scripts/ideas-weekly-clean.sh 7`
- Expected behavior:
  - prune only ideas older than 7 days from `ideas/IDEAS.md`
  - write snapshot to `memory/archive/ideas-pruned/pre-clean/`
  - append removed ideas to `memory/archive/ideas-pruned/ideas-pruned-YYYY-MM-DD.md`

## Drift check

Use this to verify the live cron job is aligned with this file:

1. `cron list` → find job name `Weekly ideas cleanup (7d TTL)`
2. Ensure expression is `0 7 * * 0` and timezone `UTC`
3. Ensure payload command runs `scripts/ideas-weekly-clean.sh 7`
