package maritime

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import org.apache.spark.sql.streaming.Trigger

/**
 * Spark Streaming pour traiter les données maritimes en temps réel
 */
object MaritimeSparkStreaming {
  
  // Schéma des données télémétrie
  val telemetrySchema = StructType(Seq(
    StructField("navire_id", StringType, nullable = false),
    StructField("timestamp", StringType, nullable = false),
    StructField("latitude", DoubleType, nullable = false),
    StructField("longitude", DoubleType, nullable = false),
    StructField("vitesse_noeuds", DoubleType, nullable = false),
    StructField("cap_degres", DoubleType, nullable = false),
    StructField("carburant_litres", DoubleType, nullable = false),
    StructField("temperature_eau_celsius", DoubleType, nullable = false),
    StructField("meteo", StringType, nullable = false),
    StructField("etat_moteur", StringType, nullable = false),
    StructField("port_depart", StringType, nullable = false),
    StructField("port_arrivee", StringType, nullable = false),
    StructField("distance_restante_nm", DoubleType, nullable = false),
    StructField("consommation_horaire_litres", DoubleType, nullable = false)
  ))
  
  def main(args: Array[String]): Unit = {
    val kafkaBrokers = if (args.length > 0) args(0) else "kafka:29092"
    val hdfsPath = if (args.length > 1) args(1) else "hdfs://namenode:9000/maritime"
    
    println(s"""
    |==========================================
    | ⚡ Maritime Spark Streaming
    |==========================================
    | Kafka: $kafkaBrokers
    | HDFS: $hdfsPath
    |==========================================
    """.stripMargin)
    
    // Créer Spark Session
    val spark = SparkSession.builder()
      .appName("MaritimeStreaming")
      .config("spark.sql.streaming.schemaInference", "true")
      .config("spark.sql.shuffle.partitions", "4")
      .config("spark.sql.adaptive.enabled", "true")
      .getOrCreate()
    
    import spark.implicits._
    
    try {
      // Lire depuis Kafka
      val rawStream = spark.readStream
        .format("kafka")
        .option("kafka.bootstrap.servers", kafkaBrokers)
        .option("subscribe", "maritime-tracking")
        .option("startingOffsets", "latest")
        .option("failOnDataLoss", "false")
        .load()
      
      // Parser les données JSON
      val telemetryStream = rawStream
        .selectExpr("CAST(value AS STRING) as json")
        .select(from_json($"json", telemetrySchema).as("data"))
        .select("data.*")
        .withColumn("processing_time", current_timestamp())
        .withColumn("timestamp_parsed", to_timestamp($"timestamp"))
        .withColumn("date", to_date($"timestamp_parsed"))
        .withColumn("hour", hour($"timestamp_parsed"))
      
      // Afficher dans la console
      val consoleQuery = telemetryStream
        .writeStream
        .outputMode("append")
        .format("console")
        .option("truncate", false)
        .trigger(Trigger.ProcessingTime("30 seconds"))
        .queryName("console_output")
        .start()
      
      // Écrire les données brutes dans HDFS (partitionnées par date)
      val hdfsRawQuery = telemetryStream
        .writeStream
        .outputMode("append")
        .format("parquet")
        .option("path", s"$hdfsPath/raw_data")
        .option("checkpointLocation", s"$hdfsPath/checkpoints/raw")
        .partitionBy("date", "navire_id")
        .trigger(Trigger.ProcessingTime("1 minute"))
        .queryName("hdfs_raw")
        .start()
      
      // Calculer des agrégations par fenêtre de temps (5 minutes)
      val aggregatedStream = telemetryStream
        .withWatermark("processing_time", "10 minutes")
        .groupBy(
          window($"processing_time", "5 minutes"),
          $"navire_id",
          $"port_depart",
          $"port_arrivee"
        )
        .agg(
          avg("vitesse_noeuds").as("vitesse_moyenne"),
          max("vitesse_noeuds").as("vitesse_max"),
          min("vitesse_noeuds").as("vitesse_min"),
          avg("carburant_litres").as("carburant_moyen"),
          avg("consommation_horaire_litres").as("consommation_moyenne"),
          sum("consommation_horaire_litres").as("consommation_totale"),
          count("*").as("nombre_mesures"),
          last("latitude").as("derniere_latitude"),
          last("longitude").as("derniere_longitude"),
          last("distance_restante_nm").as("distance_restante")
        )
        .select(
          $"window.start".as("window_start"),
          $"window.end".as("window_end"),
          $"navire_id",
          $"port_depart",
          $"port_arrivee",
          $"vitesse_moyenne",
          $"vitesse_max",
          $"vitesse_min",
          $"carburant_moyen",
          $"consommation_moyenne",
          $"consommation_totale",
          $"nombre_mesures",
          $"derniere_latitude",
          $"derniere_longitude",
          $"distance_restante"
        )
      
      // Écrire les agrégations dans HDFS
      val hdfsAggQuery = aggregatedStream
        .writeStream
        .outputMode("append")
        .format("parquet")
        .option("path", s"$hdfsPath/aggregated")
        .option("checkpointLocation", s"$hdfsPath/checkpoints/agg")
        .trigger(Trigger.ProcessingTime("1 minute"))
        .queryName("hdfs_aggregated")
        .start()
      
      // Détecter les anomalies (carburant bas, vitesse anormale)
      val anomaliesStream = telemetryStream
        .filter(
          $"carburant_litres" < 10000 ||
          $"vitesse_noeuds" < 5.0 ||
          $"etat_moteur" =!= "normal"
        )
        .select(
          $"navire_id",
          $"timestamp_parsed",
          $"latitude",
          $"longitude",
          $"carburant_litres",
          $"vitesse_noeuds",
          $"etat_moteur",
          when($"carburant_litres" < 10000, "CARBURANT_BAS")
            .when($"vitesse_noeuds" < 5.0, "VITESSE_ANORMALE")
            .when($"etat_moteur" =!= "normal", "MOTEUR_ANOMALIE")
            .otherwise("AUTRE")
            .as("type_anomalie")
        )
      
      // Écrire les anomalies
      val anomaliesQuery = anomaliesStream
        .writeStream
        .outputMode("append")
        .format("parquet")
        .option("path", s"$hdfsPath/anomalies")
        .option("checkpointLocation", s"$hdfsPath/checkpoints/anomalies")
        .trigger(Trigger.ProcessingTime("30 seconds"))
        .queryName("anomalies")
        .start()
      
      // Calcul ETA (Estimated Time of Arrival) - CORRIGÉ
      val etaStream = telemetryStream
        .filter($"distance_restante_nm" > 0 && $"vitesse_noeuds" > 0)
        .withColumn(
          "eta_heures",
          $"distance_restante_nm" / $"vitesse_noeuds"
        )
        .withColumn(
          "eta_secondes",
          ($"eta_heures" * 3600).cast("long")
        )
        .withColumn(
          "eta_timestamp",
          from_unixtime(unix_timestamp($"timestamp_parsed") + $"eta_secondes")
        )
        .select(
          $"navire_id",
          $"timestamp_parsed".as("timestamp"),
          $"port_arrivee",
          $"distance_restante_nm",
          $"vitesse_noeuds",
          $"eta_heures",
          $"eta_timestamp"
        )
      
      val etaQuery = etaStream
        .writeStream
        .outputMode("append")
        .format("parquet")
        .option("path", s"$hdfsPath/eta_predictions")
        .option("checkpointLocation", s"$hdfsPath/checkpoints/eta")
        .trigger(Trigger.ProcessingTime("1 minute"))
        .queryName("eta_predictions")
        .start()
      
      println("\n✓ Tous les streams démarrés!")
      println("  • Console output: Données brutes")
      println(s"  • HDFS raw: $hdfsPath/raw_data")
      println(s"  • HDFS aggregated: $hdfsPath/aggregated")
      println(s"  • HDFS anomalies: $hdfsPath/anomalies")
      println(s"  • HDFS ETA: $hdfsPath/eta_predictions")
      println("\nAppuyez sur Ctrl+C pour arrêter...\n")
      
      // Attendre la fin
      spark.streams.awaitAnyTermination()
      
    } catch {
      case e: Exception =>
        println(s"\n❌ Erreur lors du traitement: ${e.getMessage}")
        e.printStackTrace()
        spark.stop()
        System.exit(1)
    }
  }
}