# 🚢 Système de Suivi Maritime en Temps Réel - Projet Big Data

## 📋 Description du Projet

**Maritime Tracking System** est un système complet de suivi en temps réel d'une flotte maritime méditerranéenne utilisant un pipeline Big Data distribué et scalable. Ce projet démontre l'intégration de technologies modernes (Kafka, Spark, Hadoop, Impala) pour l'ingestion, le traitement en continu et l'analyse de données IoT provenant de navires commerciaux.

Ce système simule une flotte de navires en transit entre différents ports méditerranéens, génère des données de télémétrie en continu, les traite en temps réel, les stocke de manière distribuée et fournit des analyses approfondies pour l'optimisation des opérations maritimes.

---

## 🎯 Cas d'Usage et Objectifs

### Cas d'Usage Principal

Suivi de navires commerciaux (porte-conteneurs, pétroliers, vraquiers) sur des routes maritimes méditerranéennes avec monitoring en temps réel et analyses prédictives.

### Données Collectées

Chaque navire envoie des données de télémétrie incluant :

- **Position GPS** : Latitude, longitude, horodatage
- **Navigation** : Vitesse (nœuds), cap (0-360°), profondeur de l'eau
- **Propulsion** : Consommation carburant (litres), température moteur, RPM
- **Cargo** : Poids transporté, occupation des conteneurs
- **Conditions** : Météo, hauteur des vagues, direction du vent

### Objectifs Métier

1. **Monitoring en Temps Réel** : Suivi instantané de la position et de l'état de chaque navire
2. **Alertes Automatiques** : Carburant bas, anomalies moteur, vitesse anormale, dégradation météo
3. **Analyses Prédictives** : ETA (Estimated Time of Arrival), maintenance prédictive, score de risque
4. **Optimisation de Routes** : Analyse des performances par trajectoire, recommandations de routes optimales
5. **Reporting et Conformité** : Données historiques pour audits et conformité réglementaire

---

## 🏗️ Architecture du Pipeline

