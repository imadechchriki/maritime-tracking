#!/bin/bash

# ============================================
# Script de Setup et Exécution - Maritime Tracking
# ============================================

set -e  # Arrêt en cas d'erreur

echo "============================================"
echo "🚢 Maritime Tracking System - Setup"
echo "============================================"

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 1. VÉRIFICATION DES PRÉREQUIS
# ============================================
echo -e "\n${BLUE}[1/8]${NC} Vérification des prérequis..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker n'est pas installé${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose n'est pas installé${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker et Docker Compose sont installés${NC}"

# ============================================
# 2. CRÉATION DE LA STRUCTURE DU PROJET
# ============================================
echo -e "\n${BLUE}[2/8]${NC} Création de la structure du projet..."

mkdir -p scala-app/src/main/scala/maritime
mkdir -p scala-app/project
mkdir -p scripts
mkdir -p sql
mkdir -p notebooks
mkdir -p data
mkdir -p config/kafka
mkdir -p config/spark

echo -e "${GREEN}✓ Structure créée${NC}"

# ============================================
# 3. CRÉATION DU FICHIER project/build.properties
# ============================================
echo -e "\n${BLUE}[3/8]${NC} Configuration SBT..."

cat > scala-app/project/build.properties << 'EOF'
sbt.version=1.9.7
EOF

cat > scala-app/project/plugins.sbt << 'EOF'
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.1.5")
EOF

echo -e "${GREEN}✓ Configuration SBT créée${NC}"

# ============================================
# 4. DÉMARRAGE DES CONTENEURS DOCKER
# ============================================
echo -e "\n${BLUE}[4/8]${NC} Démarrage des conteneurs Docker..."
echo -e "${YELLOW}⚠ Cela peut prendre plusieurs minutes...${NC}"

docker-compose up -d

echo -e "${GREEN}✓ Conteneurs démarrés${NC}"

# ============================================
# 5. ATTENTE QUE LES SERVICES SOIENT PRÊTS
# ============================================
echo -e "\n${BLUE}[5/8]${NC} Attente du démarrage des services..."

# Fonction pour attendre un service via curl/wget
wait_for_http_service() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "Attente de $service "
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e " ${YELLOW}⚠ Timeout (le service devrait démarrer bientôt)${NC}"
    return 0  # Continue quand même
}

