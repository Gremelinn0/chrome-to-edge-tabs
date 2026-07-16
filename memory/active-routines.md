# Routines actives — repo navigateur

- `navigateur-urssaf-reminder-cloud` — cloud — **✅ live**, propagée 2026-07-14 (`trig_01UaFnhfA622GrnpMmHJE8P7`) — cron `0 7 6 * *` UTC (le 6 de chaque mois, ~9h Paris été/8h hiver) — prochain run 06/08/2026 — connecteur Gmail attaché — doc : `docs/routines/navigateur-urssaf-reminder-cloud/00-contexte/navigateur-urssaf-reminder-cloud-config.md`
- `navigateur-urssaf-verif-local` — local — **✅ live**, propagée 2026-07-14 — cron `0 4 15 * *` (LOCAL Paris — le 15 de chaque mois à 4h, fenêtre nuit) — doc : `~/.claude/scheduled-tasks/navigateur-urssaf-verif-local/SKILL.md`

Les deux couvrent l'échéancier URSSAF (délai T4 2025, 874 € / 7x, 13/07/2026 → 13/01/2027) : rappel avant échéance (cloud, J-7) + vérification après échéance (local, J+2). **Désactiver les deux après le run de janvier 2027** (pas de fin auto — `RemoteTrigger update` avec `enabled:false` pour le cloud, MCP `update_scheduled_task` pour le local).

**Note technique (piège RemoteTrigger create/update)** : passer `action`, `trigger_id`, `body` comme paramètres distincts de l'appel — jamais reconstruire le body à la main dans un wrapper/string unique (ça produit un payload illisible côté API, échec systématique). `mcp__scheduled-tasks__create_scheduled_task` régénère entièrement le SKILL.md à partir de `prompt`/`description` et écrase tout contenu déjà présent (repo tag + section Rapport local inclus) — repasser derrière avec `Edit` pour restaurer la structure canonique (RÈGLE 4 + Phase 1.4bis du skill `/routine`).

## 🐛 Bug corrigé 2026-07-16 — une routine ne voit QUE son propre réceptacle

**Symptôme** : `navigateur-urssaf-verif-local` a tourné le 15/07/2026 à 15:55 et n'a produit **aucun rapport** (`memory/reports/` n'existait même pas). Échec 100 % silencieux — sans le `/drive` qui a vérifié, personne ne l'aurait jamais su.

**Racine** : les 2 routines pointaient vers `memory/urssaf_cotisations.md` **« dans le repo navigateur »** — ce fichier n'y est PAS. Il vit dans l'auto-memory `~/.claude/projects/C--Users-Utilisateur-PROJECTS-navigateur/memory/`. La routine échouait dès l'étape 1.

**Aggravant côté cloud** : une routine cloud **clone le dépôt GitHub** et ne voit QUE lui — l'auto-memory locale lui est structurellement invisible. Elle aurait échoué au 1er run (06/08) sans que rien ne l'annonce.

**Fix appliqué** :
- Doc cloud rendu **auto-suffisant** (tableau des 7 échéances + toutes les références DANS le doc versionné) ; interdiction explicite d'aller chercher l'auto-memory.
- Routine locale passée en **chemins absolus** (auto-memory + rapport).
- **Rapport obligatoire même en échec** + email d'alerte si la vérif est impossible (Chrome down, session expirée) → plus jamais de run muet.

**Règle générale à retenir** : *une routine ne lit de façon fiable que ce qui vit dans le réceptacle qu'elle voit au runtime* — cloud = le dépôt cloné · locale = le disque (chemins absolus). Toute donnée nécessaire doit être **dans ce réceptacle**, jamais dans un `memory/` d'un autre espace. Et **un run qui ne peut pas faire son travail doit crier**, pas se taire.
