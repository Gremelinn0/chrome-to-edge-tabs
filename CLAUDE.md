# navigateur — Règles Claude Code

Dépôt **perso fourre-tout** de Florent (le "stock perso" au sens CLAUDE.md global global §20) : tout ce qui relève de sa vie admin/perso et n'a pas sa place dans les dépôts pro (`wisper-app`, `antigravity`). Porte plusieurs skills locaux dédiés.

## Règle de soumission — soumettre sans redemander (gravée 2026-06-22, verbatim Florent)

Sur les démarches admin de Florent (Gmail, impôts, URSSAF, CAF, bailleur…), une fois qu'il a validé le **CONTENU** d'un message/d'une démarche, **soumets directement** (clique Envoyer / Valider) **SANS redemander** — ne JAMAIS attendre une 2e validation pour le clic final. Les sessions admin (URSSAF, CAF via FranceConnect…) **expirent sans cesse** → attendre = session rafraîchie = **temps perdu**. Verbatim 2026-06-22 : *« tu dois pas attendre ma validation pour soumettre s'il te plaît… sinon ça va se rafraîchir, on aura juste perdu du temps »*.

**SEULE exception : tout mouvement d'argent** (payer une cotisation, un impôt, faire un virement) → là Florent exécute le paiement lui-même (règle financière). Préparer le contenu reste la norme : Florent valide le contenu, Claude soumet.

**Emails Gmail** : triage inbox, filtres, boucle de tri dans la session (pas de routine). Skill `/gmail-filters` (global global). **Règle n°1 (Florent, 2026-09-30) : un filtre ou un libellé RANGE, il ne CACHE pas** — humains, entretiens, rendez-vous, leads, clients restent toujours dans la boîte de réception ; seul le bruit automatique d'un expéditeur exact en sort. Chaque tour annonce, mail par mail, le geste (garder · libellé seul · libellé + hors boîte) avant d'agir.

**Fiscal + social (impôts ET URSSAF)** : déclarations IR/IS/CFE/TVA + cotisations URSSAF auto-entrepreneur (déclarations trimestrielles, dettes, délais de paiement, remises de majorations). Skill `/impots-urssaf-fr` (**global**, `~/.claude/skills/impots-urssaf-fr/` — sa copie dans ce dépôt est historique). État vivant du compte URSSAF = mémoire `urssaf_cotisations.md` ; RSA = `rsa_caf.md`. **Garde-fou** : préparer la démarche, faire valider le **contenu** par Florent, puis **soumettre soi-même** (cf Règle de soumission ci-dessus) ; seul un **paiement** (cotisation, impôt) reste exécuté par Florent.

**CAF / RSA (gravé 2026-09-30)** — lire `references/caf-rsa.md` du skill `/impots-urssaf-fr` AVANT tout geste sur wwwd.caf.fr :
1. **Un message « Contacter ma Caf » n'est PAS la déclaration.** L'alerte « Information manquante » et l'arrêt des versements durent jusqu'au dépôt du CERFA joint (ou de l'e-déclaration) — mesuré 09/09 → 30/09/2026 : deux messages, zéro effet. Ne jamais dire « fait » tant que l'alerte est affichée.
2. **Sur caf.fr, clics par coordonnées, pas par `ref`** : un clic sans effet ne prouve rien (« un seul paiement » conclu à tort ; au clic réel : 3, soit 1 939,56 €).
3. **Aide parentale : 11 718 €/an = 2025 (IR) ; 2026 = 400 + 400 = 800 €/mois (CAF).** Ne jamais lisser l'un en l'autre.
4. **Le CERFA se remplit par script ; chaque ligne (CA, pensions, argent placé) se confirme avec Florent AVANT qu'il signe** (30/09/2026 : 20 € d'assurance-vie avoués après → tout re-signé) ; **Florent le signe** (Edge → Dessiner) ; jamais de signature. **Une connexion se clique** (`/browser-login`) : session FranceConnect ouverte → « S'identifier avec FranceConnect » puis « Continuer sur le site… », sans mot de passe (éprouvé sur l'URSSAF le 30/09/2026) ; on ne tape jamais un identifiant ni un mot de passe, et Florent n'est sollicité que si FranceConnect les redemande.

**Courrier au bailleur** (appartement Charenton, agence SCOMAP) : skill `/logement-scomap` (local). Règle d'or : tout part **au nom de Guillaume** (seul titulaire du bail), depuis son adresse — Claude prépare le mail vers Guillaume, qui le recopie et l'envoie lui-même.

**Preuve/archive Discord** (dossier arnaque Dofus 2022 et besoins similaires futurs) : skill `/discord-dm-export` (local) — capture une conversation Discord complète (DM) en screenshots PNG numérotés, sans saturer la session (capture native PowerShell découplée de la navigation en texte — jamais une image par étape de scroll). Contexte : mémoire `arnaque_dofus_2022.md` + `Documents\Arnaque\DOSSIER-ARNAQUE-2022.md`.

**Repas + courses** : `/recipe-finder` (trouve de bonnes recettes selon les critères de Florent — prépa courte, infos complètes note/avis/étapes — via sa Notion Recettes + Marmiton en Chrome MCP) PUIS `/courses` (commande les ingrédients manquants sur Uber Eats, stop avant paiement). Ordre TOUJOURS recette → courses.

**Autres skills locaux perso** : `/hellofresh` (parrainage), `/leboncoin` (annonces), `/tab-groups-manager`, `/wow-macros` (macros WoW Ascension/Conquest of Azeroth, sorts confirmés sur db.ascension.gg). `/claude-subscriptions` est global et reste chargeable ici comme pont transverse.