### Flux Général des Données

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MARITIME TRACKING SYSTEM                         │
└────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 1 : GÉNÉRATION DES DONNÉES (Scala)                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  DataGenerator.scala                                                    │
│  ├─ Simule N navires                                                    │
│  ├─ Génère positions GPS basées sur formule Haversine                   │
│  ├─ Calcule vitesse, cap, consommation carburant                        │
│  ├─ Génère anomalies aléatoires (carburant bas, moteur chaud)           │
│  └─ Format: JSON pour streaming                                         │
│                                                                          │
│  Navires simulés:                                                       │
│  • SHIP_001: Route Tanger → Marseille (850 nm) - Port type: Conteneurs │
│  • SHIP_002: Route Barcelona → Alger (320 nm)   - Port type: Pétrolier │
│  • SHIP_003: Route Athènes → Naples (550 nm)    - Port type: Vraquiers │
│  • ... (jusqu'à 20+ navires configurables)                             │
│                                                                          │
└────────┬─────────────────────────────────────────────────────────────────┘
         │ JSON Telemetry (ShipTelemetry case class)
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 2 : INGESTION TEMPS RÉEL (Kafka Producer)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  KafkaProducer.scala                                                    │
│  ├─ Brokers: localhost:9092                                             │
│  ├─ Topics:                                                             │
│  │  ├─ maritime-tracking (8 partitions)  : Tous les points de données   │
│  │  └─ maritime-alerts (4 partitions)    : Uniquement anomalies         │
│  ├─ Partitionnement: Par navire_id (key) pour ordre garanti             │
│  ├─ Débit: ~100-500 messages/seconde selon config                      │
│  └─ Sérialisation: JSON                                                 │
│                                                                          │
│  Exemple message:                                                       │
│  {                                                                       │
│    "navire_id": "SHIP_001",                                             │
│    "timestamp": "2025-12-25T14:32:45Z",                                 │
│    "latitude": 43.2965, "longitude": 5.3698,                            │
│    "vitesse_noeuds": 12.5, "cap_degres": 180.0,                         │
│    "carburant_litres": 45000,                                           │
│    "temperature_moteur_celsius": 78.5,                                  │
│    "anomalies": ["CARBURANT_BAS"]                                       │
│  }                                                                       │
│                                                                          │
└────────┬─────────────────────────────────────────────────────────────────┘
         │ Streaming Kafka Topic
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 3 : TRAITEMENT EN TEMPS RÉEL (Spark Streaming)                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SparkStreaming.scala                                                   │
│  ├─ Micro-batch interval: 2 secondes                                    │
│  ├─ Watermarking: Tolérance 10 minutes pour données tardives            │
│  │                                                                       │
│  ├─ Transformations:                                                    │
│  │  ├─ Parsing JSON → DataFrames                                        │
│  │  ├─ Détection anomalies:                                             │
│  │  │   • Carburant < 20% de capacité                                   │
│  │  │   • Température moteur > 85°C                                     │
│  │  │   • Vitesse anomale (< 2 ou > 25 nœuds)                          │
│  │  ├─ Agrégations fenêtrées (5 minutes):                               │
│  │  │   • Vitesse moyenne par navire                                    │
│  │  │   • Consommation carburant cumulative                             │
│  │  │   • Distance parcourue (Haversine)                                │
│  │  │   • ETA computation                                               │
│  │  └─ Calculs additionnels:                                            │
│  │      • Efficacité énergétique (nm par litre)                         │
│  │      • Score d'alerte global                                         │
│  │                                                                       │
│  └─ Output: Écriture partitionnée en Parquet                            │
│                                                                          │
│  3 flux de sortie:                                                      │
│  1. Maritime Raw Data    : Chaque point de données                      │
│  2. Maritime Aggregated  : Agrégations par fenêtre                      │
│  3. Maritime Anomalies   : Alertes et exceptions                        │
│                                                                          │
└────────┬─────────────────────────────────────────────────────────────────┘
         │ Parquet Files
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 4 : STOCKAGE DISTRIBUÉ (HDFS - Hadoop)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  NameNode: hdfs://namenode:9000                                         │
│  Replication Factor: 3 (tolérance 2 nœuds)                              │
│                                                                          │
│  Hiérarchie HDFS:                                                       │
│  /maritime/                                                             │
│  ├─ raw_data/                 : Données brutes temps réel               │
│  │  ├─ date=2025-12-25/                                                │
│  │  │  ├─ hour=14/                                                     │
│  │  │  │  └─ part-00000*.parquet                                        │
│  │  │  └─ hour=15/                                                     │
│  │  └─ ...                                                             │
│  ├─ aggregated/               : Agrégations 5 min                       │
│  │  ├─ date=2025-12-25/                                                │
│  │  │  ├─ navire_id=SHIP_001/                                           │
│  │  │  └─ navire_id=SHIP_002/                                           │
│  │  └─ ...                                                             │
│  ├─ anomalies/                : Alertes et exceptions                   │
│  │  └─ alertes-2025-12-25.parquet                                       │
│  ├─ eta_predictions/          : Prédictions d'arrivée                   │
│  │  └─ predictions-2025-12-25.parquet                                   │
│  └─ analysis/                 : Résultats analyses batch                │
│     ├─ ship_statistics/       : Stats par navire                        │
│     ├─ route_performance/     : Performance par route                   │
│     ├─ temporal_analysis/     : Évolution horaire                       │
│     ├─ weather_impact/        : Impact météo                            │
│     ├─ anomalies_detected/    : Historique anomalies                    │
│     └─ maintenance_prediction/: Score risque maintenance                │
│                                                                          │
│  Format: Parquet compressé (Snappy)                                     │
│  Partitionnement: date, navire_id, heure                                │
│  Volume: ~1-5 GB par jour selon débit                                   │
│                                                                          │
└────────┬─────────────────────────────────────────────────────────────────┘
         │ Spark SQL Queries
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 5 : REQUÊTES SQL DISTRIBUÉES (Impala/Hive)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Tables Externes (sur données Parquet HDFS):                            │
│  ├─ maritime_raw_data        : Flux brut de tous points                 │
│  ├─ maritime_aggregated      : Agrégations par navire/fenêtre           │
│  ├─ maritime_anomalies       : Historique alertes                       │
│  ├─ maritime_eta             : Prédictions arrivée                      │
│  └─ maritime_vessel_info     : Metadata navires                         │
│                                                                          │
│  Vues SQL (Materialized):                                               │
│  ├─ v_current_positions      : Dernière position connue par navire      │
│  ├─ v_active_alerts          : Alertes actuelles non résolues           │
│  ├─ v_ships_requiring_attention: Navires avec anomalies                 │
│  ├─ v_route_efficiency       : Efficacité énergétique par route         │
│  └─ v_maintenance_alerts     : Navires nécessitant maintenance          │
│                                                                          │
│  Performances:                                                          │
│  • Requêtes simples: < 500ms                                            │
│  • Agrégations complexes: < 5s                                          │
│  • Scan complet historique: < 30s                                       │
│                                                                          │
└────────┬─────────────────────────────────────────────────────────────────┘
         │ Pandas DataFrames
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 6 : VISUALISATION & REPORTING (Jupyter)                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  maritime_analysis.ipynb                                                │
│  ├─ Graphiques temps réel:                                              │
│  │  ├─ Cartes Folium des trajectoires                                   │
│  │  ├─ Heatmaps des zones de trafic                                     │
│  │  ├─ Cartes de chaleur consommation carburant                         │
│  │  └─ Timeline des anomalies détectées                                 │
│  │                                                                       │
│  ├─ Analyses statistiques:                                              │
│  │  ├─ Histogrammes vitesse/consommation                                │
│  │  ├─ Corrélations vitesse-consommation                                │
│  │  ├─ Distribution des anomalies par type                              │
│  │  └─ Box plots comparaison navires                                    │
│  │                                                                       │
│  ├─ Dashboards:                                                         │
│  │  ├─ Vue synthétique flotte (status par navire)                       │
│  │  ├─ Tableau bord opérations (alertes actives)                        │
│  │  ├─ KPIs clés (total distance, carburant consommé, etc)              │
│  │  └─ Tendances historiques                                            │
│  │                                                                       │
│  └─ Export résultats: PDF, PNG, CSV                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Flux Technologique Simplifié

```
Données Brutes → Kafka → Spark Streaming → HDFS → Impala/Spark SQL → Visualisation
   (IoT)       (Ingestion) (Traitement)    (Stockage) (Requêtes)      (Insights)
```

---

## 🛠️ Technologies Utilisées

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **Ingestion** | Kafka 3.5.0 | Message broker temps réel |
| **Traitement** | Spark 3.5.0 (Scala 2.12) | Streaming + Batch processing |
| **Stockage** | HDFS (Hadoop 3.2.1) | Système de fichiers distribué |
| **SQL** | Hive/Impala + Spark SQL | Requêtes sur données massives |
| **Orchestration** | Docker Compose | Gestion des conteneurs |
| **Visualisation** | Jupyter (PySpark) | Notebooks interactifs |

---


```
maritime-tracking/
├── docker-compose.yml          # Configuration des services
├── README.md                   # Ce fichier
│
├── scala-app/                  # Application Scala
│   ├── build.sbt              # Configuration SBT
│   ├── project/
│   │   ├── build.properties
│   │   └── plugins.sbt
│   └── src/main/scala/maritime/
│       ├── DataGenerator.scala      # Simulation navires
│       ├── KafkaProducer.scala      # Producer Kafka
│       ├── SparkStreaming.scala     # Traitement temps réel
│       └── SparkBatch.scala         # Analyses batch
│
├── scripts/                    # Scripts d'automatisation
│   ├── setup-and-run.sh       # Installation complète
│   ├── run-producer.sh        # Lancer le producer
│   ├── run-streaming.sh       # Lancer Spark Streaming
│   └── run-batch.sh           # Lancer analyses batch
│
├── sql/                        # Requêtes SQL
│   └── create-tables.sql      # Création tables Impala/Hive
│
├── notebooks/                  # Notebooks Jupyter
│   └── analysis.ipynb         # Analyses et visualisations
│
└── data/                       # Données de référence
    └── ports.json             # Coordonnées des ports
```

---

## 🚀 Installation et Démarrage

### Prérequis

- Docker & Docker Compose installés
- 16 GB RAM minimum
- 20 GB espace disque
- SBT 1.9+ (pour compiler Scala)


| Composant | Technologie | Version | Rôle |
|-----------|-------------|---------|------|
| **Langage de Programmation** | Scala | 2.12 | Code métier, simulations, traitement |
| **Streaming** | Apache Spark | 3.5.0 | Traitement temps réel et batch |
| **Message Broker** | Apache Kafka | 3.5.0 | Ingestion en temps réel, topics distribués |
| **Système Fichiers** | HDFS (Hadoop) | 3.2.1 | Stockage distribué, répliqué, fault-tolerant |
| **Requêtes SQL** | Impala + Hive | 2.5.6 | Requêtes SQL sur données massives |
| **Spark SQL** | Built-in | 3.5.0 | Requêtes SQL additionnelles |
| **Build Tool** | SBT | 1.9.2 | Compilation, gestion dépendances Scala |
| **Orchestration** | Docker Compose | 1.29+ | Déploiement services conteneurisés |
| **Visualisation** | Jupyter Notebook | 7.0+ | Analyses interactives en Python/PySpark |
| **Format Données** | Parquet | - | Compression, performance, schéma |
| **Sérialisation** | JSON | - | Messages Kafka |

---





### Fichiers Clés Détaillés

#### 1. **docker-compose.yml**
Services conteneurisés :
- **zookeeper** : Coordination Kafka
- **kafka** : 3 brokers (replication)
- **namenode** : HDFS NameNode
- **datanode** : HDFS DataNode (stockage)
- **spark-master** : Driver Spark
- **spark-worker** : Executors Spark
- **impala-server** : Moteur requêtes SQL
- **hive-metastore** : Metadata Hive
- **jupyter** : Notebooks interactifs

#### 2. **build.sbt**
```scala
name := "MaritimeTracking"
version := "1.0"
scalaVersion := "2.12.15"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % "3.5.0",
  "org.apache.spark" %% "spark-streaming" % "3.5.0",
  "org.apache.spark" %% "spark-sql" % "3.5.0",
  "org.apache.kafka" %% "kafka-clients" % "3.5.0",
  "com.google.code.gson" % "gson" % "2.10.1",
  "org.scalatest" %% "scalatest" % "3.2.15" % Test
)

assemblyMergeStrategy in assembly := {
  case "application.conf" => MergeStrategy.concat
  case _ => (assemblyMergeStrategy in assembly).value
}
```

---

## 🚀 Installation et Démarrage Détaillé

### Prérequis Système

- **Docker & Docker Compose** : v1.29+ (ou Docker Desktop)
- **Mémoire RAM** : 16 GB minimum (recommandé 24 GB)
- **Espace Disque** : 50 GB libres (données + images Docker)
- **CPU** : 4+ cores (8+ recommandé)
- **SBT** : 1.9+ (pour compilation Scala locale)
- **Java** : JDK 11+ (généralement fourni par Docker)
- **Git** : Pour clonage du repo
- **Système** : Linux, macOS ou Windows (avec WSL2 recommandé)

### Étape 1 : Configuration Initiale

#### 1.1 Cloner le Projet

```bash
# SSH (si configuré)
git clone git@github.com:your-repo/maritime-tracking.git

# HTTPS
git clone https://github.com/your-repo/maritime-tracking.git

cd maritime-tracking
```

#### 1.2 Rendre les Scripts Exécutables

```bash
chmod +x scripts/*.sh
```

#### 1.3 Vérifier Docker

```bash
docker --version      # v20.10+
docker-compose --version  # v1.29+
docker ps            # Vérifier accès Docker daemon
```

### Étape 2 : Démarrer l'Infrastructure Docker

```bash
# Lancer tous les services
./scripts/setup-and-run.sh

# OU manuellement:
docker-compose up -d

# Attendre 30-60 secondes pour démarrage complet
sleep 60

# Vérifier les services
docker-compose ps
```

Résultat attendu :
```
CONTAINER ID   IMAGE              STATUS
abc123def      confluentinc/cp-kafka         Up 5 minutes
def456ghi      bde2020/hadoop-namenode       Up 5 minutes
ghi789jkl      bde2020/spark-master          Up 5 minutes
jkl012mno      jupyter/pyspark-notebook      Up 5 minutes
...
```

### Étape 3 : Compiler le Code Scala

```bash
cd scala-app

# Compilation et création JAR
sbt clean compile assembly

# Cela crée: target/scala-2.12/MaritimeTracking-assembly-1.0.jar
# (~2-3 minutes)

cd ..
```

### Étape 4 : Lancer le Pipeline

#### 4.1 Démarrer le Producer Kafka

```bash
# Terminal 1 : Data Generation + Kafka Producer
NUM_SHIPS=10 INTERVAL=2 ./scripts/run-producer.sh
```

**Paramètres configurable** :
- `NUM_SHIPS` : Nombre de navires à simuler (défaut: 5)
- `INTERVAL` : Interval entre messages en secondes (défaut: 5)
- `KAFKA_BROKERS` : Adresse Kafka (défaut: localhost:9092)

**Sortie attendue** :
```
🚢 Maritime Data Producer
Initializing 10 ships...
├─ SHIP_001: Tanger → Marseille
├─ SHIP_002: Barcelona → Alger
├─ SHIP_003: Athènes → Naples
└─ ...

Starting data generation (interval: 2 seconds)...

✓ Message sent to maritime-tracking [SHIP_001]: offset=1234, partition=0
✓ Message sent to maritime-tracking [SHIP_002]: offset=1235, partition=1
⚠️  ALERT: SHIP_003 - Low Fuel! (9500L / 100000L capacity)
✓ Message sent to maritime-alerts [SHIP_003]: offset=456, partition=0

✓ Timestamp: 2025-12-25 14:32:45
...
```

#### 4.2 Démarrer Spark Streaming

Dans un **nouveau terminal** :

```bash
# Terminal 2 : Spark Streaming
./scripts/run-streaming.sh
```

**Sortie attendue** :
```
25/12/25 14:35:00 INFO SparkContext: Running Spark version 3.5.0
...
25/12/25 14:35:15 INFO StreamingContext: StreamingContext started
Processing batch at time ...
- Batch 001: 150 records processed (10 ships, 5 min window)
  • Aggregated data written to HDFS
  • Anomalies detected: 2 (SHIP_003: low fuel, SHIP_007: high temp)
  • Latency: 2.34 seconds
- Batch 002: 145 records processed
  ...
```

**Accéder aux UIs** :
- Spark Master: http://localhost:8080
- Spark Jobs: http://localhost:4040
- HDFS NameNode: http://localhost:9870

#### 4.3 Lancer les Analyses Batch

Après 5-10 minutes de données streaming :

```bash
# Terminal 3 : Spark Batch Analysis
./scripts/run-batch.sh
```

**Sortie attendue** :
```
Starting Spark Batch Analysis...
Loading data from HDFS...
├─ raw_data: 1250 records
├─ aggregated: 250 records
└─ anomalies: 15 records

Computing ship statistics...
├─ Ship efficiency calculation
├─ Route performance analysis
├─ Temporal patterns
└─ Maintenance risk scores

Writing results to HDFS...
✓ ship_statistics written
✓ route_performance written
✓ temporal_analysis written
✓ weather_impact written
✓ anomalies_detected written
✓ maintenance_prediction written

Analysis complete in 45.32 seconds
```

---

## 📊 Analyses et Résultats Détaillés

### 1. Données Temps Réel (Spark Streaming)

Traitement continu par micro-batch (2 secondes) :

#### 1.1 Agrégations Fenêtrées (5 minutes)

**Calculs par navire** :
- Vitesse moyenne (nœuds)
- Consommation carburant cumulative (litres)
- Distance parcourue (formule Haversine)
- Direction dominante
- Nombre d'anomalies détectées

**Stockage** :
```
hdfs://namenode:9000/maritime/aggregated/
├─ date=2025-12-25/
│  ├─ hour=14/
│  │  ├─ navire_id=SHIP_001/
│  │  │  └─ 14_30_00.parquet
│  │  ├─ navire_id=SHIP_002/
│  │  └─ ...
│  └─ hour=15/
└─ ...
```

#### 1.2 Détection Anomalies

Règles prédéfinies :
| Anomalie | Condition | Sévérité |
|----------|-----------|----------|
| `LOW_FUEL` | Carburant < 20% de capacité | 🟠 Moyen |
| `HIGH_TEMP` | Température moteur > 85°C | 🔴 Élevé |
| `ABNORMAL_SPEED` | Vitesse < 2 ou > 25 nœuds | 🟠 Moyen |
| `LOST_SIGNAL` | Pas de message depuis 5 min | 🔴 Élevé |
| `OFF_COURSE` | Déviation > 20° par rapport route | 🟡 Faible |

**Output** :
```
hdfs://namenode:9000/maritime/anomalies/
├─ alertes-2025-12-25.parquet
├─ alertes-2025-12-26.parquet
└─ ...
```

#### 1.3 Calcul ETA (Estimated Time of Arrival)

```
ETA = (Distance restante) / (Vitesse moyenne récente)
```

Intègre :
- Position actuelle vs port de destination
- Vitesse moyenne dernières 30 minutes
- Ajustements météo (ralentissement estimé)
- Buffers de sécurité (5-10%)

**Mis à jour** : Chaque 5 minutes

---

### 2. Analyses Batch (Spark SQL)


| Analyse | Description | Fichier |
|---------|-------------|---------|
| **ship_statistics** | Stats par navire (vitesse, consommation, efficacité) | `/maritime/analysis/ship_statistics` |
| **route_performance** | Performance par route (temps, distance, conso) | `/maritime/analysis/route_performance` |
| **temporal_analysis** | Évolution par heure de la journée | `/maritime/analysis/temporal_analysis` |
| **weather_impact** | Impact météo sur performance | `/maritime/analysis/weather_impact` |
| **anomalies_detected** | Historique des anomalies | `/maritime/analysis/anomalies_detected` |
| **maintenance_prediction** | Score de risque maintenance | `/maritime/analysis/maintenance_prediction` |

---

## 🗄️ Requêtes SQL - Impala/Hive

### Créer les Tables

```bash
# Copier script SQL dans conteneur Hive
docker cp sql/create-tables.sql hive-metastore:/tmp/

# Exécuter
docker exec -it hive-metastore beeline -f /tmp/create-tables.sql
```

### Création Tables Détaillée

#### Table Principale : maritime_raw_data

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS maritime_raw_data (
  timestamp STRING,
  navire_id STRING,
  latitude DOUBLE,
  longitude DOUBLE,
  vitesse_noeuds DOUBLE,
  cap_degres DOUBLE,
  carburant_litres DOUBLE,
  temperature_moteur_celsius DOUBLE,
  rpm_moteur INT,
  poids_cargo_tonnes INT,
  meteo STRING,
  anomalies ARRAY<STRING>
)
PARTITIONED BY (
  date_partition STRING,
  hour_partition INT
)
STORED AS PARQUET
LOCATION '/maritime/raw_data/'
TBLPROPERTIES ("classification"="parquet");
```

#### Vues Analytiques

```sql
-- Vue positions actuelles
CREATE VIEW v_current_positions AS
SELECT 
  navire_id,
  MAX(timestamp) as dernier_update,
  LAST(latitude) as latitude,
  LAST(longitude) as longitude,
  LAST(vitesse_noeuds) as vitesse_actuelle,
  LAST(carburant_litres) as carburant_actuel,
  LAST(temperature_moteur_celsius) as temp_actuelle
FROM maritime_raw_data
GROUP BY navire_id;

-- Vue navires en alerte
CREATE VIEW v_ships_requiring_attention AS
SELECT 
  navire_id,
  timestamp,
  anomalie,
  CASE 
    WHEN anomalie = 'LOW_FUEL' THEN 'Carburant critique'
    WHEN anomalie = 'HIGH_TEMP' THEN 'Moteur surchauffé'
    WHEN anomalie = 'ABNORMAL_SPEED' THEN 'Vitesse anormale'
    ELSE 'Autre anomalie'
  END as description
FROM maritime_anomalies
WHERE timestamp > DATE_SUB(NOW(), 1)
ORDER BY timestamp DESC;

-- Vue efficacité routes
CREATE VIEW v_route_efficiency AS
SELECT 
  port_depart,
  port_arrivee,
  AVG(distance_nm / NULLIF(carburant_consomme, 0)) as efficacite_moyenne,
  COUNT(*) as nb_traversees,
  AVG(temps_heures) as temps_moyen
FROM maritime_completed_routes
GROUP BY port_depart, port_arrivee;
```

### Requêtes Analytiques Courantes

#### 1. Suivi Flotte Temps Réel

```sql
-- Tous les navires et leur status
SELECT 
  navire_id,
  latitude,
  longitude,
  vitesse_noeuds,
  carburant_litres,
  temperature_moteur_celsius,
  CASE 
    WHEN carburant_litres < 20000 THEN 'CRITIQUE'
    WHEN carburant_litres < 40000 THEN 'BAS'
    ELSE 'OK'
  END as fuel_status,
  dernier_update
FROM v_current_positions
ORDER BY dernier_update DESC
LIMIT 50;
```

#### 2. Navires en Maintenance Urgente

```sql
SELECT 
  navire_id,
  COUNT(*) as anomalies_count,
  COLLECT_SET(anomalie) as types_anomalies,
  MAX(temperature_moteur_celsius) as temp_max_recente,
  AVG(rpm_moteur) as rpm_moyen
FROM maritime_raw_data
WHERE timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY navire_id
HAVING COUNT(*) > 5
ORDER BY anomalies_count DESC;
```

#### 3. Top 10 Routes Plus Rapides

```sql
SELECT 
  port_depart,
  port_arrivee,
  ROUND(AVG(distance_nm), 2) as distance_km,
  ROUND(AVG(temps_estime_heures), 2) as temps_moyen_heures,
  ROUND(AVG(vitesse_noeuds), 2) as vitesse_moyenne
FROM maritime_aggregated
WHERE port_depart IS NOT NULL AND port_arrivee IS NOT NULL
GROUP BY port_depart, port_arrivee
ORDER BY temps_estime_heures ASC
LIMIT 10;
```

#### 4. Consommation Carburant par Navire (Dernier 7 jours)

```sql
SELECT 
  navire_id,
  DATE(timestamp) as date_voyage,
  ROUND(SUM(carburant_consomme), 0) as total_litre,
  ROUND(SUM(distance_parcourue), 0) as distance_nm,
  ROUND(SUM(carburant_consomme) / SUM(distance_parcourue) * 100, 2) as litres_par_100nm
FROM maritime_raw_data
WHERE timestamp > DATE_SUB(NOW(), 7)
GROUP BY navire_id, DATE(timestamp)
ORDER BY navire_id, date_voyage;
```

#### 5. Distribution Anomalies par Type

```sql
SELECT 
  anomalie,
  COUNT(*) as occurrences,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pourcentage,
  COUNT(DISTINCT navire_id) as nb_navires_affectes
FROM maritime_anomalies
WHERE timestamp > DATE_SUB(NOW(), 30)
GROUP BY anomalie
ORDER BY occurrences DESC;
```

---

## 📈 Visualisation avec Jupyter

### Accès à Jupyter

```bash
# URL d'accès
open http://localhost:8888

# Token d'authentification (première connexion)
docker logs jupyter | grep token
```

### Exemple : Script Analyse Complète

```python
from pyspark.sql import SparkSession
import matplotlib.pyplot as plt
import pandas as pd
import folium
from folium.plugins import HeatMap, MarkerCluster
import numpy as np

# ============= 1. INITIALISER SPARK =============
spark = SparkSession.builder \
    .appName("MaritimeAnalysis") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .config("spark.sql.shuffle.partitions", "16") \
    .getOrCreate()

# ============= 2. CHARGER DONNÉES =============
# Données brutes
raw_df = spark.read.parquet("hdfs://namenode:9000/maritime/raw_data")

# Données agrégées
agg_df = spark.read.parquet("hdfs://namenode:9000/maritime/aggregated")

# Anomalies
alerts_df = spark.read.parquet("hdfs://namenode:9000/maritime/anomalies")

# ============= 3. STATISTIQUES DESCRIPTIVES =============
print("="*60)
print("STATISTIQUES FLOTTE")
print("="*60)

stats_df = raw_df.groupBy("navire_id").agg(
    F.count("*").alias("nb_records"),
    F.avg("vitesse_noeuds").alias("vitesse_moy"),
    F.max("temperature_moteur_celsius").alias("temp_max"),
    F.sum("carburant_consomme").alias("total_consomme")
)

stats_pdf = stats_df.toPandas()
print(stats_pdf.to_string())

# ============= 4. VISUALISATIONS =============

# 4.1 Efficacité Énergétique
fig, axes = plt.subplots(1, 2, figsize=(14, 6))

# Histogramme consommation
stats_pdf.plot(x='navire_id', y='total_consomme', kind='bar', ax=axes[0])
axes[0].set_title('Consommation Carburant par Navire (dernières 24h)')
axes[0].set_ylabel('Litres')
axes[0].set_xlabel('Navire')

# Scatter vitesse vs consommation
axes[1].scatter(stats_pdf['vitesse_moy'], stats_pdf['total_consomme'])
axes[1].set_title('Vitesse vs Consommation')
axes[1].set_xlabel('Vitesse Moyenne (nœuds)')
axes[1].set_ylabel('Consommation Totale (L)')

plt.tight_layout()
plt.savefig('/tmp/efficiency_analysis.png', dpi=100)
plt.show()

# 4.2 Carte Interactive des Trajectoires
# Charger positions recentes
positions_df = raw_df.select("latitude", "longitude", "navire_id", "timestamp") \
    .orderBy("timestamp", ascending=False) \
    .limit(1000)

positions_pdf = positions_df.toPandas()

# Créer carte Folium
m = folium.Map(
    location=[37.0, 3.0],  # Centre Méditerranée
    zoom_start=5,
    tiles='OpenStreetMap'
)

# Ajouter markers pour dernière position chaque navire
for ship_id in positions_pdf['navire_id'].unique():
    ship_data = positions_pdf[positions_pdf['navire_id'] == ship_id]
    last_pos = ship_data.iloc[0]
    
    folium.CircleMarker(
        location=[last_pos['latitude'], last_pos['longitude']],
        radius=8,
        popup=f"{ship_id}<br>{last_pos['timestamp']}",
        color='red',
        fill=True,
        fillColor='red'
    ).add_to(m)

# Ajouter heatmap trajectoires
HeatMap(
    positions_pdf[['latitude', 'longitude']].values.tolist(),
    radius=20,
    blur=25
).add_to(m)

m.save('/tmp/maritime_trajectories.html')
print("✓ Carte sauvegardée: /tmp/maritime_trajectories.html")

# 4.3 Timeline Anomalies
alerts_pdf = alerts_df.select(
    "timestamp", "navire_id", "anomalie", "severite"
).toPandas()

alerts_pdf['timestamp'] = pd.to_datetime(alerts_pdf['timestamp'])
alerts_by_hour = alerts_pdf.set_index('timestamp').resample('H').size()

fig, ax = plt.subplots(figsize=(14, 5))
alerts_by_hour.plot(kind='line', ax=ax, marker='o')
ax.set_title('Anomalies Détectées par Heure')
ax.set_ylabel('Nombre d\'anomalies')
ax.set_xlabel('Heure')
plt.tight_layout()
plt.savefig('/tmp/anomalies_timeline.png', dpi=100)
plt.show()

# ============= 5. EXPORT RÉSULTATS =============
# Exporter en CSV
stats_pdf.to_csv('/tmp/fleet_statistics.csv', index=False)
alerts_pdf.to_csv('/tmp/alerts_history.csv', index=False)

print("\n✓ Analyses complétées et exportées")
print("  - Fleet Statistics: /tmp/fleet_statistics.csv")
print("  - Alerts History: /tmp/alerts_history.csv")
print("  - Trajectories Map: /tmp/maritime_trajectories.html")
```

### Notebooks Disponibles

1. **maritime_analysis.py** (inclus)
   - Vue d'ensemble flotte
   - Analyses temporelles
   - Cartes trajectoires
   - Tableaux bord KPIs

2. **Notebooks personnalisés** à créer :
   - Prédictions maintenance ML
   - Optimisation routes IA
   - Alertes prédictives
   - Benchmarking navires


---

## 🔍 Monitoring et Debugging Détaillé

### Interfaces Web

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **Spark Master** | http://localhost:8080 | 8080 | État cluster, workers, applications |
| **Spark Job UI** | http://localhost:4040 | 4040 | Jobs en cours, stages, tasks |
| **HDFS NameNode** | http://localhost:9870 | 9870 | Exploration HDFS, fichiers, health |
| **Jupyter** | http://localhost:8888 | 8888 | Notebooks interactifs |
| **Kafka Manager** | http://localhost:9000 | 9000 | Gestion topics (optionnel) |
| **Impala** | localhost:21000 | 21000 | Shell requêtes (CLI) |

### Commandes Docker Utiles

#### Gestion Services

```bash
# Voir tous les conteneurs
docker-compose ps

# Voir logs en temps réel
docker-compose logs -f kafka        # Kafka
docker-compose logs -f spark-master # Spark
docker-compose logs -f jupyter      # Jupyter

# Redémarrer un service
docker-compose restart spark-master
docker-compose restart kafka

# Arrêter tous les services
docker-compose down

# Redémarrer complet
docker-compose down && docker-compose up -d
```

#### Accès Conteneurs

```bash
# Entrer dans un conteneur
docker exec -it spark-master bash
docker exec -it namenode bash
docker exec -it kafka bash

# Exécuter commande unique
docker exec spark-master spark-submit --version
docker exec namenode hdfs dfs -ls /
```

### Monitoring Kafka

```bash
# Lister tous les topics
docker exec kafka kafka-topics \
    --list \
    --bootstrap-server localhost:9092

# Détails d'un topic
docker exec kafka kafka-topics \
    --describe \
    --topic maritime-tracking \
    --bootstrap-server localhost:9092

# Consommer messages
docker exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic maritime-tracking \
    --from-beginning \
    --max-messages 100

# Consommer alerts seulement
docker exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic maritime-alerts \
    --from-beginning

# Vérifier lag consumer groups
docker exec kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --group maritime-streaming \
    --describe
```

### Monitoring HDFS

```bash
# Explorer hiérarchie
docker exec namenode hdfs dfs -ls -h /maritime

# Voir fichiers détaillé
docker exec namenode hdfs dfs -ls -R /maritime/raw_data

# Espace disque utilisé
docker exec namenode hdfs dfsadmin -report

# Santé cluster
docker exec namenode hdfs dfsadmin -report | grep "Name:"

# Permissions fichiers
docker exec namenode hdfs dfs -stat /maritime

# Copier fichier depuis HDFS
docker exec namenode hdfs dfs -cat /maritime/raw_data/part-*.parquet | head -c 1000

# Vérifier replication
docker exec namenode hdfs fsck /maritime -blocks -locations
```

### Monitoring Spark Streaming

```bash
# Voir jobs en cours
# → Aller à http://localhost:4040/jobs

# Logs détaillés streaming
docker logs -f spark-master | grep -i "batch\|processing\|trigger"

# Voir RDD stats
docker exec spark-master spark-shell <<EOF
val rdd = sc.textFile("hdfs://namenode:9000/maritime/raw_data")
println(rdd.count())
EOF
```

---

## 🛠️ Architecture Code Scala Détaillée

### DataGenerator.scala

**Responsabilité** : Simulation des navires

```scala
case class Port(name: String, latitude: Double, longitude: Double)

case class Ship(
  id: String,
  portDeparture: Port,
  portArrival: Port,
  capacity: Double = 100000  // litres carburant
)

case class ShipTelemetry(
  timestamp: String,
  navire_id: String,
  latitude: Double,
  longitude: Double,
  vitesse_noeuds: Double,
  cap_degres: Double,
  carburant_litres: Double,
  temperature_moteur_celsius: Double,
  rpm_moteur: Int,
  anomalies: List[String] = List()
)

object DataGenerator {
  def generateTelemetry(ship: Ship, step: Int): ShipTelemetry = {
    // Haversine distance calculation
    val distance = haversineDistance(
      ship.currentLat, ship.currentLong,
      ship.portArrival.latitude, ship.portArrival.longitude
    )
    
    // Simulation déplacement
    val newLat = ship.currentLat + (Random.nextDouble() - 0.5) * 0.01
    val newLong = ship.currentLong + (Random.nextDouble() - 0.5) * 0.01
    
    // Consommation carburant
    val consumption = vitesse_noeuds * 1.5 // litres par heure
    val newFuel = ship.currentFuel - consumption
    
    // Détection anomalies
    val anomalies = List(
      if (newFuel < 20000) Some("LOW_FUEL") else None,
      if (temperature > 85) Some("HIGH_TEMP") else None
    ).flatten
    
    ShipTelemetry(
      timestamp = System.currentTimeMillis(),
      navire_id = ship.id,
      latitude = newLat,
      longitude = newLong,
      vitesse_noeuds = Random.nextDouble() * 20,
      cap_degres = Random.nextDouble() * 360,
      carburant_litres = newFuel,
      temperature_moteur_celsius = 70 + Random.nextDouble() * 20,
      rpm_moteur = (1000 + Random.nextInt(2000)),
      anomalies = anomalies
    )
  }
  
  private def haversineDistance(
    lat1: Double, lon1: Double,
    lat2: Double, lon2: Double
  ): Double = {
    val R = 6371.0 // Rayon Terre km
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
            Math.sin(dLon/2) * Math.sin(dLon/2)
    val c = 2 * Math.asin(Math.sqrt(a))
    R * c * 0.539957 // Convertir en milles nautiques
  }
}
```

### KafkaProducer.scala

**Responsabilité** : Envoi messages Kafka

```scala
object KafkaProducer {
  def main(args: Array[String]): Unit = {
    val props = new Properties()
    props.put("bootstrap.servers", "localhost:9092")
    props.put("key.serializer", 
      "org.apache.kafka.common.serialization.StringSerializer")
    props.put("value.serializer",
      "org.apache.kafka.common.serialization.StringSerializer")
    
    val producer = new KafkaProducer[String, String](props)
    
    // Générer et envoyer
    for (i <- 1 to 1000) {
      val telemetry = DataGenerator.generateTelemetry(...)
      val json = serializeToJson(telemetry)
      
      // Topic : maritime-tracking ou maritime-alerts selon anomalies
      val topic = if (telemetry.anomalies.nonEmpty) 
        "maritime-alerts" else "maritime-tracking"
      
      val record = new ProducerRecord[String, String](
        topic,
        telemetry.navire_id,  // Key pour partitionnement
        json                  // Value
      )
      
      producer.send(record)
      Thread.sleep(5000)
    }
    
    producer.close()
  }
}
```

### SparkStreaming.scala

**Responsabilité** : Traitement temps réel

```scala
object SparkStreaming {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("MaritimeStreaming")
      .getOrCreate()
    
    // Lire depuis Kafka
    val kafkaDF = spark
      .readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "kafka:9092")
      .option("subscribe", "maritime-tracking")
      .option("startingOffsets", "latest")
      .load()
    
    // Parser JSON
    val schemaString = "timestamp STRING, navire_id STRING, latitude DOUBLE, ..."
    val schema = StructType.fromDDL(schemaString)
    
    val dataDF = kafkaDF
      .select(from_json(col("value"), schema) as "data")
      .select("data.*")
    
    // Agrégations fenêtrées 5 minutes
    val aggregations = dataDF
      .withWatermark("timestamp", "10 minutes")
      .groupBy(
        window(col("timestamp"), "5 minutes"),
        col("navire_id")
      )
      .agg(
        avg("vitesse_noeuds").as("vitesse_moyenne"),
        sum("carburant_consomme").as("carburant_cumul"),
        max("temperature_moteur_celsius").as("temp_max"),
        count("*").as("nb_records")
      )
    
    // Écrire HDFS
    aggregations
      .writeStream
      .format("parquet")
      .option("path", "hdfs://namenode:9000/maritime/aggregated")
      .option("checkpointLocation", "hdfs://namenode:9000/.checkpoint")
      .partitionBy("navire_id")
      .mode("append")
      .start()
      .awaitTermination()
  }
}
```

### SparkBatch.scala

**Responsabilité** : Analyses batch

```scala
object SparkBatch {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("MaritimeBatch")
      .getOrCreate()
    
