# navigateur — Règles Claude Code

Dépôt **perso fourre-tout** de Florent (le "stock perso" au sens CLAUDE.md global global §20) : tout ce qui relève de sa vie admin/perso et n'a pas sa place dans les dépôts pro (`wisper-app`, `antigravity`). Porte plusieurs skills locaux dédiés.

## Règle de soumission — soumettre sans redemander (gravée 2026-06-22, verbatim Florent)

Sur les démarches admin de Florent (Gmail, impôts, URSSAF, CAF, bailleur…), une fois qu'il a validé le **CONTENU** d'un message/d'une démarche, **soumets directement** (clique Envoyer / Valider) **SANS redemander** — ne JAMAIS attendre une 2e validation pour le clic final. Les sessions admin (URSSAF, CAF via FranceConnect…) **expirent sans cesse** → attendre = session rafraîchie = **temps perdu**. Verbatim 2026-06-22 : *« tu dois pas attendre ma validation pour soumettre s'il te plaît… sinon ça va se rafraîchir, on aura juste perdu du temps »*.

**SEULE exception : tout mouvement d'argent** (payer une cotisation, un impôt, faire un virement) → là Florent exécute le paiement lui-même (règle financière). Préparer le contenu reste la norme : Florent valide le contenu, Claude soumet.

**Emails Gmail** : triage inbox, archivage en masse, filtres. Skill `/gmail-filters` (global global).

**Fiscal + social (impôts ET URSSAF)** : déclarations IR/IS/CFE/TVA + cotisations URSSAF auto-entrepreneur (déclarations trimestrielles, dettes, délais de paiement, remises de majorations). Skill `/impots-urssaf-fr` (local). État vivant du compte URSSAF = mémoire `urssaf_cotisations.md` ; RSA = `rsa_caf.md`. **Garde-fou** : préparer la démarche, faire valider le **contenu** par Florent, puis **soumettre soi-même** (cf Règle de soumission ci-dessus) ; seul un **paiement** (cotisation, impôt) reste exécuté par Florent.

**Courrier au bailleur** (appartement Charenton, agence SCOMAP) : skill `/logement-scomap` (local). Règle d'or : tout part **au nom de Guillaume** (seul titulaire du bail), depuis son adresse — Claude prépare le mail vers Guillaume, qui le recopie et l'envoie lui-même.

**Repas + courses** : `/recipe-finder` (trouve de bonnes recettes selon les critères de Florent — prépa courte, infos complètes note/avis/étapes — via sa Notion Recettes + Marmiton en Chrome MCP) PUIS `/courses` (commande les ingrédients manquants sur Uber Eats, stop avant paiement). Ordre TOUJOURS recette → courses.

**Autres skills locaux perso** : `/hellofresh` (parrainage), `/leboncoin` (annonces), `/claude-subscriptions`, `/tab-groups-manager`.
