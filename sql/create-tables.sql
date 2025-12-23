-- ============================================
-- CRÉATION DES TABLES IMPALA/HIVE
-- Projet: Maritime Tracking System
-- ============================================

-- Base de données
CREATE DATABASE IF NOT EXISTS maritime;
USE maritime;

-- ============================================
-- TABLE 1: Données brutes télémétrie
-- ============================================
DROP TABLE IF EXISTS raw_telemetry;

CREATE EXTERNAL TABLE raw_telemetry (
    navire_id STRING,
    timestamp STRING,
    latitude DOUBLE,
    longitude DOUBLE,
    vitesse_noeuds DOUBLE,
    cap_degres DOUBLE,
    carburant_litres DOUBLE,
    temperature_eau_celsius DOUBLE,
    meteo STRING,
    etat_moteur STRING,
    port_depart STRING,
    port_arrivee STRING,
    distance_restante_nm DOUBLE,
    consommation_horaire_litres DOUBLE,
    processing_time TIMESTAMP,
    hour INT
)
PARTITIONED BY (date STRING)
STORED AS PARQUET
LOCATION '/maritime/raw_data';

-- Découvrir les partitions
MSCK REPAIR TABLE raw_telemetry;

-- ============================================
-- TABLE 2: Données agrégées (fenêtres 5 min)
-- ============================================
DROP TABLE IF EXISTS aggregated_metrics;

CREATE EXTERNAL TABLE aggregated_metrics (
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    navire_id STRING,
    port_depart STRING,
    port_arrivee STRING,
    vitesse_moyenne DOUBLE,
    vitesse_max DOUBLE,
    vitesse_min DOUBLE,
    carburant_moyen DOUBLE,
    consommation_moyenne DOUBLE,
    consommation_totale DOUBLE,
    nombre_mesures BIGINT,
    derniere_latitude DOUBLE,
    derniere_longitude DOUBLE,
    distance_restante DOUBLE
)
STORED AS PARQUET
LOCATION '/maritime/aggregated';

-- ============================================
-- TABLE 3: Anomalies détectées
-- ============================================
DROP TABLE IF EXISTS anomalies;

CREATE EXTERNAL TABLE anomalies (
    navire_id STRING,
    timestamp STRING,
    latitude DOUBLE,
    longitude DOUBLE,
    carburant_litres DOUBLE,
    vitesse_noeuds DOUBLE,
    etat_moteur STRING,
    type_anomalie STRING
)
STORED AS PARQUET
LOCATION '/maritime/anomalies';

-- ============================================
-- TABLE 4: Prédictions ETA
-- ============================================
DROP TABLE IF EXISTS eta_predictions;

CREATE EXTERNAL TABLE eta_predictions (
    navire_id STRING,
    timestamp STRING,
    port_arrivee STRING,
    distance_restante_nm DOUBLE,
    vitesse_noeuds DOUBLE,
    eta_heures DOUBLE,
    eta_timestamp TIMESTAMP
)
STORED AS PARQUET
LOCATION '/maritime/eta_predictions';

-- ============================================
-- TABLE 5: Statistiques par navire
-- ============================================
DROP TABLE IF EXISTS ship_statistics;

CREATE EXTERNAL TABLE ship_statistics (
    navire_id STRING,
    port_depart STRING,
    port_arrivee STRING,
    nombre_mesures BIGINT,
    vitesse_moyenne DOUBLE,
    vitesse_max DOUBLE,
    vitesse_min DOUBLE,
    consommation_moyenne DOUBLE,
    consommation_totale DOUBLE,
    carburant_initial DOUBLE,
    carburant_final DOUBLE,
    distance_min_restante DOUBLE,
    carburant_utilise DOUBLE,
    efficacite_carburant_nm_per_litre DOUBLE
)
STORED AS PARQUET
LOCATION '/maritime/analysis/ship_statistics';

-- ============================================
-- TABLE 6: Performance par route
-- ============================================
DROP TABLE IF EXISTS route_performance;

CREATE EXTERNAL TABLE route_performance (
    port_depart STRING,
    port_arrivee STRING,
    nombre_navires BIGINT,
    vitesse_moyenne_route DOUBLE,
    consommation_moyenne_route DOUBLE,
    distance_moyenne_route DOUBLE,
    temps_estime_heures DOUBLE
)
STORED AS PARQUET
LOCATION '/maritime/analysis/route_performance';

-- ============================================
-- TABLE 7: Analyse temporelle
-- ============================================
DROP TABLE IF EXISTS temporal_analysis;

CREATE EXTERNAL TABLE temporal_analysis (
    hour INT,
    navires_actifs BIGINT,
    vitesse_moyenne DOUBLE,
    consommation_moyenne DOUBLE
)
PARTITIONED BY (date STRING)
STORED AS PARQUET
LOCATION '/maritime/analysis/temporal_analysis';

MSCK REPAIR TABLE temporal_analysis;

-- ============================================
-- TABLE 8: Impact météo
-- ============================================
DROP TABLE IF EXISTS weather_impact;