    // Charger données HDFS
    val rawDF = spark.read.parquet(
      "hdfs://namenode:9000/maritime/raw_data/*"
    )
    
    // Statistiques navires
    val shipStats = rawDF
      .groupBy("navire_id")
      .agg(
        avg("vitesse_noeuds").as("vitesse_moy"),
        sum("carburant_consomme").as("consomme_total"),
        max("temperature_moteur_celsius").as("temp_max")
      )
    
    shipStats.write
      .mode("overwrite")
      .parquet("hdfs://namenode:9000/maritime/analysis/ship_statistics")
    
    // Performance routes
    val routePerf = rawDF
      .filter(col("port_depart").isNotNull)
      .groupBy("port_depart", "port_arrivee")
      .agg(
        avg("distance_nm").as("distance_moy"),
        avg("temps_heures").as("temps_moyen")
      )
      .orderBy("temps_moyen")
    
    routePerf.write
      .mode("overwrite")
      .parquet("hdfs://namenode:9000/maritime/analysis/route_performance")
  }
}
```

---

## 🎓 Points Clés pour Évaluation

#### Structure Recommandée

1. **Introduction**
   - Contexte du projet
   - Cas d'usage maritime
   - Objectifs

2. **Architecture**
   - Schéma du pipeline
   - Justification des choix technologiques
   - Flux de données

3. **Implémentation**
   - **Génération des données** (Scala)
     - Modèle de simulation
     - Formule Haversine pour calculs géographiques
   - **Kafka** : Configuration, topics, producer
   - **Spark Streaming** : Fenêtres de temps, watermarking
   - **HDFS** : Partitionnement, format Parquet
   - **Impala/Spark SQL** : Tables, vues, requêtes complexes

4. **Analyses et Résultats**
   - Statistiques descriptives
   - Visualisations (graphiques, cartes)
   - Insights métier

5. **Performances**
   - Throughput Kafka
   - Latence de traitement Spark
   - Scalabilité du système

6. **Conclusion**
   - Apprentissages
   - Limites du projet
   - Améliorations futures

### Code Source

Structure à inclure :
```
maritime-tracking-code/
├── docker-compose.yml
├── scala-app/
│   ├── build.sbt
│   └── src/main/scala/maritime/
├── scripts/
├── sql/
└── notebooks/
```

### Captures d'Écran

À inclure dans le rapport :
- ✅ Spark UI montrant les jobs en cours
- ✅ HDFS UI avec l'arborescence des fichiers
- ✅ Logs Kafka montrant les messages
- ✅ Résultats des requêtes SQL
- ✅ Graphiques de visualisation (Jupyter)
- ✅ Carte des trajectoires maritimes

---

## 🎓 Points Clés pour l'Évaluation

### Spark (RDD, DataFrame, Spark SQL, Streaming)

✅ **RDD** : Manipulation bas niveau dans `DataGenerator`  
✅ **DataFrame** : Transformations dans `SparkStreaming` et `SparkBatch`  
✅ **Spark SQL** : Requêtes complexes, agrégations, fenêtres  
✅ **Spark Streaming** : Traitement temps réel avec watermarking

### Scala

✅ **Classes case** : `Ship`, `ShipTelemetry`  
✅ **Pattern matching** : Gestion des anomalies  
✅ **Fonctions** : Haversine, calcul de cap  
✅ **Intégration Spark** : Code idiomatique Scala

### Kafka

✅ **Producer** : Envoi de messages JSON  
✅ **Topics** : `maritime-tracking`, `maritime-alerts`  
✅ **Consumer** : Spark Streaming lit depuis Kafka  
✅ **Partitionnement** : Par `navire_id`

### Impala/Hive

✅ **Tables externes** : Sur données Parquet HDFS  
✅ **Partitionnement** : Par date et navire_id  
✅ **Vues** : Positions actuelles, alertes, résumés  
✅ **Requêtes distribuées** : Agrégations complexes

### HDFS

✅ **Stockage distribué** : Réplication, tolérance aux pannes  
✅ **Organisation** : Hiérarchie `/maritime/raw_data/`, `/analysis/`  
✅ **Format** : Parquet pour compression et performance

### Outil Additionnel : Docker

✅ **Orchestration** : Docker Compose pour tous les services  
✅ **Networking** : Réseau `maritime-network`  
✅ **Volumes** : Persistance des données

---

## 🔧 Personnalisation et Extensions

### Ajouter Plus de Navires

```bash
NUM_SHIPS=20 ./scripts/run-producer.sh
```

### Modifier l'Intervalle de Génération

```bash
INTERVAL=5 ./scripts/run-producer.sh  # Toutes les 5 secondes
```

### Ajouter de Nouveaux Ports

Éditer `DataGenerator.scala` :

```scala
val ports = Map(
  "Tanger" -> (35.7595, -5.8340),
  "Marseille" -> (43.2965, 5.3698),
  "Athènes" -> (37.9838, 23.7275),  // Nouveau
  "Istamboul" -> (41.0082, 28.9784) // Nouveau
)
```

### Ajouter de Nouvelles Métriques

Dans `ShipTelemetry`, ajouter :

```scala
case class ShipTelemetry(
  // ... champs existants
  pression_atmospherique: Double,
  hauteur_vagues_metres: Double,
  direction_vent_degres: Double
)
```

---

## 🐛 Troubleshooting

### Problème : Kafka ne démarre pas

```bash
# Vérifier les logs
docker logs kafka