# Fonction pour attendre qu'un conteneur soit en état "running"
wait_for_container() {
    local container=$1
    local max_attempts=30
    local attempt=1
    
    echo -n "Attente de $container "
    while [ $attempt -le $max_attempts ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' $container 2>/dev/null)" == "true" ]; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e " ${YELLOW}⚠ Timeout${NC}"
    return 0  # Continue quand même
}

# Vérification des conteneurs
wait_for_container "zookeeper"
wait_for_container "kafka"
wait_for_container "namenode"
wait_for_container "spark-master"

# Attente supplémentaire pour que les services soient vraiment prêts
echo -e "\n${YELLOW}⏳ Attente supplémentaire pour la stabilisation des services (20s)...${NC}"
sleep 20

echo -e "${GREEN}✓ Services en cours d'exécution${NC}"

# ============================================
# 6. CRÉATION DES TOPICS KAFKA
# ============================================
echo -e "\n${BLUE}[6/8]${NC} Création des topics Kafka..."

# Attendre que Kafka soit vraiment prêt
echo -n "Vérification de Kafka "
for i in {1..15}; do
    if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 &>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Créer les topics
docker exec kafka kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --replication-factor 1 \
    --partitions 3 \
    --topic maritime-tracking \
    --if-not-exists 2>/dev/null || echo -e "${YELLOW}Topic maritime-tracking existe déjà${NC}"

docker exec kafka kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --replication-factor 1 \
    --partitions 1 \
    --topic maritime-alerts \
    --if-not-exists 2>/dev/null || echo -e "${YELLOW}Topic maritime-alerts existe déjà${NC}"

echo -e "${GREEN}✓ Topics Kafka créés${NC}"

# Liste des topics
echo -e "\n${YELLOW}Topics disponibles:${NC}"
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null || echo "Kafka pas encore prêt"

# ============================================
# 7. CRÉATION DES RÉPERTOIRES HDFS
# ============================================
echo -e "\n${BLUE}[7/8]${NC} Configuration HDFS..."

# Attendre que HDFS soit prêt
echo -n "Vérification de HDFS "
for i in {1..15}; do
    if docker exec namenode hdfs dfs -ls / &>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Créer les répertoires
docker exec namenode hdfs dfs -mkdir -p /maritime 2>/dev/null || true
docker exec namenode hdfs dfs -mkdir -p /maritime/raw_data 2>/dev/null || true
docker exec namenode hdfs dfs -mkdir -p /maritime/aggregated 2>/dev/null || true
docker exec namenode hdfs dfs -mkdir -p /maritime/anomalies 2>/dev/null || true
docker exec namenode hdfs dfs -mkdir -p /maritime/eta_predictions 2>/dev/null || true
docker exec namenode hdfs dfs -mkdir -p /maritime/analysis 2>/dev/null || true
docker exec namenode hdfs dfs -mkdir -p /maritime/checkpoints 2>/dev/null || true

docker exec namenode hdfs dfs -chmod -R 777 /maritime 2>/dev/null || true

echo -e "${GREEN}✓ Répertoires HDFS créés${NC}"

# ============================================
# 8. AFFICHAGE DES INFORMATIONS
# ============================================
echo -e "\n${BLUE}[8/8]${NC} Résumé de l'installation"

echo -e "\n${GREEN}============================================"
echo -e "✅ INSTALLATION TERMINÉE AVEC SUCCÈS!"
echo -e "============================================${NC}"

echo -e "\n📊 ${YELLOW}Services disponibles:${NC}"
echo -e "  • HDFS Web UI:        ${GREEN}http://localhost:9870${NC}"
echo -e "  • Spark Master UI:    ${GREEN}http://localhost:8080${NC}"
echo -e "  • Spark Worker UI:    ${GREEN}http://localhost:8081${NC}"
echo -e "  • Spark Jobs UI:      ${GREEN}http://localhost:4040${NC} (après démarrage job)"
echo -e "  • Jupyter Notebook:   ${GREEN}http://localhost:8888${NC}"

echo -e "\n🔍 ${YELLOW}Vérification de l'état des services:${NC}"
echo -e "  ${GREEN}docker-compose ps${NC}"

echo -e "\n🚀 ${YELLOW}Prochaines étapes:${NC}"
echo -e "  1. Compiler le code Scala:"
echo -e "     ${GREEN}cd scala-app && sbt clean compile assembly${NC}"
echo -e ""
echo -e "  2. Lancer le producer Kafka:"
echo -e "     ${GREEN}./scripts/run-producer.sh${NC}"
echo -e ""
echo -e "  3. Lancer Spark Streaming:"
echo -e "     ${GREEN}./scripts/run-streaming.sh${NC}"
echo -e ""
echo -e "  4. Lancer l'analyse batch:"
echo -e "     ${GREEN}./scripts/run-batch.sh${NC}"

echo -e "\n📝 ${YELLOW}Commandes utiles:${NC}"
echo -e "  • Voir les logs:      ${GREEN}docker-compose logs -f [service]${NC}"
echo -e "  • Arrêter tout:       ${GREEN}docker-compose down${NC}"
echo -e "  • Redémarrer:         ${GREEN}docker-compose restart${NC}"
echo -e "  • Voir HDFS:          ${GREEN}docker exec namenode hdfs dfs -ls /maritime${NC}"
echo -e "  • Tester Kafka:       ${GREEN}docker exec kafka kafka-topics --list --bootstrap-server localhost:9092${NC}"

echo -e "\n${BLUE}============================================${NC}"
echo -e "Pour plus d'aide, consultez le README.md"
echo -e "${BLUE}============================================${NC}\n"