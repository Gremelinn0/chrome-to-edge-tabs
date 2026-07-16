# URSSAF — Rappel échéance (cloud) — Configuration

> **Slug** : `navigateur-urssaf-reminder-cloud`
> **Repo** : `navigateur`
> **Statut** : 🟢 document créé 2026-07-09 — **en attente de propagation** (compte principal routines requis)

## ⚠️ Pré-requis critiques

- **Cron (UTC)** : `0 7 6 * *` — le 6 de chaque mois, ≈ 8h-9h Paris (J-7 avant l'échéance du 13, jour d'ouverture du paiement).
- **Fenêtre active** : août 2026 → janvier 2027 (6 runs restants ; le run du 06/07/2026 est déjà passé). **Désactiver après le run du 06/01/2027** — pas de fin auto, à faire manuellement (`enabled: false` ou suppression).
- **Modèle** : Sonnet (tâche déterministe — lecture mémoire + envoi email).
- **Connecteurs MCP** : Gmail (UUID `4ea3ada1-92a3-4085-84c1-cf184fdd5fd1`, `https://gmailmcp.googleapis.com/mcp/v1`).
- **Repo GitHub attaché** : `navigateur` (pour lire `memory/urssaf_cotisations.md`).

## 1. Contexte business

Florent (EI micro-BNC) a un délai de paiement URSSAF accordé le 24/06/2026 pour sa dette T4 2025 (874 €, 7 échéances mensuelles 13/07/2026 → 13/01/2027, dossier 0105091193). Une échéance ratée fait tomber le délai, relance les poursuites, et perd la remise des majorations de retard. Cette routine est le filet de sécurité **AVANT** échéance (le pendant après-échéance est `navigateur-urssaf-verif-local`). Voir mémoire [[urssaf_cotisations]] pour l'état complet.

## 2. Objectif

Le 6 de chaque mois (jour d'ouverture du paiement, J-7 avant l'échéance du 13), envoyer à Florent un email de rappel avec le montant exact de l'échéance à venir, les références à citer (TI, Dossier), et le lien direct de paiement.

## 3. Architecture (flux haut niveau)

1. Lire `memory/urssaf_cotisations.md` (repo `navigateur`) pour récupérer l'état de l'échéancier et l'échéance du mois en cours.
2. Identifier l'échéance du 13 de ce même mois (numéro, montant papier, montant arrondi site).
3. Composer un email de rappel (voir §5).
4. Envoyer à `florent.maisoncelle@gmail.com` via connecteur Gmail.
5. Ne rien écrire dans le compte URSSAF — lecture mémoire + envoi email uniquement.

## 4. Sources et cibles

- **Source** : `memory/urssaf_cotisations.md` (repo `navigateur`).
- **Cible** : email Gmail à `florent.maisoncelle@gmail.com`.

## 5. Procédure détaillée (prompt de la routine)

> Le prompt de la routine (`events[0].data.message.content` côté RemoteTrigger) référence ce document — jamais de logique dupliquée inline (RÈGLE 1 skill `/routine`).

```
Invoque le skill /impots-urssaf-fr (section URSSAF).

Lis memory/urssaf_cotisations.md dans le repo navigateur pour l'état de l'échéancier de délai
de paiement URSSAF (accord du 24/06/2026, dossier 0105091193, 874 EUR en 7 echeances
13/07/2026 -> 13/01/2027).

Identifie l'echeance dont la date d'echeance (le 13) tombe dans le mois EN COURS.
Si aucune echeance ne correspond au mois en cours (ex: routine encore active apres la
derniere echeance de janvier 2027), n'envoie rien et termine silencieusement.

Sinon, envoie un email a florent.maisoncelle@gmail.com :
- Objet : "URSSAF - Echeance #<n>/7 payable des maintenant (<montant> EUR, le 13/<mois>)"
- Corps : montant exact (papier + arrondi site), rappel "mode au choix, paiement en ligne
  sur autoentrepreneur.urssaf.fr > Mon compte", N Ti 117 1579821172, N Dossier 0105091193,
  lien direct https://www.autoentrepreneur.urssaf.fr/services/espace-personnel/mes-paiements/mes-delais-de-paiement/105091193,
  et l'avertissement : une echeance ratee fait perdre le delai + relance les poursuites +
  fait perdre la remise des majorations de retard.

Ne clique jamais "Payer" ni ne fait aucun mouvement d'argent - envoi d'email uniquement.
```

## 6. Règles strictes

- Ne jamais tenter de payer / se connecter au compte URSSAF (règle argent — Florent seul).
- Ne jamais dupliquer la logique métier dans le prompt de la routine si ce document change — toujours relire ce fichier à jour.
- Si `memory/urssaf_cotisations.md` indique que le délai a été soldé/annulé → ne pas envoyer de rappel, logguer "no action — délai soldé" (pas de rapport formel requis pour une routine cloud, contrairement au local).

## 7. Format du livrable

Un email Gmail envoyé à Florent. Pas de commit, pas de fichier généré.

## 8. Gestion des erreurs

- Mémoire introuvable / illisible → ne pas envoyer d'email approximatif, logguer l'échec.
- Aucune échéance ne correspond au mois → sortie silencieuse (cas attendu après janvier 2027 tant que la routine n'a pas été désactivée).

---

## Propagation (à faire par Florent depuis le compte principal routines)

**MAIN_ACCOUNT_ROUTINES_EMAIL = `florent.maisoncelle@gmail.com`** (cf skill `/routine`). Ce document a été créé depuis une session sur un autre compte — **pas de propagation tentée**.

Quand Florent est sur le compte principal, relancer le skill `/routine` (ou demander explicitement "propage la routine URSSAF cloud") pour créer le trigger via `RemoteTrigger create` avec :
- `name`: `navigateur-urssaf-reminder-cloud`
- `cron_expression`: `0 7 6 * *`
- `job_config.ccr.events[0].data.message.content`: le prompt du §5 ci-dessus
- `session_context.sources`: repo `navigateur`
- `mcp_connections`: Gmail (UUID ci-dessus)

Puis vérification visuelle sur https://claude.ai/code/scheduled (Phase 1.4 du skill `/routine`).
