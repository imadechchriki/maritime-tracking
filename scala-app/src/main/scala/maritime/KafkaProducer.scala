package maritime

import org.apache.kafka.clients.producer.{KafkaProducer, ProducerRecord, ProducerConfig}
import org.apache.kafka.common.serialization.StringSerializer
import java.util.Properties
import scala.util.{Try, Success, Failure}

/**
 * Producer Kafka pour envoyer les données maritimes
 */
object MaritimeKafkaProducer {
  
  val TOPIC_TRACKING = "maritime-tracking"
  val TOPIC_ALERTS = "maritime-alerts"
  
  /**
   * Crée un producer Kafka
   */
  def createProducer(brokers: String): KafkaProducer[String, String] = {
    val props = new Properties()
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, brokers)
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, classOf[StringSerializer].getName)
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, classOf[StringSerializer].getName)
    props.put(ProducerConfig.ACKS_CONFIG, "1")
    props.put(ProducerConfig.RETRIES_CONFIG, "3")
    props.put(ProducerConfig.LINGER_MS_CONFIG, "100")
    
    new KafkaProducer[String, String](props)
  }
  
  /**
   * Envoie une télémétrie vers Kafka
   */
  def sendTelemetry(
    producer: KafkaProducer[String, String],
    telemetry: ShipTelemetry
  ): Try[Unit] = {
    Try {
      val json = DataGenerator.toJson(telemetry)
      val record = new ProducerRecord[String, String](
        TOPIC_TRACKING,
        telemetry.navire_id,
        json
      )
      
      val metadata = producer.send(record).get()
      println(s"✓ Sent: ${telemetry.navire_id} to partition ${metadata.partition()} at offset ${metadata.offset()}")
      
      // Vérifier si c'est une alerte
      checkAndSendAlert(producer, telemetry)
    }
  }
  
  /**
   * Vérifie et envoie des alertes si nécessaire
   */
  private def checkAndSendAlert(
    producer: KafkaProducer[String, String],
    telemetry: ShipTelemetry
  ): Unit = {
    val alerts = scala.collection.mutable.ListBuffer[String]()
    
    // Alerte carburant bas
    if (telemetry.carburant_litres < 10000) {
      alerts += s"ALERTE: Carburant bas (${telemetry.carburant_litres.toInt}L)"
    }
    
    // Alerte tempête
    if (telemetry.meteo == "tempete") {
      alerts += "ALERTE: Navire dans une tempête"
    }
    
    // Alerte maintenance
    if (telemetry.etat_moteur == "maintenance_requise" || telemetry.etat_moteur == "surchauffe") {
      alerts += s"ALERTE: Moteur en état ${telemetry.etat_moteur}"
    }
    
    // Alerte vitesse anormale
    if (telemetry.vitesse_noeuds < 5.0) {
      alerts += s"ALERTE: Vitesse anormalement basse (${telemetry.vitesse_noeuds.toInt} nœuds)"
    }
    
    // Envoyer les alertes
    alerts.foreach { alert =>
      val alertJson = s"""{
        "navire_id": "${telemetry.navire_id}",
        "timestamp": "${telemetry.timestamp}",
        "type": "alert",
        "message": "$alert",
        "latitude": ${telemetry.latitude},
        "longitude": ${telemetry.longitude}
      }"""
      
      val record = new ProducerRecord[String, String](
        TOPIC_ALERTS,
        telemetry.navire_id,
        alertJson
      )
      
      producer.send(record)
      println(s"⚠️  ALERTE: ${telemetry.navire_id} - $alert")
    }
  }
  
  /**
   * Application principale - Simulation continue
   */
  def main(args: Array[String]): Unit = {
    val kafkaBrokers = if (args.length > 0) args(0) else "localhost:9092"
    val numberOfShips = if (args.length > 1) args(1).toInt else 5
    val intervalSeconds = if (args.length > 2) args(2).toInt else 10
    
    println(s"""
    |==========================================
    | 🚢 Maritime Tracking Producer
    |==========================================
    | Kafka Brokers: $kafkaBrokers
    | Nombre de navires: $numberOfShips
    | Intervalle: ${intervalSeconds}s
    |==========================================
    """.stripMargin)
    
    val producer = createProducer(kafkaBrokers)
    val fleet = DataGenerator.createFleet(numberOfShips)
    
    println("\n🚢 Flotte créée:")
    fleet.foreach { ship =>
      println(s"  • ${ship.navireId}: ${ship.portDepart} → ${ship.portArrivee} (${ship.distanceTotaleNm.toInt} nm)")
    }
    println()
    
    // Envoyer des données en continu
    try {
      var iteration = 1
      while (true) {
        println(s"\n--- Itération $iteration ---")
        
        fleet.foreach { ship =>
          val telemetry = DataGenerator.generateTelemetry(ship)
          sendTelemetry(producer, telemetry) match {
            case Success(_) => // OK
            case Failure(e) => println(s"✗ Erreur: ${e.getMessage}")
          }
        }
        
        iteration += 1
        Thread.sleep(intervalSeconds * 1000)
      }
    } catch {
      case _: InterruptedException =>
        println("\n🛑 Arrêt du producer...")
    } finally {
      producer.close()
      println("✓ Producer fermé")
    }
  }
}