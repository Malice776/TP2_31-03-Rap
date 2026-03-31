# TP1 Pipeline structuré Pokémon avec PokeAPI, n8n et PostgreSQL


## Partie A Mise en place de l'environnement
1. Lancer Docker Desktop.
2. Vérifier que PostgreSQL et n8n fonctionnent correctement.
3. Préparer les connexions nécessaires.


## Partie B Préparation de la base

### Tables SQL

```sql
-- Table pour suivre les ingestions
CREATE TABLE ingestion_runs (
    id SERIAL PRIMARY KEY,
    source VARCHAR(100),
    started_at TIMESTAMP,
    finished_at TIMESTAMP,
    status VARCHAR(50),
    records_received INT,
    records_inserted INT
);

-- Table Pokémon
CREATE TABLE pokemon (
    pokemon_id INT PRIMARY KEY,
    pokemon_name VARCHAR(100),
    base_experience INT,
    height INT,
    weight INT,
    main_type VARCHAR(50),
    has_official_artwork BOOLEAN,
    has_front_sprite BOOLEAN,
    source_last_updated_at TIMESTAMP,
    ingested_at TIMESTAMP,
    run_id INT REFERENCES ingestion_runs(id)
);
```

## Partie C Construction du workflow n8n

## Workflow complet

`NODE 1 HTTP Request` (pour la liste Pokémon)
 - URL mise : https://pokeapi.co/api/v2/pokemon?limit=20
 - Méthode utilisée : GET

`NODE 2 Split Out Items` (pour Item Lists)
 - Objectif : transformer le tableau "results" en items séparés pour la suite
 - Field to Split choisit : results

`NODE 3 HTTP Request` (pour le détail Pokémon)
 - URL choisi : {{ $json.url }}
 - Méthode utilisée : GET

`NODE 4 Function` (transformation des données)

```JavaScript
return $input.all().map(item => {
  const data = item.json;

  return {
    json: {
      pokemon_id: data.id,
      pokemon_name: data.name || null,
      base_experience: data.base_experience || 0,
      height: data.height,
      weight: data.weight,
      main_type: data.types?.[0]?.type?.name || null,
      has_official_artwork: !!data.sprites?.other?.["official-artwork"]?.front_default,
      has_front_sprite: !!data.sprites?.front_default,
      source_last_updated_at: new Date().toISOString(),
      ingested_at: new Date().toISOString()
    }
  };
});
```

`NODE 5 PostgreSQL Insertion dans pokemon`

```SQL

INSERT INTO pokemon (
    pokemon_id,
    pokemon_name,
    base_experience,
    height,
    weight,
    main_type,
    has_official_artwork,
    has_front_sprite,
    source_last_updated_at,
    ingested_at
)
VALUES (
    {{$json.pokemon_id}},
    '{{$json.pokemon_name}}',
    {{$json.base_experience}},
    {{$json.height}},
    {{$json.weight}},
    '{{$json.main_type}}',
    {{$json.has_official_artwork}},
    {{$json.has_front_sprite}},
    '{{$json.source_last_updated_at}}',
    '{{$json.ingested_at}}'
)
ON CONFLICT (pokemon_id) DO NOTHING;
```

`NODE 6 PostgreSQL Suivi de l’ingestion`
- avant pipeline


```SQL
INSERT INTO ingestion_runs (source, started_at, status)
VALUES ('pokeapi', NOW(), 'running')
RETURNING id;
```

- apres pipeline 

```SQL
UPDATE ingestion_runs
SET finished_at = NOW(),
    status = 'success',
    records_received = X,
    records_inserted = Y
WHERE id = run_id;
```

## Partie D Chargement en base

Verification : SELECT * FROM pokemon LIMIT 5;
Exemple de sortie :

```JSON
"pokemon_id": 1,
"pokemon_name": "bulbasaur",
"base_experience": 64,
"height": 7,
"weight": 69,
"main_type": "grass",
"has_official_artwork": true,
"has_front_sprite": true,
"source_last_updated_at": "2026-03-31T10:12:42.247Z",
"ingested_at": "2026-03-31T10:12:42.247Z",
"run_id": null
```

## Partie E Requêtes SQL de contrôle

```SQL
-- 1. Nombre total de Pokémon
SELECT COUNT(*) FROM pokemon;

-- 2. Pokémon sans artwork officiel
SELECT COUNT(*) FROM pokemon WHERE has_official_artwork = FALSE;

-- 3. Pokémon sans sprite frontal
SELECT COUNT(*) FROM pokemon WHERE has_front_sprite = FALSE;

-- 4. Répartition par type principal
SELECT main_type, COUNT(*) FROM pokemon GROUP BY main_type;

-- 5. Pokémon dont le nom est vide ou manquant
SELECT * FROM pokemon WHERE pokemon_name IS NULL OR pokemon_name = '';
```

## Partie F Justification Data Warehouse

L’architecture réalisée suit une logique Data Warehouse car elle suit les principes classiques d’ETL :

`Extraction` : récupération des données depuis la PokéAPI via n8n.
`Transformation` : nettoyage, normalisation et enrichissement des données (gestion des valeurs manquantes, création de booléens).
`Chargement` : insertion dans une base relationnelle PostgreSQL avec tables structurées (ingestion_runs).

