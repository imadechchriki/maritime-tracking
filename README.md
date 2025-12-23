# 🚢 Maritime Tracking System - Big Data Project

## 📋 Description du Projet

Système de suivi en temps réel d'une flotte maritime utilisant un pipeline Big Data complet. Ce projet démontre l'intégration de technologies distribuées pour l'ingestion, le traitement et l'analyse de données IoT.

### 🎯 Cas d'Usage

Suivi de navires commerciaux sur des routes maritimes méditerranéennes avec :
- **Télémétrie en temps réel** : Position GPS, vitesse, cap, consommation carburant
- **Alertes automatiques** : Carburant bas, anomalies moteur, conditions météo
- **Analyses prédictives** : ETA (Estimated Time of Arrival), maintenance prédictive
- **Optimisation de routes** : Analyse des performances par trajectoire

---

## 🏗️ Architecture du Pipeline

```
┌─────────────────┐
│  Générateur     │  Simulation de navires en Scala
│  Scala          │  (DataGenerator.scala)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Kafka          │  Ingestion temps réel
│  Producer       │  Topics: maritime-tracking, maritime-alerts
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Spark          │  Traitement streaming + batch
│  Streaming      │  - Agrégations fenêtrées (5 min)
│                 │  - Détection anomalies
│                 │  - Calcul ETA
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  HDFS           │  Stockage distribué
│                 │  - Données brutes (partitionnées)
│                 │  - Données agrégées
│                 │  - Analyses
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Impala/Hive    │  Requêtes SQL distribuées
│  + Spark SQL    │  - Tables partitionnées
│                 │  - Vues analytiques
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Visualisation  │  Jupyter Notebook
│                 │  - Cartes des trajectoires
│                 │  - Dashboards analytiques
└─────────────────┘
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

## 📦 Structure du Projet

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

### Étape 1 : Cloner et Configurer

```bash
# Cloner le projet
git clone <votre-repo>
cd maritime-tracking