CREATE EXTERNAL TABLE weather_impact (
    meteo STRING,
    occurrences BIGINT,
    vitesse_moyenne DOUBLE,
    consommation_moyenne DOUBLE
)
STORED AS PARQUET
LOCATION '/maritime/analysis/weather_impact';

-- ============================================
-- TABLE 9: Prédiction maintenance
-- ============================================
DROP TABLE IF EXISTS maintenance_prediction;

CREATE EXTERNAL TABLE maintenance_prediction (
    navire_id STRING,
    temp_moyenne DOUBLE,
    temp_max DOUBLE,
    incidents_moteur BIGINT,
    carburant_actuel DOUBLE,
    score_risque INT,
    priorite_maintenance STRING
)
STORED AS PARQUET
LOCATION '/maritime/analysis/maintenance_prediction';

-- ============================================
-- VUES ANALYTIQUES
-- ============================================

-- Vue: Position actuelle de tous les navires
CREATE VIEW IF NOT EXISTS v_current_positions AS
SELECT 
    t1.navire_id,
    t1.timestamp,
    t1.latitude,
    t1.longitude,
    t1.vitesse_noeuds,
    t1.port_depart,
    t1.port_arrivee,
    t1.distance_restante_nm,
    t1.carburant_litres,
    t1.etat_moteur
FROM raw_telemetry t1
INNER JOIN (
    SELECT navire_id, MAX(timestamp) as max_timestamp
    FROM raw_telemetry
    GROUP BY navire_id
) t2 ON t1.navire_id = t2.navire_id AND t1.timestamp = t2.max_timestamp;

-- Vue: Navires nécessitant attention
CREATE VIEW IF NOT EXISTS v_ships_requiring_attention AS
SELECT 
    navire_id,
    timestamp,
    carburant_litres,
    vitesse_noeuds,
    etat_moteur,
    CASE 
        WHEN carburant_litres < 5000 THEN 'CRITIQUE'
        WHEN carburant_litres < 10000 THEN 'ATTENTION'
        ELSE 'OK'
    END as niveau_carburant,
    CASE 
        WHEN vitesse_noeuds < 5 THEN 'PROBLEME'
        ELSE 'OK'
    END as statut_vitesse
FROM v_current_positions
WHERE carburant_litres < 10000 
   OR vitesse_noeuds < 5 
   OR etat_moteur != 'normal';

-- Vue: Résumé flotte par port
CREATE VIEW IF NOT EXISTS v_fleet_summary_by_port AS
SELECT 
    port_depart,
    port_arrivee,
    COUNT(DISTINCT navire_id) as nombre_navires,
    AVG(vitesse_noeuds) as vitesse_moyenne,
    AVG(distance_restante_nm) as distance_moyenne_restante,
    SUM(CASE WHEN carburant_litres < 10000 THEN 1 ELSE 0 END) as navires_carburant_bas
FROM v_current_positions
GROUP BY port_depart, port_arrivee;

-- ============================================
-- REQUÊTES D'EXEMPLE POUR LE RAPPORT
-- ============================================

-- Q1: Top 10 navires les plus rapides
SELECT navire_id, vitesse_moyenne, port_depart, port_arrivee
FROM ship_statistics
ORDER BY vitesse_moyenne DESC
LIMIT 10;

-- Q2: Routes les plus fréquentées
SELECT port_depart, port_arrivee, nombre_navires, temps_estime_heures
FROM route_performance
ORDER BY nombre_navires DESC
LIMIT 10;

-- Q3: Consommation moyenne par heure de la journée
SELECT hour, AVG(consommation_moyenne) as conso_avg
FROM temporal_analysis
GROUP BY hour
ORDER BY hour;

-- Q4: Navires en maintenance urgente
SELECT navire_id, score_risque, priorite_maintenance, carburant_actuel
FROM maintenance_prediction
WHERE priorite_maintenance = 'URGENT'
ORDER BY score_risque DESC;

-- Q5: Distribution des conditions météo
SELECT meteo, occurrences, 
       ROUND(occurrences * 100.0 / SUM(occurrences) OVER(), 2) as pourcentage
FROM weather_impact
ORDER BY occurrences DESC;

-- Q6: Efficacité énergétique par route
SELECT 
    rp.port_depart,
    rp.port_arrivee,
    rp.distance_moyenne_route,
    rp.consommation_moyenne_route,
    ROUND(rp.distance_moyenne_route / rp.consommation_moyenne_route, 2) as efficacite
FROM route_performance rp
ORDER BY efficacite DESC;

-- Q7: Analyse des alertes par navire
SELECT 
    navire_id,
    COUNT(*) as total_alertes,
    SUM(CASE WHEN type_anomalie = 'CARBURANT_BAS' THEN 1 ELSE 0 END) as alertes_carburant,
    SUM(CASE WHEN type_anomalie = 'VITESSE_ANORMALE' THEN 1 ELSE 0 END) as alertes_vitesse,
    SUM(CASE WHEN type_anomalie = 'MOTEUR_ANOMALIE' THEN 1 ELSE 0 END) as alertes_moteur
FROM anomalies
GROUP BY navire_id
ORDER BY total_alertes DESC;

-- ============================================
-- FIN DU SCRIPT
-- ============================================