# Redémarrer Zookeeper puis Kafka
docker-compose restart zookeeper
sleep 10
docker-compose restart kafka
```

### Problème : HDFS "Safe Mode"

```bash
docker exec namenode hdfs dfsadmin -safemode leave
```

### Problème : Mémoire insuffisante Spark

Dans `docker-compose.yml`, augmenter :

```yaml
spark-master:
  environment:
    - SPARK_DRIVER_MEMORY=4G  # Au lieu de 2G
```

### Problème : Compilation Scala échoue

```bash
cd scala-app
rm -rf target project/target
sbt clean compile
```

---

## 📚 Ressources Complémentaires

### Documentation Officielle

- [Apache Spark](https://spark.apache.org/docs/latest/)
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Apache Hadoop](https://hadoop.apache.org/docs/current/)
- [Scala](https://docs.scala-lang.org/)

### Concepts Clés

- **Streaming** : Traitement de flux de données en temps réel
- **Partitionnement** : Division des données pour parallélisme
- **Watermarking** : Gestion des données en retard (late data)
- **Windowing** : Agrégations sur fenêtres de temps

---

## 👥 Auteur

**Projet Big Data / Data Engineering**  
Module : Big Data Ecosystem  
Technologies : Kafka, Spark, Scala, HDFS, Impala

---

## 📄 Licence

Projet académique - Utilisation libre pour apprentissage.

---

---

## 🎓 Points Clés pour Évaluation

### Spark (RDD, DataFrame, Spark SQL, Streaming)

#### RDD (Resilient Distributed Datasets)

✅ **Utilisation dans DataGenerator** :
- Création RDD navires parallélisés
- Transformations map/flatMap pour telemetry
- Persistence en cache pour réutilisation

```scala
val shipsRDD = sc.parallelize(ships).cache()
val telemetryRDD = shipsRDD.flatMap(ship => 
  (0 until 1000).map(i => generateTelemetry(ship, i))
)
```

#### DataFrames & Spark SQL

✅ **SparkStreaming & SparkBatch** :
- Parsing JSON → Structured Streaming DataFrame
- Agrégations window, groupBy, agg
- Optimisations Catalyst optimizer
- Partitionnement intelligent

```scala
val df = spark.read.json(jsonRDD)
df.createOrReplaceTempView("maritime_data")
spark.sql("SELECT navire_id, AVG(vitesse_noeuds) FROM maritime_data GROUP BY navire_id")
```

#### Spark SQL

✅ **Requêtes distribuées** :
- Joins multi-tables
- Window functions (ROW_NUMBER, LAG, LEAD)
- Agrégations complexes
- Optimisation query plans

```scala
df.filter(col("carburant_litres") < 20000)
  .groupBy("navire_id")
  .agg(count("*").as("nb_alerts"))
  .orderBy(desc("nb_alerts"))
