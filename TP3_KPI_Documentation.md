# TP 3 - KPI et Couche Analytique Pokémon

## 1. Définition des KPI de Pilotage
Pour piloter la qualité du référentiel, nous avons retenu les indicateurs suivants :

**K1** Taux de Complétude Global % moyen des données présentes par Pokémon Indicateur de santé globale du catalogue. 
**K2** Couverture Artwork % de Pokémon avec une image officielle  Critique pour l'expérience utilisateur finale. 
**K3** Couverture de Stockage (MinIO) % de Pokémon ayant des fichiers JSON bruts stockés  Garantit la traçabilité et le backup des données brutes. 
**K4** Répartition Typologique Volume de Pokémon par type principal Permet de voir si l'échantillon collecté est représentatif. 
**K5** Score de CritiqueNombre de Pokémon avec un score < 40/100  Liste d'action prioritaires pour l'enrichissement. 

## 2. Couche Analytique SQL
La couche analytique repose sur 4 vues principales détaillées dans `tp3_analytical_layer.sql` :
- `v_pokemon_quality` : Fiche d'identité qualité par Pokémon (score, statut).
- `v_analytics_kpis` : Agrégation des indicateurs globaux pour le haut de page du dashboard.
- `v_type_distribution` : Données de répartition pour les graphiques.
- `v_missing_data_alerts` : Liste noire des Pokémon à corriger en priorité.

## 3. Restitution Visuelle avec Metabase
Nous utilisons **Metabase** (exposé sur le port **3001**) pour la restitution analytique. 
Metabase se connecte directement à la base `pokemon_db` et utilise nos vues SQL pour générer les graphiques sans surcharge technique.

### Configuration du Dashboard Metabase
1. **Source de données** : Se connecter à PostgreSQL (`localhost:5432` ou le service `postgres`).
2. **Questions analytiques** :
   - Graphique de type "Gauge" pour le **Global Quality Rate** issu de `v_analytics_kpis`.
   - Graphique "Bar Chart" pour la **Répartition par Type** issue de `v_type_distribution`.
   - Table de données filtrée pour les **Alertes** via `v_missing_data_alerts`.
3. **Mise à jour** : Les graphiques se mettent à jour automatiquement dès que les vues SQL changent (sync n8n).

## 4. Architecture n8n pour Discord
Le workflow n8n (Partie F) est structuré comme suit :
1. **Discord Trigger** (via Webhook ou Bot interaction)
2. **Switch/Router** selon le contenu du message (la commande)
3. **PostgreSQL Node** : Appel des vues analytiques (`v_analytics_kpis`, `v_pokemon_quality`, etc.)
4. **Discord Node** (Send Message) : Retourne une réponse formatée avec un titre et des indicateurs clairs.
