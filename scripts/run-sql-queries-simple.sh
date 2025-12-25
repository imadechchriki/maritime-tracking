#!/bin/bash

# ============================================
# Script SIMPLIFIÉ pour exécuter les requêtes SQL
# ============================================

echo "============================================"
echo "🗄️  Exécution des requêtes SQL avec Spark SQL"
echo "============================================"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HDFS_PATH="hdfs://namenode:9000/maritime"

echo "Configuration:"
echo "  • HDFS Path: $HDFS_PATH"
echo ""

# Vérifier Spark
if ! docker ps | grep -q spark-master; then
    echo "❌ Spark Master n'est pas en cours d'exécution"
    exit 1
fi

echo -e "${GREEN}✓ Spark Master actif${NC}"

# Créer le script Scala
echo -e "\n${BLUE}📝 Création du script SQL...${NC}"

cat > /tmp/maritime_sql.scala << 'EOFSCALA'
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._

object MaritimeSQLQueries {
  def main(args: Array[String]): Unit = {
    val hdfsPath = "hdfs://namenode:9000/maritime"
    
    println("\n" + "="*60)
    println("🚢 MARITIME TRACKING - ANALYSE SQL")
    println("="*60)
    
    val spark = SparkSession.builder()
      .appName("MaritimeSQLQueries")
      .config("spark.sql.adaptive.enabled", "true")
      .getOrCreate()
    
    import spark.implicits._
    
    try {
      println("\n📊 CHARGEMENT DES DONNÉES...")
      println("-" * 60)
      
      // Charger les tables d'analyse
      val shipStats = spark.read.parquet(s"$hdfsPath/analysis/ship_statistics")
      shipStats.createOrReplaceTempView("ship_statistics")
      println(f"✓ ship_statistics: ${shipStats.count()}%,d lignes")
      
      val routePerf = spark.read.parquet(s"$hdfsPath/analysis/route_performance")
      routePerf.createOrReplaceTempView("route_performance")
      println(f"✓ route_performance: ${routePerf.count()}%,d lignes")
      
      val weatherImpact = spark.read.parquet(s"$hdfsPath/analysis/weather_impact")
      weatherImpact.createOrReplaceTempView("weather_impact")
      println(f"✓ weather_impact: ${weatherImpact.count()}%,d lignes")
      
      val maintenance = spark.read.parquet(s"$hdfsPath/analysis/maintenance_prediction")
      maintenance.createOrReplaceTempView("maintenance_prediction")
      println(f"✓ maintenance_prediction: ${maintenance.count()}%,d lignes")
      
      val anomalies = spark.read.parquet(s"$hdfsPath/analysis/anomalies_detected")
      anomalies.createOrReplaceTempView("anomalies")
      println(f"✓ anomalies: ${anomalies.count()}%,d lignes")
      
      val rawData = spark.read.parquet(s"$hdfsPath/raw_data")
      rawData.createOrReplaceTempView("raw_telemetry")
      println(f"✓ raw_telemetry: ${rawData.count()}%,d lignes")
      
      val etaPred = spark.read.parquet(s"$hdfsPath/eta_predictions")
      etaPred.createOrReplaceTempView("eta_predictions")
      println(f"✓ eta_predictions: ${etaPred.count()}%,d lignes")
      
      // ========== REQUÊTES ==========
      
      println("\n" + "="*60)
      println("🔍 REQUÊTE 1: Top 10 Navires les Plus Rapides")
      println("="*60)
      spark.sql("""
        SELECT 
          navire_id,
          port_depart,
          port_arrivee,
          ROUND(vitesse_moyenne, 2) as vitesse_moy_noeuds,
          ROUND(efficacite_carburant_nm_per_litre, 3) as efficacite
        FROM ship_statistics
        ORDER BY vitesse_moyenne DESC
        LIMIT 10
      """).show(10, false)
      
      println("\n" + "="*60)
      println("🗺️  REQUÊTE 2: Routes les Plus Fréquentées")
      println("="*60)
      spark.sql("""
        SELECT 
          port_depart,
          port_arrivee,
          nombre_navires,
          ROUND(distance_moyenne_route, 1) as distance_nm,
          ROUND(temps_estime_heures, 1) as temps_h
        FROM route_performance
        ORDER BY nombre_navires DESC
        LIMIT 10
      """).show(10, false)
      
      println("\n" + "="*60)
      println("⚠️  REQUÊTE 3: Positions Actuelles - Navires à Surveiller")
      println("="*60)
      spark.sql("""
        SELECT 
          navire_id,
          ROUND(carburant_litres, 0) as carburant_L,
          ROUND(vitesse_noeuds, 1) as vitesse,
          etat_moteur,
          CASE 
            WHEN carburant_litres < 5000 THEN 'CRITIQUE'
            WHEN carburant_litres < 10000 THEN 'ATTENTION'
            ELSE 'OK'
          END as niveau_carburant
        FROM (
          SELECT *, ROW_NUMBER() OVER (PARTITION BY navire_id ORDER BY timestamp DESC) as rn
          FROM raw_telemetry
        ) t
        WHERE rn = 1 
          AND (carburant_litres < 10000 OR vitesse_noeuds < 5 OR etat_moteur != 'normal')
        ORDER BY carburant_litres ASC
        LIMIT 15
      """).show(15, false)
      
      println("\n" + "="*60)
      println("🔧 REQUÊTE 4: Maintenance Urgente")
      println("="*60)
      spark.sql("""
        SELECT 
          navire_id,
          score_risque,
          priorite_maintenance,
          ROUND(temp_max, 1) as temp_max_C,
          incidents_moteur,
          ROUND(carburant_actuel, 0) as carburant_L
        FROM maintenance_prediction
        WHERE priorite_maintenance = 'URGENT'
        ORDER BY score_risque DESC
      """).show(20, false)
      
      println("\n" + "="*60)
      println("🌤️  REQUÊTE 5: Impact Conditions Météo")
      println("="*60)
      spark.sql("""
        SELECT 
          meteo,
          occurrences,
          ROUND(100.0 * occurrences / SUM(occurrences) OVER(), 2) as pct,
          ROUND(vitesse_moyenne, 2) as vitesse_moy,
          ROUND(consommation_moyenne, 1) as conso_moy
        FROM weather_impact
        ORDER BY occurrences DESC
      """).show(false)
      
      println("\n" + "="*60)
      println("📈 REQUÊTE 6: Efficacité par Route")
      println("="*60)
      spark.sql("""
        SELECT 
          port_depart,
          port_arrivee,
          ROUND(distance_moyenne_route, 1) as dist_nm,
          ROUND(consommation_moyenne_route, 1) as conso_L_h,
          ROUND(distance_moyenne_route / consommation_moyenne_route, 3) as efficacite
        FROM route_performance
        ORDER BY efficacite DESC
        LIMIT 10
      """).show(10, false)
      
      println("\n" + "="*60)
      println("🚨 REQUÊTE 7: Analyse des Alertes")
      println("="*60)
      spark.sql("""
        SELECT 
          navire_id,
          COUNT(*) as total,
          SUM(CASE WHEN type_anomalie = 'CARBURANT_BAS' THEN 1 ELSE 0 END) as carburant,
          SUM(CASE WHEN type_anomalie = 'VITESSE_ANORMALE' THEN 1 ELSE 0 END) as vitesse,
          SUM(CASE WHEN type_anomalie = 'MOTEUR_ANOMALIE' THEN 1 ELSE 0 END) as moteur
        FROM anomalies
        GROUP BY navire_id
        ORDER BY total DESC
        LIMIT 15
      """).show(15, false)
      
      println("\n" + "="*60)
      println("⏱️  REQUÊTE 8: ETA - Prochains Arrivages")
      println("="*60)
      spark.sql("""
        SELECT 
          navire_id,
          port_arrivee,
          ROUND(distance_restante_nm, 1) as dist_nm,
          ROUND(eta_heures, 2) as eta_h,
          DATE_FORMAT(eta_timestamp, 'yyyy-MM-dd HH:mm') as arrivee
        FROM (
          SELECT *, ROW_NUMBER() OVER (PARTITION BY navire_id ORDER BY timestamp DESC) as rn
          FROM eta_predictions
        ) t
        WHERE rn = 1 AND eta_heures > 0
        ORDER BY eta_heures ASC
        LIMIT 15
      """).show(15, false)
      
      println("\n" + "="*60)
      println("📊 REQUÊTE 9: Vue d'Ensemble Flotte")
      println("="*60)
      spark.sql("""
        SELECT 
          COUNT(DISTINCT navire_id) as total_navires,
          ROUND(AVG(vitesse_noeuds), 2) as vitesse_moy,
          ROUND(AVG(carburant_litres), 0) as carburant_moy,
          SUM(CASE WHEN carburant_litres < 10000 THEN 1 ELSE 0 END) as alerte_carburant,
          SUM(CASE WHEN etat_moteur != 'normal' THEN 1 ELSE 0 END) as probleme_moteur
        FROM (
          SELECT *, ROW_NUMBER() OVER (PARTITION BY navire_id ORDER BY timestamp DESC) as rn
          FROM raw_telemetry
        ) t
        WHERE rn = 1
      """).show(false)
      
      println("\n" + "="*60)
      println("🏆 REQUÊTE 10: Classement des Navires")
      println("="*60)
      spark.sql("""
        SELECT 
          navire_id,
          ROUND(vitesse_moyenne, 2) as vitesse,
          ROUND(efficacite_carburant_nm_per_litre, 3) as efficacite,
          CASE 
            WHEN efficacite_carburant_nm_per_litre > 0.5 THEN 'Excellent'
            WHEN efficacite_carburant_nm_per_litre > 0.3 THEN 'Bon'
            WHEN efficacite_carburant_nm_per_litre > 0.1 THEN 'Acceptable'
            ELSE 'Problématique'
          END as performance
        FROM ship_statistics
        WHERE efficacite_carburant_nm_per_litre > 0
        ORDER BY efficacite_carburant_nm_per_litre DESC
        LIMIT 15
      """).show(15, false)
      
      println("\n" + "="*60)
      println("✅ TOUTES LES REQUÊTES EXÉCUTÉES AVEC SUCCÈS!")
      println("="*60)
      
    } catch {
      case e: Exception =>
        println(s"\n❌ ERREUR: ${e.getMessage}")
        e.printStackTrace()
        sys.exit(1)
    } finally {
      spark.stop()
    }
  }
}
EOFSCALA

echo -e "${GREEN}✓ Script créé${NC}"

# Copier dans le conteneur
docker cp /tmp/maritime_sql.scala spark-master:/tmp/

# Exécuter
echo -e "\n${BLUE}🚀 Exécution des requêtes...${NC}\n"

docker exec spark-master bash -c '
export SPARK_HOME=/opt/spark
$SPARK_HOME/bin/spark-shell \
  --master spark://spark-master:7077 \
  --deploy-mode client \
  --driver-memory 2g \
  --executor-memory 2g \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.rpc.message.maxSize=256 \
  -i /tmp/maritime_sql.scala \
  <<< "MaritimeSQLQueries.main(Array())"
'

EXIT_CODE=$?

rm /tmp/maritime_sql.scala 2>/dev/null || true

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Succès!${NC}"
else
    echo "❌ Échec (code $EXIT_CODE)"
    exit $EXIT_CODE
fi