```

#### Spark Streaming

✅ **Traitement temps réel** :
- Micro-batch processing (2 sec intervals)
- Windowed aggregations (5 min windows)
- Watermarking pour late data (10 min tolerance)
- Stateful operations (agregation state)

```scala
df.withWatermark("timestamp", "10 minutes")
  .groupBy(window(col("timestamp"), "5 minutes"), col("navire_id"))
  .agg(avg("vitesse_noeuds"))
```

### Scala

✅ **Concepts avancés** :
- **Case classes** : ShipTelemetry, Ship, Port
- **Pattern matching** : Détection anomalies (match/case)
- **Implicits & Type classes** : Sérialisation JSON
- **Higher-order functions** : map, filter, fold, foldLeft
- **Collections API** : List, Map, Set, Seq, Iterator
- **Functional programming** : Pure functions, composition, recursion
- **Option/Try/Either** : Error handling sans exceptions
- **For comprehensions** : Abstractions monadic

```scala
case class ShipTelemetry(...) // Case class
val telemetry = ShipTelemetry(...)
telemetry match {  // Pattern matching
  case ShipTelemetry(_, _, _, _, _, _, f, _, _, alerts) if f < 20000 =>
    println("Low fuel alert!")
  case _ => ()
}
```

### Kafka

✅ **Concepts clés** :
- **Producers** : DataGenerator → Topic maritime-tracking/maritime-alerts
- **Topics** : 2 topics (tracking + alerts), 8 + 4 partitions
- **Partitioning** : Par navire_id (key) → garantit ordre par navire
- **Consumers** : Spark Streaming Consumer Group
- **Replication Factor** : 1 (développement) à 3 (production)
- **Brokers** : Cluster Kafka haute disponibilité
- **Serialization** : JSON format messages

```
Producer (Ship Data) → [Topic: maritime-tracking] ← Spark Streaming Consumer
                      └─ 8 partitions (SHIP_001 → P0, SHIP_002 → P1, etc)
