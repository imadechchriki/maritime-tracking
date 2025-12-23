#!/bin/bash

# ============================================
# Script pour lancer Spark Streaming
# ============================================

echo "============================================"
echo "⚡ Lancement de Spark Streaming"
echo "============================================"

# Paramètres par défaut
KAFKA_BROKERS="${KAFKA_BROKERS:-kafka:29092}"
HDFS_PATH="${HDFS_PATH:-hdfs://namenode:9000/maritime}"

echo "Configuration:"
echo "  • Kafka Brokers: $KAFKA_BROKERS"
echo "  • HDFS Path: $HDFS_PATH"
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

# Vérifier que le conteneur Spark est en cours d'exécution
echo "🔍 Vérification du conteneur Spark Master..."
if ! docker ps | grep -q spark-master; then
    echo "❌ Erreur: Le conteneur spark-master n'est pas en cours d'exécution"
    echo "💡 Lancez: docker-compose up -d"
    exit 1
fi

# Copier le JAR dans le conteneur Spark
echo "📦 Copie du JAR vers Spark Master..."
docker cp "$JAR_FILE" spark-master:/tmp/maritime.jar

# Soumettre le job Spark avec SPARK_HOME
echo "🚀 Soumission du job Spark Streaming..."
docker exec spark-master bash -c '
export SPARK_HOME=/opt/spark
$SPARK_HOME/bin/spark-submit \
    --class maritime.MaritimeSparkStreaming \
    --master spark://spark-master:7077 \
    --deploy-mode client \
    --driver-memory 2g \
    --executor-memory 2g \
    --executor-cores 2 \
    --total-executor-cores 2 \
    --conf spark.rpc.message.maxSize=256 \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
    /tmp/maritime.jar \
    '"$KAFKA_BROKERS"' \
    '"$HDFS_PATH"'
'

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Job Spark Streaming terminé avec succès"
    echo "📊 Consultez l'UI Spark: http://localhost:4040"
else
    echo "❌ Le job Spark a échoué avec le code: $EXIT_CODE"
    echo "💡 Vérifiez les logs avec: docker logs spark-master"
fi