Cette séparation garantit des données qui son fiables, traçables et prêtes pour l’analyse.
L’approche est celle d’un data warehouse, car elle permet des requêtes analytiques rapides et répétables sur des données structurées.

`voir TP1_Workflow.png (workflow TP1) pour le workflow`





# TP2 Data Lake avec n8n, PostgreSQL et MinIO

## 2 l'Environnement :

### Services Docker utilises pour le deuxieme tp

- **PostgreSQL 15**  
  - Base : `pokemon_db`  
  - Utilisateur : `postgres`  
  - Mot de passe : `postgres`  
  - Port exposé : 5432

- **n8n**  
  - Port exposé : 5678  

- **MinIO**  
  - Port exposé : 9000  
  - Utilisateur : `minio`  
  - Mot de passe : `minio123`  
  - Buckets créés : `raw-pokemon`, `pokemon-images`, `reports`


## 3 Structure SQL des tables :

### Tables Pokémon 

```sql
CREATE TABLE pokemon (
    pokemon_id INT PRIMARY KEY,
    pokemon_name VARCHAR(100),
    base_experience INT,
    height INT,
    weight INT,
    main_type VARCHAR(50),
    has_official_artwork BOOLEAN,
    has_front_sprite BOOLEAN,
    source_last_updated_at TIMESTAMP,
    ingested_at TIMESTAMP,
    run_id INT
);

CREATE TABLE ingestion_runs (
    run_id SERIAL PRIMARY KEY,
    source VARCHAR(50),
    started_at TIMESTAMP,
    finished_at TIMESTAMP,
    status VARCHAR(20),
    records_received INT,
    records_inserted INT
);
```

### Tables fichiers

```sql
CREATE TABLE pokemon_files (
    file_id SERIAL PRIMARY KEY,
    pokemon_id INT,
    bucket_name VARCHAR(100),
    object_key VARCHAR(255),
    file_name VARCHAR(255),
    file_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE file_ingestion_log (
    id SERIAL PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    bucket_name VARCHAR(255) NOT NULL,
    object_key VARCHAR(255) NOT NULL,
    source VARCHAR(100),
    status VARCHAR(50),
    processed_at TIMESTAMP DEFAULT NOW()
);
```

4. Workflow n8n

### Le workflow contient les nodes :

### HTTP Request
Récupère la liste de Pokémon depuis PokéAPI

`HTTP Request` (détails Pokémon)
Appelle chaque URL Pokémon pour récupérer les détails

`Function Node` (Data Preparation)
Transforme les données JSON pour correspondre aux champs de pokemon
Ajoute timestamps et indicateurs (has_official_artwork, has_front_sprite)

`PostgreSQL Node` (Insert Pokémon)
Insère les données dans la table pokemon
Utilise ON CONFLICT DO NOTHING pour éviter les doublons

`Function Node` (Préparer fichiers pour MinIO)
Génère les métadonnées des fichiers JSON (nom, bucket, clé, type)

`S3 Node` (Upload file)
Upload des fichiers JSON dans le bucket raw-pokemon de MinIO

`PostgreSQL Node` (Insert pokemon_files)
Insère les métadonnées dans la table pokemon_files

`PostgreSQL Node` (Insert file_ingestion_log)
Trace chaque fichier uploadé avec statut success ou failed

## 5 les requêtes SQL de contrôle

```sql

-- Nombre total de Pokemon charges
SELECT COUNT(*) FROM pokemon;

-- Nombre de Pokemon sans image officielle
SELECT COUNT(*) FROM pokemon WHERE has_official_artwork = false;

-- Nombre de Pokemon sans sprite frontal
SELECT COUNT(*) FROM pokemon WHERE has_front_sprite = false;

-- Repartition par type principal
SELECT main_type, COUNT(*) FROM pokemon GROUP BY main_type ORDER BY COUNT(*) DESC;

-- Pokemon dont le nom est vide ou manquant
SELECT * FROM pokemon WHERE pokemon_name IS NULL OR pokemon_name = '';

```

## 6. Preuves de fonctionnement

- Tables PostgreSQL créées et remplies
- Fichiers JSON uploadés dans MinIO (dans raw-pokemon bucket)
- Entrées correspondantes dans pokemon_files et file_ingestion_log
- Workflow n8n testé et fonctionnel


## 7. Justification de l’architecture

PostgreSQL et MinIO permettent de gérer à la fois :
- des données structurées exploitables pour de l’analytique (en mode Data Warehouse)
- des fichiers bruts (JSON, images) qui peuvent être réutilisés ou retraités (en mode Data Lake)
- Les fichiers bruts sont conservés pour assurer la traçabilité et la flexibilité
- La base contient uniquement des métadonnées et références aux fichiers, ce qui réduit la duplication et - permet des traitements analytiques efficaces

Cette architecture est donc plus proche d’un Data Lake / Lakehouse que d’une simple base relationnelle.

## 8. Répertoire GitHub

`docker-compose.yaml`
`workflow_n8n.json`
`README.md`
`TP1_Workflow.png (workflow TP1)`
`TP2_Workflow.png (workflow TP2)`