```

### Impala/Hive

✅ **Big Data SQL** :
- **External Tables** : Sur données Parquet HDFS
- **Partitioning** : Par date, heure, navire_id → Pruning automatique
- **Materialized Views** : v_current_positions, v_ships_requiring_attention
- **Distributed Queries** : Exécution parallèle sur cluster
- **Complex Joins** : Multi-table analytics, Self-joins
- **Window Functions** : ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD
- **Aggregations** : GROUP BY avec HAVING, SUM OVER, AVG OVER

```sql
SELECT 
  navire_id,
  timestamp,
  carburant_litres,
  LAG(carburant_litres) OVER (PARTITION BY navire_id ORDER BY timestamp) as prev_fuel
FROM maritime_raw_data
WHERE carburant_litres < LAG(carburant_litres) OVER (...)
```

### HDFS (Hadoop)

✅ **Distributed File System** :
- **NameNode** : Métadata, namespace management, file system hierarchy
- **DataNodes** : Stockage blocs (blocs 128/256 MB)
- **Replication** : Tolérance 2 nœuds défaillants (factor=3)
- **Rack-awareness** : Placement blocs racks différents
- **Partitioning Strategy** :
  ```
  /maritime/raw_data/date=2025-12-25/hour=14/ship_001/part-00000.parquet
  ```
  → Partition pruning sur date/hour/navire
- **Format** : Parquet compression (Snappy, LZO, GZIP)
- **Fault Tolerance** : Réplication automatique, heartbeat, re-replication
- **Data Locality** : Computation moves to data principle

### Docker & Orchestration

✅ **Containerization** :
- **docker-compose.yml** : Définit 9+ services et leur configuration
- **Networking** : Conteneurs communiquent via bridge network `maritime-network`
- **Volumes** : Persistance données (/data, /logs, /checkpoint)
- **Health checks** : Validation services prêts avant démarrage
- **Resource management** : Limites CPU/RAM par service
- **Logging** : Centralisé avec docker logs

---

## 🔧 Configuration et Personnalisation

### Augmenter Nombre de Navires

```bash
NUM_SHIPS=50 ./scripts/run-producer.sh
```

Modifie aussi `scala-app/src/main/scala/maritime/DataGenerator.scala` :

```scala
val ports = Map(
  "Tanger" -> (35.7595, -5.8340),
  "Marseille" -> (43.2965, 5.3698),
  "Valencia" -> (39.4699, -0.3763),
  "Barcelona" -> (41.3851, 2.1734),
  "Alger" -> (36.7372, 3.0588),
  "Athènes" -> (37.9838, 23.7275),
  "Istamboul" -> (41.0082, 28.9784),  // NOUVEAU
  "Naples" -> (40.8518, 14.2681),     // NOUVEAU
  "Palma" -> (39.5696, 2.6502)        // NOUVEAU
)
```

### Modifier Intervalle Génération Données

```bash
INTERVAL=2 ./scripts/run-producer.sh  # 2 secondes entre messages
INTERVAL=1 ./scripts/run-producer.sh  # 1 seconde (débit max)
```

### Ajouter Nouvelles Métriques

Dans `ShipTelemetry` :

```scala
case class ShipTelemetry(
  // ... existants ...
  pression_atmospherique_hpa: Double,
  hauteur_vagues_metres: Double,
  direction_vent_degres: Double,
  couvert_nuageux_percent: Int
)
```

Puis ajouter generation dans `DataGenerator`:

```scala
pression_atmospherique_hpa = 1013.25 + Random.nextGaussian() * 2,
hauteur_vagues_metres = 0.5 + Random.nextDouble() * 4,
direction_vent_degres = Random.nextDouble() * 360,
couvert_nuageux_percent = Random.nextInt(101)
```

### Augmenter Rétention HDFS

Modifier `docker-compose.yml` :

```yaml
namenode:
  environment:
    - HDFS_CONF_dfs_namenode_safemode_threshold_pct: 0.99
    - HDFS_CONF_dfs_replication: 2  # Au lieu de 3 si espace limité
