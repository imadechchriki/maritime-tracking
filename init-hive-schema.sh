#!/bin/bash

# ============================================
# Script de correction du schéma Hive
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================"
echo "🔧 Correction du schéma Hive Metastore"
echo "============================================"

# Vérifier que PostgreSQL est accessible
echo -e "\n${BLUE}[1/4]${NC} Vérification de PostgreSQL..."
if ! docker exec postgres-hive pg_isready -U hive -d metastore &>/dev/null; then
    echo -e "${RED}✗ PostgreSQL n'est pas accessible${NC}"
    echo "Lancez: docker-compose restart postgres-hive"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL accessible${NC}"

# Arrêter Hive Metastore
echo -e "\n${BLUE}[2/4]${NC} Arrêt de Hive Metastore..."
docker-compose stop hive-metastore
echo -e "${GREEN}✓ Hive Metastore arrêté${NC}"

# Supprimer le schéma corrompu
echo -e "\n${BLUE}[3/4]${NC} Nettoyage du schéma PostgreSQL..."
docker exec postgres-hive psql -U hive -d metastore << 'EOF'
-- Supprimer toutes les tables Hive
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO hive;
ALTER DATABASE metastore OWNER TO hive;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Schéma nettoyé avec succès${NC}"
else
    echo -e "${RED}✗ Échec du nettoyage${NC}"
    exit 1
fi

# Redémarrer Hive Metastore
echo -e "\n${BLUE}[4/4]${NC} Redémarrage de Hive Metastore..."
docker-compose start hive-metastore

echo -e "\n${YELLOW}⏳ Attente du démarrage de Hive Metastore (30 secondes)...${NC}"
sleep 30

# Vérifier le démarrage
if docker ps | grep -q hive-metastore; then
    echo -e "${GREEN}✓ Hive Metastore redémarré${NC}"
else
    echo -e "${RED}✗ Hive Metastore n'a pas démarré${NC}"
    echo "Vérifiez les logs: docker-compose logs hive-metastore"
    exit 1
fi

# Initialiser le schéma proprement
echo -e "\n${BLUE}Initialisation du schéma Hive...${NC}"
docker exec hive-metastore /opt/hive/bin/schematool -dbType postgres -initSchema

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ SCHÉMA HIVE INITIALISÉ AVEC SUCCÈS!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    
    # Vérifier le schéma
    echo -e "\n${BLUE}Vérification du schéma...${NC}"
    docker exec hive-metastore /opt/hive/bin/schematool -dbType postgres -info
    
    echo -e "\n${YELLOW}Tables créées:${NC}"
    docker exec postgres-hive psql -U hive -d metastore -c "\dt" | head -20
else
    echo -e "\n${RED}════════════════════════════════════════════${NC}"
    echo -e "${RED}❌ ÉCHEC DE L'INITIALISATION${NC}"
    echo -e "${RED}════════════════════════════════════════════${NC}"
    echo -e "\nVoir les logs: ${YELLOW}docker-compose logs hive-metastore${NC}"
    exit 1
fi

echo -e "\n${GREEN}✅ Correction terminée!${NC}\n"