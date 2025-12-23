#!/bin/bash

# ============================================
# Script pour lancer le Producer Kafka
# ============================================

echo "============================================"
echo "🚢 Lancement du Producer Kafka"
echo "============================================"

# Paramètres par défaut
KAFKA_BROKERS="${KAFKA_BROKERS:-localhost:9092}"
NUM_SHIPS="${NUM_SHIPS:-5}"
INTERVAL="${INTERVAL:-10}"

echo "Configuration:"
echo "  • Kafka Brokers: $KAFKA_BROKERS"
echo "  • Nombre de navires: $NUM_SHIPS"
echo "  • Intervalle: ${INTERVAL}s"
echo ""

# Compilation si nécessaire
JAR_FILE="scala-app/target/scala-2.12/maritime-tracking.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo "📦 Compilation du projet avec assembly..."
    cd scala-app
    sbt assembly
    cd ..
else
    echo "✅ JAR trouvé: $JAR_FILE"
fi

# Vérifier que le JAR existe
if [ ! -f "$JAR_FILE" ]; then
    echo "❌ Erreur: JAR non trouvé à $JAR_FILE"
    exit 1
fi

# Exécution
echo "🚀 Démarrage du producer..."
java -cp "$JAR_FILE" \
    maritime.MaritimeKafkaProducer \
    $KAFKA_BROKERS \
    $NUM_SHIPS \
    $INTERVAL