```

---

## 🐛 Troubleshooting Avancé

### Problème : Kafka ne reçoit pas de messages

```bash
# Vérifier producer logs
docker logs -f spark-master | grep KafkaProducer

# Vérifier broker
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Vérifier topics existent
docker exec kafka kafka-topics \
    --create --if-not-exists \
    --bootstrap-server localhost:9092 \
    --topic maritime-tracking \
    --partitions 8 \
    --replication-factor 1

# Tester producer simple
docker exec kafka kafka-console-producer \
    --broker-list localhost:9092 \
    --topic maritime-tracking <<EOF
{"test": "message"}
EOF
```

### Problème : Spark Streaming plante

```bash
# Vérifier mémoire
docker stats spark-master

# Augmenter dans docker-compose.yml
spark-master:
  environment:
    - SPARK_DRIVER_MEMORY=4g     # Au lieu de 2g
    - SPARK_EXECUTOR_MEMORY=4g   # Au lieu de 2g

# Redémarrer
docker-compose restart spark-master
```

### Problème : HDFS "Safe Mode"

```bash
# Vérifier status
docker exec namenode hdfs dfsadmin -safemode get

# Quitter safe mode
docker exec namenode hdfs dfsadmin -safemode leave

# Vérifier health
docker exec namenode hdfs dfsadmin -report
```

### Problème : Mémoire cluster insuffisante

```bash
# Vérifier utilisation
docker stats

