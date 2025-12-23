#!/bin/bash

# ============================================
# Script de dépannage Hive Metastore
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================"
echo "🔧 Dépannage Hive Metastore"
echo "============================================"

# 1. Vérifier l'état des conteneurs
echo -e "\n${BLUE}[1] État des conteneurs${NC}"
echo "----------------------------------------"
docker-compose ps postgres-hive hive-metastore

# 2. Vérifier PostgreSQL
echo -e "\n${BLUE}[2] Test de connexion PostgreSQL${NC}"
echo "----------------------------------------"
if docker exec postgres-hive pg_isready -U hive -d metastore &>/dev/null; then
    echo -e "${GREEN}✓ PostgreSQL est accessible${NC}"
    
    # Vérifier les tables
    echo -e "\n${YELLOW}Tables dans la base metastore:${NC}"
    docker exec postgres-hive psql -U hive -d metastore -c "\dt" 2>/dev/null || echo -e "${RED}Erreur lors de la récupération des tables${NC}"
else
    echo -e "${RED}✗ PostgreSQL n'est pas accessible${NC}"
fi

# 3. Vérifier les logs Hive
echo -e "\n${BLUE}[3] Derniers logs Hive Metastore${NC}"
echo "----------------------------------------"
docker-compose logs --tail=50 hive-metastore

# 4. Tester la connexion réseau
echo -e "\n${BLUE}[4] Test de résolution DNS${NC}"
echo "----------------------------------------"
docker exec hive-metastore ping -c 2 postgres-hive 2>/dev/null && echo -e "${GREEN}✓ DNS fonctionne${NC}" || echo -e "${RED}✗ Problème DNS${NC}"

# 5. Vérifier le schéma Hive
echo -e "\n${BLUE}[5] Informations sur le schéma Hive${NC}"
echo "----------------------------------------"
docker exec hive-metastore /opt/hive/bin/schematool -dbType postgres -info 2>&1 || echo -e "${YELLOW}⚠️  Impossible de récupérer les infos${NC}"

# 6. Proposer des solutions
echo -e "\n${BLUE}[6] Actions recommandées${NC}"
echo "----------------------------------------"

SCHEMA_EXISTS=$(docker exec postgres-hive psql -U hive -d metastore -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='VERSION';" 2>/dev/null || echo "0")

if [ "$SCHEMA_EXISTS" = "0" ]; then
    echo -e "${YELLOW}⚠️  Le schéma Hive n'est pas initialisé${NC}"
    echo ""
    echo "Commandes pour corriger:"
    echo -e "  ${GREEN}docker exec hive-metastore /opt/hive/bin/schematool -dbType postgres -initSchema${NC}"
else
    echo -e "${GREEN}✓ Schéma Hive existe${NC}"
    
    # Vérifier s'il y a des problèmes de version
    echo ""
    echo "Pour mettre à jour le schéma:"
    echo -e "  ${GREEN}docker exec hive-metastore /opt/hive/bin/schematool -dbType postgres -upgradeSchema${NC}"
fi

echo ""
echo "Pour réinitialiser complètement:"
echo -e "  ${YELLOW}docker-compose down -v${NC}"
echo -e "  ${YELLOW}docker-compose up -d${NC}"

echo ""
echo "Pour voir les logs en temps réel:"
echo -e "  ${GREEN}docker-compose logs -f hive-metastore${NC}"
echo -e "  ${GREEN}docker-compose logs -f postgres-hive${NC}"

echo ""
echo "============================================"