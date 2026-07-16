# Routines actives — repo navigateur

- `navigateur-urssaf-reminder-cloud` — cloud — **✅ live**, propagée 2026-07-14 (`trig_01UaFnhfA622GrnpMmHJE8P7`) — cron `0 7 6 * *` UTC (le 6 de chaque mois, ~9h Paris été/8h hiver) — prochain run 06/08/2026 — connecteur Gmail attaché — doc : `docs/routines/navigateur-urssaf-reminder-cloud/00-contexte/navigateur-urssaf-reminder-cloud-config.md`
- `navigateur-urssaf-verif-local` — local — **✅ live**, propagée 2026-07-14 — cron `0 4 15 * *` (LOCAL Paris — le 15 de chaque mois à 4h, fenêtre nuit) — doc : `~/.claude/scheduled-tasks/navigateur-urssaf-verif-local/SKILL.md`

Les deux couvrent l'échéancier URSSAF (délai T4 2025, 874 € / 7x, 13/07/2026 → 13/01/2027) : rappel avant échéance (cloud, J-7) + vérification après échéance (local, J+2). **Désactiver les deux après le run de janvier 2027** (pas de fin auto — `RemoteTrigger update` avec `enabled:false` pour le cloud, MCP `update_scheduled_task` pour le local).

**Note technique (piège RemoteTrigger create/update)** : passer `action`, `trigger_id`, `body` comme paramètres distincts de l'appel — jamais reconstruire le body à la main dans un wrapper/string unique (ça produit un payload illisible côté API, échec systématique). `mcp__scheduled-tasks__create_scheduled_task` régénère entièrement le SKILL.md à partir de `prompt`/`description` et écrase tout contenu déjà présent (repo tag + section Rapport local inclus) — repasser derrière avec `Edit` pour restaurer la structure canonique (RÈGLE 4 + Phase 1.4bis du skill `/routine`).
