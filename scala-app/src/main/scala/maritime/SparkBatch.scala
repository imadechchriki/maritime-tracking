package maritime

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.expressions.Window

/**
 * Traitement Batch pour analyses historiques
 */
object MaritimeBatchAnalysis {
  
  def main(args: Array[String]): Unit = {
    val hdfsPath = if (args.length > 0) args(0) else "hdfs://namenode:9000/maritime"
    
    println(s"""
    |==========================================
    | 📊 Maritime Batch Analysis
    |==========================================
    | HDFS Path: $hdfsPath
    |==========================================
    """.stripMargin)
    
    val spark = SparkSession.builder()
      .appName("MaritimeBatchAnalysis")
      .config("spark.sql.adaptive.enabled", "true")
      .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
      .getOrCreate()
    
    import spark.implicits._
    
    try {
      // Lire les données brutes
      println("\n📖 Lecture des données brutes...")
      val rawData = spark.read
        .parquet(s"$hdfsPath/raw_data")
        .withColumn("timestamp_parsed", to_timestamp($"timestamp"))
        .cache()
      
      val totalRecords = rawData.count()
      println(s"✓ $totalRecords enregistrements chargés")
      
      if (totalRecords == 0) {
        println("⚠️  Aucune donnée trouvée. Assurez-vous que le streaming a bien écrit des données.")
        spark.stop()
        System.exit(0)
      }
      
      // === ANALYSE 1: Statistiques par navire ===
      println("\n🚢 Analyse 1: Statistiques par navire")
      
      val shipStats = rawData
        .groupBy("navire_id", "port_depart", "port_arrivee")
        .agg(
          count("*").as("nombre_mesures"),
          avg("vitesse_noeuds").as("vitesse_moyenne"),
          max("vitesse_noeuds").as("vitesse_max"),
          min("vitesse_noeuds").as("vitesse_min"),
          avg("consommation_horaire_litres").as("consommation_moyenne"),
          sum("consommation_horaire_litres").as("consommation_totale"),
          first("carburant_litres").as("carburant_initial"),
          last("carburant_litres").as("carburant_final"),
          max("distance_restante_nm").as("distance_debut"),
          min("distance_restante_nm").as("distance_min_restante")
        )
        .withColumn(
          "carburant_utilise",
          $"carburant_initial" - $"carburant_final"
        )
        .withColumn(
          "distance_parcourue",
          $"distance_debut" - $"distance_min_restante"
        )
        .withColumn(
          "efficacite_carburant_nm_per_litre",
          when($"carburant_utilise" > 0, 
            $"distance_parcourue" / $"carburant_utilise"
          ).otherwise(0)
        )
        .orderBy(desc("nombre_mesures"))
      
      shipStats.show(20, truncate = false)
      
      // Sauvegarder
      shipStats.write
        .mode("overwrite")
        .parquet(s"$hdfsPath/analysis/ship_statistics")
      
      // === ANALYSE 2: Performance par route ===
      println("\n🗺️  Analyse 2: Performance par route")
      val routePerformance = rawData
        .groupBy("port_depart", "port_arrivee")
        .agg(
          countDistinct("navire_id").as("nombre_navires"),
          avg("vitesse_noeuds").as("vitesse_moyenne_route"),
          avg("consommation_horaire_litres").as("consommation_moyenne_route"),
          avg("distance_restante_nm").as("distance_moyenne_route")
        )
        .withColumn(
          "temps_estime_heures",
          when($"vitesse_moyenne_route" > 0,
            $"distance_moyenne_route" / $"vitesse_moyenne_route"
          ).otherwise(0)
        )
        .orderBy(desc("nombre_navires"))
      
      routePerformance.show(20, truncate = false)
      
      routePerformance.write
        .mode("overwrite")
        .parquet(s"$hdfsPath/analysis/route_performance")
      
      // === ANALYSE 3: Évolution temporelle ===
      println("\n📈 Analyse 3: Évolution temporelle")
      val temporalAnalysis = rawData
        .withColumn("hour", hour($"timestamp_parsed"))
        .groupBy("date", "hour")
        .agg(
          countDistinct("navire_id").as("navires_actifs"),
          avg("vitesse_noeuds").as("vitesse_moyenne"),
          avg("consommation_horaire_litres").as("consommation_moyenne")
        )
        .orderBy("date", "hour")
      
      temporalAnalysis.show(24, truncate = false)
      
      temporalAnalysis.write
        .mode("overwrite")
        .partitionBy("date")
        .parquet(s"$hdfsPath/analysis/temporal_analysis")
      
      // === ANALYSE 4: Conditions météo ===
      println("\n🌤️  Analyse 4: Impact météo")
      val weatherImpact = rawData
        .groupBy("meteo")
        .agg(
          count("*").as("occurrences"),
          avg("vitesse_noeuds").as("vitesse_moyenne"),
          avg("consommation_horaire_litres").as("consommation_moyenne")
        )
        .orderBy(desc("occurrences"))
      
      weatherImpact.show(truncate = false)
      
      weatherImpact.write
        .mode("overwrite")
        .parquet(s"$hdfsPath/analysis/weather_impact")
      
      // === ANALYSE 5: Top navires par efficacité ===
      println("\n🏆 Analyse 5: Top navires par efficacité")
      val topShips = shipStats
        .filter($"carburant_utilise" > 0)
        .select(
          $"navire_id",
          $"port_depart",
          $"port_arrivee",
          $"vitesse_moyenne",
          $"consommation_moyenne",
          $"efficacite_carburant_nm_per_litre"
        )
        .orderBy(desc("efficacite_carburant_nm_per_litre"))
      
      println("\n✨ Navires les plus efficaces:")
      topShips.show(10, truncate = false)
      
      // === ANALYSE 6: Alertes et anomalies ===
      println("\n⚠️  Analyse 6: Anomalies détectées")
      val anomalies = rawData
        .filter(
          $"carburant_litres" < 10000 ||
          $"vitesse_noeuds" < 5.0 ||
          $"etat_moteur" =!= "normal"
        )
        .select(
          $"navire_id",
          $"timestamp_parsed".as("timestamp"),
          $"carburant_litres",
          $"vitesse_noeuds",
          $"etat_moteur",
          when($"carburant_litres" < 10000, "CARBURANT_BAS")
            .when($"vitesse_noeuds" < 5.0, "VITESSE_ANORMALE")
            .when($"etat_moteur" =!= "normal", "MOTEUR_PROBLEME")
            .as("type_anomalie")
        )
      
      val anomaliesSummary = anomalies
        .groupBy("navire_id", "type_anomalie")
        .agg(count("*").as("nombre_anomalies"))
        .orderBy(desc("nombre_anomalies"))
      
      anomaliesSummary.show(20, truncate = false)
      
      anomalies.write
        .mode("overwrite")
        .parquet(s"$hdfsPath/analysis/anomalies_detected")
      
      // === ANALYSE 7: Prédiction maintenance ===
      println("\n🔧 Analyse 7: Prédiction maintenance")
      val maintenancePrediction = rawData
        .groupBy("navire_id")
        .agg(
          avg("temperature_eau_celsius").as("temp_moyenne"),
          max("temperature_eau_celsius").as("temp_max"),
          sum(when($"etat_moteur" =!= "normal", 1).otherwise(0)).as("incidents_moteur"),
          last("carburant_litres").as("carburant_actuel")
        )
        .withColumn(
          "score_risque",
          (when($"temp_max" > 25, 1).otherwise(0) +
           when($"incidents_moteur" > 0, 2).otherwise(0) +
           when($"carburant_actuel" < 15000, 1).otherwise(0))
        )
        .withColumn(
          "priorite_maintenance",
          when($"score_risque" >= 3, "URGENT")
            .when($"score_risque" === 2, "MOYEN")
            .otherwise("BAS")
        )
        .orderBy(desc("score_risque"))
      
      maintenancePrediction.show(20, truncate = false)
      
      maintenancePrediction.write
        .mode("overwrite")
        .parquet(s"$hdfsPath/analysis/maintenance_prediction")
      
      println("\n" + "="*50)
      println("✅ Toutes les analyses terminées!")
      println("="*50)
      println(s"\nRésultats sauvegardés dans: $hdfsPath/analysis/")
      println("  • ship_statistics")
      println("  • route_performance")
      println("  • temporal_analysis")
      println("  • weather_impact")
      println("  • anomalies_detected")
      println("  • maintenance_prediction")
      
    } catch {
      case e: Exception =>
        println(s"\n❌ Erreur lors de l'analyse: ${e.getMessage}")
        e.printStackTrace()
        spark.stop()
        System.exit(1)
    }
    
    spark.stop()
  }
}