# Rendre les scripts exécutables
chmod +x scripts/*.sh

# Lancer l'installation complète
./scripts/setup-and-run.sh
```

**Ce script va :**
- ✅ Démarrer tous les conteneurs Docker
- ✅ Créer les topics Kafka
- ✅ Initialiser les répertoires HDFS
- ✅ Configurer SBT

### Étape 2 : Compiler le Code Scala

```bash
cd scala-app
sbt clean compile assembly
cd ..
```

Cela crée le JAR : `MaritimeTracking-assembly-1.0.jar`

### Étape 3 : Lancer le Pipeline

#### 3.1 Démarrer le Producer Kafka

```bash
./scripts/run-producer.sh

# Avec paramètres personnalisés
KAFKA_BROKERS=localhost:9092 NUM_SHIPS=10 INTERVAL=5 ./scripts/run-producer.sh
```

Vous devriez voir :
```
🚢 Flotte créée:
  • SHIP_001: Tanger → Marseille (850 nm)
  • SHIP_002: Barcelona → Alger (320 nm)
  ...

✓ Sent: SHIP_001 to partition 0 at offset 123
⚠️  ALERTE: SHIP_003 - Carburant bas (9500L)
```

#### 3.2 Lancer Spark Streaming

```bash
# Dans un nouveau terminal
./scripts/run-streaming.sh
```

Accédez à l'UI Spark : http://localhost:4040

#### 3.3 Lancer l'Analyse Batch (après ~5 min de données)

```bash
./scripts/run-batch.sh
```

---

## 📊 Analyses Disponibles

### 1. Données Temps Réel (Spark Streaming)

- **Agrégations par fenêtre (5 min)** : Vitesse moyenne, consommation
- **Détection anomalies** : Carburant bas, vitesse anormale, problème moteur
- **Calcul ETA** : Estimation temps d'arrivée

**Localisation HDFS** :
```
/maritime/raw_data/         # Données brutes partitionnées
/maritime/aggregated/       # Agrégations 5 min
/maritime/anomalies/        # Alertes détectées
/maritime/eta_predictions/  # Prédictions ETA
```

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

## 🗄️ Requêtes SQL Impala/Hive

### Créer les Tables

```bash
# Copier le script SQL dans Hive
docker cp sql/create-tables.sql hive-metastore:/tmp/

# Exécuter
docker exec -it hive-metastore hive -f /tmp/create-tables.sql
```

### Exemples de Requêtes

```sql
-- Position actuelle de tous les navires
SELECT * FROM v_current_positions;

-- Navires nécessitant attention
SELECT * FROM v_ships_requiring_attention;

-- Top 10 routes les plus rapides
SELECT port_depart, port_arrivee, temps_estime_heures
FROM route_performance
ORDER BY temps_estime_heures ASC
LIMIT 10;

-- Navires en maintenance urgente
SELECT navire_id, score_risque, priorite_maintenance
FROM maintenance_prediction
WHERE priorite_maintenance = 'URGENT';

-- Distribution météo
SELECT meteo, occurrences, 
       ROUND(100.0 * occurrences / SUM(occurrences) OVER(), 2) as pourcentage
FROM weather_impact;
```

---

## 📈 Visualisation avec Jupyter

### Accéder à Jupyter

1. Ouvrir : http://localhost:8888
2. Token : visible dans `docker logs jupyter`

### Exemple de Notebook

```python
from pyspark.sql import SparkSession
import matplotlib.pyplot as plt
import pandas as pd

# Créer session Spark
spark = SparkSession.builder \
    .appName("MaritimeAnalysis") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .getOrCreate()

# Charger les statistiques des navires
df = spark.read.parquet("hdfs://namenode:9000/maritime/analysis/ship_statistics")

# Convertir en Pandas pour visualisation
pdf = df.toPandas()

# Graphique efficacité carburant
plt.figure(figsize=(12, 6))
plt.barh(pdf['navire_id'], pdf['efficacite_carburant_nm_per_litre'])
plt.xlabel('Efficacité (nm par litre)')
plt.ylabel('Navire')
plt.title('Efficacité Énergétique par Navire')
plt.tight_layout()
plt.show()

# Carte des trajectoires
import folium
from folium.plugins import HeatMap

# Charger positions
positions = spark.read.parquet("hdfs://namenode:9000/maritime/raw_data")
pos_pdf = positions.select("latitude", "longitude").toPandas()

# Créer carte centrée sur la Méditerranée
m = folium.Map(location=[37.0, 3.0], zoom_start=5)

# Ajouter heatmap des trajectoires
HeatMap(pos_pdf[['latitude', 'longitude']].values.tolist()).add_to(m)

m.save('maritime_heatmap.html')
```

---

## 🔍 Monitoring et Debugging

### Interfaces Web

| Service | URL | Description |
|---------|-----|-------------|
| Spark Master UI | http://localhost:8080 | État du cluster Spark |
| Spark Job UI | http://localhost:4040 | Jobs en cours d'exécution |
| HDFS NameNode | http://localhost:9870 | Exploration HDFS |
| Jupyter | http://localhost:8888 | Notebooks |

### Commandes Utiles

```bash
# Voir les logs d'un service
docker logs -f kafka
docker logs -f spark-master

# État des conteneurs
docker-compose ps

# Redémarrer un service
docker-compose restart spark-master

# Entrer dans un conteneur
docker exec -it spark-master bash

# Vérifier les topics Kafka
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Consommer un topic
docker exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic maritime-tracking \
    --from-beginning \
    --max-messages 10

# Explorer HDFS
docker exec namenode hdfs dfs -ls /maritime
docker exec namenode hdfs dfs -cat /maritime/raw_data/date=2025-12-22/*/part-00000*.parquet | head

# Vérifier l'espace HDFS
docker exec namenode hdfs dfsadmin -report
```

---

## 📝 Travail à Rendre

### Rapport (10-20 pages)

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

## ✅ Checklist Finale

Avant de rendre votre projet, vérifiez :

- [ ] Tous les services Docker démarrent correctement
- [ ] Le producer Kafka génère des données
- [ ] Spark Streaming traite les flux en temps réel
- [ ] Les données sont écrites dans HDFS (vérifier avec `hdfs dfs -ls`)
- [ ] L'analyse batch produit des résultats
- [ ] Les tables Impala/Hive sont créées
- [ ] Les requêtes SQL s'exécutent sans erreur
- [ ] Le rapport PDF est complet (10-20 pages)
- [ ] Le code est commenté et propre
- [ ] Les captures d'écran sont incluses
- [ ] Un README explique comment lancer le projet

---

**🚢 Bon courage pour votre projet Big Data !**