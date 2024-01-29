#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE ROLE ohdsi_admin_user LOGIN PASSWORD '${OHDSI_ADMIN_PASSWORD}' VALID UNTIL 'infinity';
    COMMENT ON ROLE ohdsi_admin_user IS 'Admin user account for OHDSI applications';
    CREATE ROLE ohdsi_admin CREATEDB REPLICATION VALID UNTIL 'infinity';
    COMMENT ON ROLE ohdsi_admin IS 'Administration group for OHDSI applications';
    GRANT ohdsi_admin TO ohdsi_admin_user;
    GRANT ALL ON DATABASE ohdsi TO GROUP ohdsi_admin;
EOSQL
