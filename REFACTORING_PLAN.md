# Plan de Refactorisation Maybe Finance Self-Hosted

## 🎯 OBJECTIF PRINCIPAL
Transformer Maybe Finance en application 100% self-hosted, épurée des composants "managed mode", avec intégration Tink pour les données bancaires.

## 📊 ANALYSE ARCHITECTURALE

### Différences Managed vs Self-Hosted
- **UN SEUL CODEBASE** - Différenciation via `SELF_HOSTED=true/false`
- **Détection** : `Rails.application.config.app_mode.self_hosted?`
- **Mode self-hosted** = fonctionnalités désactivées (facturation, emails auto, analytics)

### Architecture Actuelle
```
Models (Domaine Métier)
├── Family → Users → Accounts → Entries → Transactions
├── Système Synchronisation (Plaid)
├── Système IA/Chat (À CONSERVER)
├── Système Facturation (À SUPPRIMER)
└── Système Import/Export

Frontend (Hotwire + Tailwind)
├── Design System complet (250+ variables CSS)
├── ViewComponents réutilisables
└── Mode sombre intégré
```

## 🚀 PHASES D'EXÉCUTION

### PHASE 0 : DONNÉES DE DÉMO ✅
**Objectif** : Charger données complètes (8k-12k transactions)

**Commandes terminal** :
```bash
cd /Users/martincharpentier/Dev/number-go-up/maybe
bin/rails db:reset
DISABLE_SPRING=1 DEMO_DATA_SEED=12345 bin/rails demo_data:default
bin/rails server -p 3001
```

**Test utilisateur** :
- Vérifier localhost:3001
- Login : `user@maybe.local` / `password`
- Tester navigation, montants, chat IA

**Commit si OK** : "Reset DB with full demo data"

---

### PHASE 1 : ANALYSE & AUDIT
**Objectif** : Identifier tous les composants MANAGED à supprimer

**Actions techniques** :
1. Mappage composants avec `guard_feature if: -> { self_hosted? }`
2. Identification vues avec `<% if !self_hosted? %>`
3. Audit CSS/assets managed-specific

**Test utilisateur** :
- Explorer toutes sections interface
- Identifier visuellement éléments "managed"
- Noter fonctionnalités importantes à préserver

**Commit si OK** : "Analysis complete - managed components identified"

---

### PHASE 2 : NETTOYAGE COMPOSANTS MANAGED
**Objectif** : Supprimer progressivement les éléments managed

#### 2.1 Facturation Stripe
**À supprimer** :
- `app/controllers/subscriptions_controller.rb`
- `app/models/subscription.rb`
- `app/models/family/subscribeable.rb`
- `app/models/provider/stripe.rb`
- Vues facturation

**Test** : Interface settings sans erreurs
**Commit** : "Remove Stripe billing components"

#### 2.2 Authentification simplifiée
**À modifier** :
- Simplifier `registrations_controller.rb`
- Nettoyer onboarding complexe
- Supprimer confirmations email automatiques

**Test** : Création compte, login/logout
**Commit** : "Simplify authentication flow"

#### 2.3 Interface utilisateur épurée
**À retirer** :
- Éléments "upgrade premium"
- Alertes managed mode
- Navigation complexe settings

**Test** : Navigation fluide, design cohérent
**Commit** : "Clean up managed UI elements"

---

### PHASE 3 : OPTIMISATION FRONTEND
**Objectif** : Nettoyer CSS et prévenir effets de bord

**Actions** :
1. Backup design system complet
2. Nettoyage variables CSS inutiles
3. Suppression composants managed-only
4. Tests responsive

**Tests fréquents** : Pas d'effets de bord visuels
**Commits** : "Optimize CSS - step X"

---

### PHASE 4 : PRÉPARATION TINK
**Objectif** : Préparer intégration agrégateur Tink

**Étude préalable** :
- Architecture Plaid existante (`PlaidItem`, `PlaidAccount`)
- Patterns synchronisation
- Processeurs et importers

**Développement** :
```ruby
# Structure à créer
class TinkItem < ApplicationRecord
  belongs_to :family
  has_many :tink_accounts
end

class TinkAccount < ApplicationRecord
  belongs_to :tink_item
  belongs_to :account
end
```

**Test** : Structure stable, pas de régression
**Commit** : "Add Tink integration foundation"

---

### PHASE 5 : INTÉGRATION TINK COMPLÈTE
**Objectif** : Connexion fonctionnelle avec Tink

**Étapes** :
1. Configuration API Tink
2. Authentification et connexion comptes
3. Import/synchronisation transactions
4. Tests intégration complète

**Tests à chaque étape** : Fonctionnalité progressive
**Commits fréquents** : "Tink integration - step X"

---

## 🛠️ MÉTHODOLOGIE DE TRAVAIL

### Processus validé :
1. **Commandes longues** → Terminal séparé (éviter timeout contexte)
2. **Tests fréquents** → Validation interface après chaque modification
3. **Commits réguliers** → Checkpoints dès validation fonctionnelle
4. **Documentation** → Plan mis à jour selon avancement

### Critères de validation :
- ✅ Interface propre et épurée
- ✅ Fonctionnalités financières core intactes  
- ✅ Chat/IA fonctionnel
- ✅ Pas d'éléments "managed mode"
- ✅ Performance stable
- ✅ Prêt pour intégration Tink

### Commands de référence :
```bash
# Reset complet
bin/rails db:reset

# Données démo complètes
DISABLE_SPRING=1 DEMO_DATA_SEED=12345 bin/rails demo_data:default

# Serveur développement
bin/rails server -p 3001

# Tests
bin/rails test

# Lint/format
bin/rubocop -a
```

---

## 📝 ÉTAT D'AVANCEMENT

- [ ] Phase 0 : Données démo
- [ ] Phase 1 : Analyse composants
- [ ] Phase 2 : Nettoyage managed
- [ ] Phase 3 : Optimisation frontend  
- [ ] Phase 4 : Préparation Tink
- [ ] Phase 5 : Intégration Tink

---

*Plan créé le : 2025-08-04*  
*Dernière mise à jour : 2025-08-04*