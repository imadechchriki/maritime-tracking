#!/bin/bash
set -e

echo "Initializing Hive Metastore Database..."

# Create extensions if needed
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Grant all privileges
    GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;
    
    -- Create schema if not exists
    CREATE SCHEMA IF NOT EXISTS public;
    GRANT ALL ON SCHEMA public TO hive;
    
    -- Ensure hive user has proper permissions
    ALTER DATABASE metastore OWNER TO hive;
EOSQL

echo "Database initialized successfully!"