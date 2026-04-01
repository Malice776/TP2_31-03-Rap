-- ==========================================
-- TP3 : Couche Analytique Pokémon
-- ==========================================

-- 1. Vue détaillée de la qualité par Pokémon
-- Permet d'identifier rapidement les fiches incomplètes
CREATE OR REPLACE VIEW v_pokemon_quality AS
SELECT 
    p.pokemon_id,
    p.pokemon_name,
    p.main_type,
    p.has_official_artwork,
    p.has_front_sprite,
    (SELECT COUNT(*) FROM pokemon_files pf WHERE pf.pokemon_id = p.pokemon_id) as file_count,
    CASE 
        WHEN p.has_official_artwork AND p.has_front_sprite AND (SELECT COUNT(*) FROM pokemon_files pf WHERE pf.pokemon_id = p.pokemon_id) > 0 THEN 'Complète'
        WHEN p.has_official_artwork OR p.has_front_sprite THEN 'Partielle'
        ELSE 'Critique'
    END as quality_status,
    -- Score de complétude sur 100
    (
        (CASE WHEN p.pokemon_name IS NOT NULL AND p.pokemon_name <> '' THEN 20 ELSE 0 END) +
        (CASE WHEN p.main_type IS NOT NULL THEN 20 ELSE 0 END) +
        (CASE WHEN p.has_official_artwork THEN 20 ELSE 0 END) +
        (CASE WHEN p.has_front_sprite THEN 20 ELSE 0 END) +
        (CASE WHEN (SELECT COUNT(*) FROM pokemon_files pf WHERE pf.pokemon_id = p.pokemon_id) > 0 THEN 20 ELSE 0 END)
    ) as completeness_score
FROM pokemon p;

-- 2. Vue de synthèse pour le pilotage (KPI Globaux)
-- Destinée au Dashboard et aux commandes globales du bot
CREATE OR REPLACE VIEW v_analytics_kpis AS
SELECT 
    COUNT(*) as total_pokemon,
    ROUND(AVG(completeness_score), 2) as global_quality_rate,
    SUM(CASE WHEN has_official_artwork THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as artwork_coverage_pct,
    SUM(CASE WHEN file_count > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as storage_coverage_pct,
    COUNT(DISTINCT main_type) as distinct_types_count
FROM v_pokemon_quality;

-- 3. Vue de répartition par type
CREATE OR REPLACE VIEW v_type_distribution AS
SELECT 
    main_type, 
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pokemon), 2) as percentage
FROM pokemon
GROUP BY main_type
ORDER BY count DESC;

-- 4. Vue des éléments à corriger (Top 10 pires scores)
CREATE OR REPLACE VIEW v_missing_data_alerts AS
SELECT 
    pokemon_id, 
    pokemon_name, 
    quality_status, 
    completeness_score
FROM v_pokemon_quality
WHERE completeness_score < 100
ORDER BY completeness_score ASC
LIMIT 10;
