#!/bin/bash

# ============================================
# Script pour lancer l'Analyse Batch
# ============================================

echo "============================================"
echo "📊 Lancement de l'Analyse Batch"
echo "============================================"

# Paramètres par défaut
HDFS_PATH="${HDFS_PATH:-hdfs://namenode:9000/maritime}"

echo "Configuration:"
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
echo "🚀 Soumission du job Spark Batch..."
docker exec spark-master bash -c '
export SPARK_HOME=/opt/spark
$SPARK_HOME/bin/spark-submit \
    --class maritime.MaritimeBatchAnalysis \
    --master spark://spark-master:7077 \
    --deploy-mode client \
    --driver-memory 2g \
    --executor-memory 2g \
    --executor-cores 2 \
    --total-executor-cores 2 \
    --conf spark.rpc.message.maxSize=512 \
    /tmp/maritime.jar \
    '"$HDFS_PATH"'
'

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Analyse batch terminée avec succès"
    echo "📁 Résultats dans: $HDFS_PATH/analysis/"
    echo ""
    echo "Pour voir les résultats:"
    echo "  docker exec namenode hdfs dfs -ls $HDFS_PATH/analysis/"
else
    echo "❌ Le job Spark a échoué avec le code: $EXIT_CODE"
    echo "💡 Vérifiez les logs avec: docker logs spark-master"
    exit $EXIT_CODE
fi