package maritime

import scala.util.Random
import java.time.{Instant, ZoneOffset}
import java.time.format.DateTimeFormatter
import org.json4s._
import org.json4s.jackson.Serialization
import org.json4s.jackson.Serialization.write

/**
 * Classe représentant un navire
 */
case class Ship(
  navireId: String,
  portDepart: String,
  portArrivee: String,
  var latitude: Double,
  var longitude: Double,
  var vitesseNoeuds: Double,
  var capDegres: Double,
  var carburantLitres: Double,
  distanceTotaleNm: Double
)

/**
 * Classe représentant une mesure télémétrique
 */
case class ShipTelemetry(
  navire_id: String,
  timestamp: String,
  latitude: Double,
  longitude: Double,
  vitesse_noeuds: Double,
  cap_degres: Double,
  carburant_litres: Double,
  temperature_eau_celsius: Double,
  meteo: String,
  etat_moteur: String,
  port_depart: String,
  port_arrivee: String,
  distance_restante_nm: Double,
  consommation_horaire_litres: Double
)

/**
 * Générateur de données maritimes
 */
object DataGenerator {
  
  implicit val formats: Formats = DefaultFormats
  private val random = new Random()
  
  // Ports maritimes (Latitude, Longitude)
  val ports = Map(
    "Tanger" -> (35.7595, -5.8340),
    "Marseille" -> (43.2965, 5.3698),
    "Barcelona" -> (41.3851, 2.1734),
    "Genova" -> (44.4056, 8.9463),
    "Valencia" -> (39.4699, -0.3763),
    "Alger" -> (36.7538, 3.0588),
    "Tunis" -> (36.8065, 10.1815),
    "Casablanca" -> (33.5731, -7.5898)
  )
  
  // Conditions météo
  val meteoConditions = Array("claire", "nuageux", "pluie_legere", "brouillard", "tempete")
  
  // États moteur
  val etatsMoteur = Array("normal", "maintenance_requise", "surchauffe", "optimal")
  
  /**
   * Crée une flotte de navires
   */
  def createFleet(numberOfShips: Int): List[Ship] = {
    val portNames = ports.keys.toList
    
    (1 to numberOfShips).map { i =>
      val departIndex = random.nextInt(portNames.length)
      var arriveeIndex = random.nextInt(portNames.length)
      
      // S'assurer que départ != arrivée
      while (arriveeIndex == departIndex) {
        arriveeIndex = random.nextInt(portNames.length)
      }
      
      val portDepart = portNames(departIndex)
      val portArrivee = portNames(arriveeIndex)
      
      val (latDepart, lonDepart) = ports(portDepart)
      val (latArrivee, lonArrivee) = ports(portArrivee)
      
      // Calcul distance (formule simplifiée)
      val distance = haversineDistance(latDepart, lonDepart, latArrivee, lonArrivee)
      
      Ship(
        navireId = f"SHIP_${i}%03d",
        portDepart = portDepart,
        portArrivee = portArrivee,
        latitude = latDepart,
        longitude = lonDepart,
        vitesseNoeuds = 15.0 + random.nextDouble() * 10.0, // 15-25 nœuds
        capDegres = calculateBearing(latDepart, lonDepart, latArrivee, lonArrivee),
        carburantLitres = 50000.0 + random.nextDouble() * 30000.0, // 50k-80k litres
        distanceTotaleNm = distance
      )
    }.toList
  }
  
  /**
   * Génère une télémétrie pour un navire
   */
  def generateTelemetry(ship: Ship): ShipTelemetry = {
    val now = Instant.now()
    val timestamp = DateTimeFormatter.ISO_INSTANT.format(now)
    
    // Simulation du mouvement (déplacement par heure)
    val distanceParcourue = ship.vitesseNoeuds * (1.0 / 60.0) // en 1 minute
    moveShip(ship, distanceParcourue)
    
    // Consommation carburant (litres/heure)
    val consommation = 10.0 + (ship.vitesseNoeuds * 2.5) + random.nextDouble() * 5.0
    ship.carburantLitres -= consommation / 60.0 // consommation par minute
    
    // Distance restante
    val (latArrivee, lonArrivee) = ports(ship.portArrivee)
    val distanceRestante = haversineDistance(
      ship.latitude, ship.longitude, 
      latArrivee, lonArrivee
    )
    
    // Température eau (variation saisonnière)
    val tempEau = 18.0 + random.nextDouble() * 8.0
    
    // Météo aléatoire (pondérée vers beau temps)
    val meteo = if (random.nextDouble() < 0.7) "claire" else meteoConditions(random.nextInt(meteoConditions.length))
    
    // État moteur (pondéré vers normal)
    val etatMoteur = if (random.nextDouble() < 0.85) "normal" else etatsMoteur(random.nextInt(etatsMoteur.length))
    
    ShipTelemetry(
      navire_id = ship.navireId,
      timestamp = timestamp,
      latitude = ship.latitude,
      longitude = ship.longitude,
      vitesse_noeuds = ship.vitesseNoeuds,
      cap_degres = ship.capDegres,
      carburant_litres = ship.carburantLitres,
      temperature_eau_celsius = tempEau,
      meteo = meteo,
      etat_moteur = etatMoteur,
      port_depart = ship.portDepart,
      port_arrivee = ship.portArrivee,
      distance_restante_nm = distanceRestante,
      consommation_horaire_litres = consommation
    )
  }
  
  /**
   * Déplace un navire selon sa vitesse et son cap
   */
  private def moveShip(ship: Ship, distanceNm: Double): Unit = {
    val R = 3440.065 // Rayon Terre en miles nautiques
    val bearing = Math.toRadians(ship.capDegres)
    val lat1 = Math.toRadians(ship.latitude)
    val lon1 = Math.toRadians(ship.longitude)
    
    val lat2 = Math.asin(
      Math.sin(lat1) * Math.cos(distanceNm / R) +
      Math.cos(lat1) * Math.sin(distanceNm / R) * Math.cos(bearing)
    )
    
    val lon2 = lon1 + Math.atan2(
      Math.sin(bearing) * Math.sin(distanceNm / R) * Math.cos(lat1),
      Math.cos(distanceNm / R) - Math.sin(lat1) * Math.sin(lat2)
    )
    
    ship.latitude = Math.toDegrees(lat2)
    ship.longitude = Math.toDegrees(lon2)
    
    // Variation légère de vitesse
    ship.vitesseNoeuds += (random.nextDouble() - 0.5) * 2.0
    ship.vitesseNoeuds = Math.max(10.0, Math.min(30.0, ship.vitesseNoeuds))
  }
  
  /**
   * Calcule la distance Haversine entre deux points (en miles nautiques)
   */
  def haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double = {
    val R = 3440.065 // Rayon Terre en miles nautiques
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    
    val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2)
    
    val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    R * c
  }
  
  /**
   * Calcule le cap initial entre deux points
   */
  def calculateBearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double = {
    val dLon = Math.toRadians(lon2 - lon1)
    val lat1Rad = Math.toRadians(lat1)
    val lat2Rad = Math.toRadians(lat2)
    
    val y = Math.sin(dLon) * Math.cos(lat2Rad)
    val x = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
            Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLon)
    
    val bearing = Math.toDegrees(Math.atan2(y, x))
    (bearing + 360) % 360
  }
  
  /**
   * Convertit une télémétrie en JSON
   */
  def toJson(telemetry: ShipTelemetry): String = {
    write(telemetry)
  }
}