# Réduire batch size
# Dans docker-compose.yml
spark-worker:
  environment:
    - SPARK_EXECUTOR_CORES=1  # Au lieu de 2
    - SPARK_EXECUTOR_MEMORY=1g  # Au lieu de 2g

# Ou réduire NUM_SHIPS
NUM_SHIPS=5 ./scripts/run-producer.sh
```

### Problème : Requêtes SQL lentes

```bash
# Vérifier partitions
docker exec namenode hdfs dfs -ls -h /maritime/raw_data/

# Recréer tables avec meilleures partitions
# Dans sql/create-tables.sql :
PARTITIONED BY (
  date_partition STRING,
  hour_partition INT,
  navire_id STRING  # Ajouter partition
)

# Analyser query plan
spark-sql> EXPLAIN SELECT ... ;

# Augmenter parallel processes
# Dans docker-compose.yml
spark-master:
  environment:
    - SPARK_SQL_SHUFFLE_PARTITIONS: 32
```

---

## 📚 Ressources & Références

### Documentation Officielle

- **Apache Spark** : https://spark.apache.org/docs/latest/
- **Apache Kafka** : https://kafka.apache.org/documentation/
- **Apache Hadoop/HDFS** : https://hadoop.apache.org/docs/current/
- **Scala** : https://docs.scala-lang.org/
- **Impala** : https://impala.apache.org/
- **Folium Maps** : https://python-visualization.github.io/folium/

### Concepts à Maîtriser

| Concept | Description | Ressource |
|---------|-------------|-----------|
| **Streaming** | Traitement données temps réel | [Spark Streaming Guide](https://spark.apache.org/docs/latest/streaming-programming-guide.html) |
| **Window Functions** | Agrégations temporelles | [Spark Window Functions](https://spark.apache.org/docs/latest/sql-ref-window-functions.html) |
| **Watermarking** | Gestion données tardives | [Spark Watermarking](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html#handling-event-time-and-late-data) |
| **Partitioning** | Optimisation parallélisme | [HDFS Partitioning](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HdfsDesign.html) |
| **Haversine Formula** | Distance géographique | [Haversine Distance](https://en.wikipedia.org/wiki/Haversine_formula) |

### Tutoriels Recommandés

1. Introduction Spark Streaming (30 min)
2. Kafka Producer/Consumer Pattern (45 min)
3. HDFS Architecture & Best Practices (1 h)
4. Impala Query Optimization (1 h)
5. Scala for Big Data (2 h)

---

## 👥 Auteur et Contexte

**Projet Big Data / Data Engineering**  
**Module** : Big Data Ecosystem (Kafka, Spark, Scala, HDFS, Impala)  
**Date** : Décembre 2025  
**Technologies** : Kafka, Spark, Scala, HDFS, Impala, Docker, Jupyter

---

## 📄 Licence

Projet académique - Utilisation libre pour apprentissage et fin d'études.

---

## ✅ Checklist Finale

Avant de rendre votre projet, vérifiez :

- [ ] Tous les services Docker démarrent correctement (`docker-compose ps`)
- [ ] Le producer Kafka génère des données (vérifier topic avec kafka-console-consumer)
- [ ] Spark Streaming traite les flux en temps réel (Spark UI http://localhost:4040)
- [ ] Les données sont écrites dans HDFS (vérifier avec `hdfs dfs -ls /maritime`)
- [ ] L'analyse batch produit des résultats (vérifier `/maritime/analysis/`)
- [ ] Les tables Impala/Hive sont créées (exécuter `CREATE TABLE` scripts)
- [ ] Les requêtes SQL s'exécutent sans erreur (tester sur Impala shell)
- [ ] Le rapport documentation est complet (10-20 pages minimum)
- [ ] Le code est bien commenté et proprement formaté (indentation, noms explicites)
- [ ] Les captures d'écran sont incluses (Spark UI, HDFS, Kafka, Jupyter, Résultats SQL)
- [ ] Un README explique comment lancer le projet (celui-ci!)
- [ ] Le dépôt Git contient tous les fichiers nécessaires (pas de dossiers vides)
- [ ] Les scripts sont tous exécutables (`chmod +x scripts/*.sh`)
- [ ] La compilation Scala réussit sans erreurs (`sbt clean compile assembly`)
- [ ] Au moins 1000 enregistrements sont traités pour démonstration
- [ ] Les analyses batch produisent des résultats exploitables

---

## 🚀 Quick Start Guide

Pour démarrer rapidement :

```bash
# 1. Cloner et configuration
git clone <repo>
cd maritime-tracking
chmod +x scripts/*.sh

# 2. Démarrer infrastructure
docker-compose up -d
sleep 60

# 3. Compiler code Scala
cd scala-app && sbt clean compile assembly && cd ..

# 4. Lancer producer (Terminal 1)
NUM_SHIPS=10 INTERVAL=2 ./scripts/run-producer.sh

# 5. Lancer Spark Streaming (Terminal 2)
./scripts/run-streaming.sh

# 6. Lancer analyses batch (Terminal 3, après 5 min)
./scripts/run-batch.sh

# 7. Accéder visualisations
# - Spark: http://localhost:4040
# - HDFS: http://localhost:9870
# - Jupyter: http://localhost:8888
```

---

**🚢 Bon courage pour votre projet Big Data ! Consultez ce README pour tous les détails. Amusez-vous ! 🚀**