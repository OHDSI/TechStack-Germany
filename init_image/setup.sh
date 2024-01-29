#!/bin/bash
set -e

SETUP_CDS=${SETUP_CDS:-"true"}
SETUP_SYNPUF=${SETUP_SYNPUF:-"false"}

OMOP_INIT_BASE_DIR="/opt/omop_init"
SOURCES_DIR="$OMOP_INIT_BASE_DIR/sources"
VOCABS_DIR="$OMOP_INIT_BASE_DIR/vocabs"
POSTINIT_DIR="$OMOP_INIT_BASE_DIR/init_post"

WEBAPI_URL=${WEBAPI_URL:?"WEBAPI_URL required but not set"}
PGPASSWORD=${PGPASSWORD:?"PGPASSWORD required but not set"}
PGHOST=${PGHOST:?"PGHOST required but not set"}

export PGDATABASE=${PGDATABASE:-"ohdsi"}
export PGUSER=${PGUSER:-"postgres"}
export PGPORT=${PGPORT:-"5432"}

echo "$(date): Checking if postgres is ready $PGHOST:$PGPORT"
until pg_isready; do
  sleep 5
done

mkdir -p "$VOCABS_DIR"

if [ "$SETUP_CDS" = "true" ]; then
    echo "$(date): Setting up CDS vocabs"

    CDS_DIR="$VOCABS_DIR/cds"
    mkdir -p "$CDS_DIR"

    echo "$(date): Extracting CDS vocabs"
    tar -xzvf "$SOURCES_DIR/cds.tar.gz" -C "$CDS_DIR" --strip-components 1

    echo "$(date): Creating CDS Schema"
    for SQL_FILE in init_cds/*; do
        echo "$(date): Applying $SQL_FILE"
        psql -f "$SQL_FILE"
    done

    echo "$(date): Copying CDS vocabulary"

    psql <<-EOSQL
			\COPY cds_cdm.care_site FROM '$CDS_DIR/CARE_SITE.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.source_to_concept_map FROM '$CDS_DIR/SOURCE_TO_CONCEPT_MAP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.drug_strength FROM '$CDS_DIR/DRUG_STRENGTH.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.concept FROM '$CDS_DIR/CONCEPT.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.concept_relationship FROM '$CDS_DIR/CONCEPT_RELATIONSHIP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.concept_ancestor FROM '$CDS_DIR/CONCEPT_ANCESTOR.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.concept_synonym FROM '$CDS_DIR/CONCEPT_SYNONYM.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.vocabulary FROM '$CDS_DIR/VOCABULARY.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.relationship FROM '$CDS_DIR/RELATIONSHIP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.concept_class FROM '$CDS_DIR/CONCEPT_CLASS.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
			\COPY cds_cdm.domain FROM '$CDS_DIR/DOMAIN.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		EOSQL

    echo "$(date): Creating CDS DB primary keys"
    PGOPTIONS=--search_path=cds_cdm psql -f "$POSTINIT_DIR/primary_keys.sql"

    echo "$(date): Creating CDS DB constraints"
    PGOPTIONS=--search_path=cds_cdm psql -f "$POSTINIT_DIR/constraints.sql"

    echo "$(date): Creating CDS DB indices"
    PGOPTIONS=--search_path=cds_cdm psql -f "$POSTINIT_DIR/indices.sql"

    echo "$(date): Creating CDS results tables"
    PGOPTIONS=--search_path=cds_cdm psql -f "$POSTINIT_DIR/results_cds.sql"

    echo "$(date): Creating ICD/SNOMED view in cds_etl_helper schema"
    PGOPTIONS=--search_path=cds_etl_helper psql -f "$POSTINIT_DIR/create_icd_snomed_view.sql"

    echo "$(date): Creating post_process_map table in cds_etl_helper schema"
    PGOPTIONS=--search_path=cds_etl_helper psql -f "$POSTINIT_DIR/create_post_process_map.sql"

    echo "$(date): Creating medication_id_map table in cds_etl_helper schema"
    PGOPTIONS=--search_path=cds_etl_helper psql -f "$POSTINIT_DIR/create_medication_id_map.sql"

    echo "$(date): Updating OHDSI WebAPI CDM sources"
    psql <<-EOSQL
			INSERT INTO ohdsi.source(source_id, source_name, source_key, source_connection, username, password, source_dialect, is_cache_enabled)
			VALUES (1, 'CDS CDM V5.3.1 Database', 'CDS-CDMV5', 'jdbc:postgresql://${PGHOST}:${PGPORT}/${PGDATABASE}', '$PGUSER', '$PGPASSWORD', 'postgresql', TRUE);

			INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
			VALUES (5, 1, 0, 'cds_cdm', 2);

			INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
			VALUES (6, 1, 1, 'cds_cdm', 2);

			INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
			VALUES (7, 1, 2, 'cds_results', 2);

			INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
			VALUES (8, 1, 3, 'cds_results', 2);
		EOSQL

fi

if [ "$SETUP_SYNPUF" = "true" ]; then

  echo "$(date): Setting up SynPUF vocabs and data"
    tar -xzvf "$SOURCES_DIR/SynPUF.tar.gz" -C "$VOCABS_DIR/"
    tar -xzvf "$SOURCES_DIR/synpuf1k.tar.gz" -C "$VOCABS_DIR/"
    SYNPUF_DIR_V="$VOCABS_DIR/SynPUF"
    SYNPUF_DIR_D="$VOCABS_DIR/synpuf1k531"

    echo "$(date): Creating SynPUF Schema"
    for SQL_FILE in init_synpuf/*; do
      echo "$(date): Applying $SQL_FILE"
      psql -f "$SQL_FILE"
    done

    echo "$(date): Copying SynPUF vocabulary"

  psql <<-EOSQL
		\COPY synpuf_cdm.drug_strength FROM '$SYNPUF_DIR_V/DRUG_STRENGTH.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.concept FROM '$SYNPUF_DIR_V/CONCEPT.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.concept_relationship FROM '$SYNPUF_DIR_V/CONCEPT_RELATIONSHIP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.concept_ancestor FROM '$SYNPUF_DIR_V/CONCEPT_ANCESTOR.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.concept_synonym FROM '$SYNPUF_DIR_V/CONCEPT_SYNONYM.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.vocabulary FROM '$SYNPUF_DIR_V/VOCABULARY.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.relationship FROM '$SYNPUF_DIR_V/RELATIONSHIP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.concept_class FROM '$SYNPUF_DIR_V/CONCEPT_CLASS.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
		\COPY synpuf_cdm.domain FROM '$SYNPUF_DIR_V/DOMAIN.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';
	EOSQL

  echo "$(date): Copying SynPUF data"

  psql <<-EOSQL
		\COPY synpuf_cdm.care_site FROM '$SYNPUF_DIR_D/care_site.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.cdm_source FROM '$SYNPUF_DIR_D/cdm_source.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.condition_era FROM '$SYNPUF_DIR_D/condition_era.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.condition_occurrence FROM '$SYNPUF_DIR_D/condition_occurrence.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.cost FROM '$SYNPUF_DIR_D/cost.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.death FROM '$SYNPUF_DIR_D/death.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.device_exposure FROM '$SYNPUF_DIR_D/device_exposure.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.drug_era FROM '$SYNPUF_DIR_D/drug_era.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.drug_exposure FROM '$SYNPUF_DIR_D/drug_exposure.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.location FROM '$SYNPUF_DIR_D/location.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.measurement FROM '$SYNPUF_DIR_D/measurement.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.observation FROM '$SYNPUF_DIR_D/observation.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.observation_period FROM '$SYNPUF_DIR_D/observation_period.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.payer_plan_period FROM '$SYNPUF_DIR_D/payer_plan_period.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.person FROM '$SYNPUF_DIR_D/person.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.procedure_occurrence FROM '$SYNPUF_DIR_D/procedure_occurrence.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.provider FROM '$SYNPUF_DIR_D/provider.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
		\COPY synpuf_cdm.visit_occurrence FROM '$SYNPUF_DIR_D/visit_occurrence.csv' DELIMITER E'\t' CSV ENCODING 'UTF8';
	EOSQL

    echo "$(date): Creating SynPUF DB primary keys"
    PGOPTIONS=--search_path=synpuf_cdm psql -f "$POSTINIT_DIR/primary_keys.sql"

    echo "$(date): Creating SynPUF DB constraints"
    PGOPTIONS=--search_path=synpuf_cdm psql -f "$POSTINIT_DIR/constraints.sql"

    echo "$(date): Creating SynPUF DB indices"
    PGOPTIONS=--search_path=synpuf_cdm psql -f "$POSTINIT_DIR/indices.sql"

    echo "$(date): Creating SynPUF results tables"
    PGOPTIONS=--search_path=synpuf_cdm psql -f "$POSTINIT_DIR/results_synpuf.sql"

  echo "$(date): Updating OHDSI WebAPI SynPUF CDM source"
  psql <<-EOSQL
		INSERT INTO ohdsi.source(source_id, source_name, source_key, source_connection, username, password, source_dialect, is_cache_enabled)
		VALUES (2, 'SynPUF CDM V5.3.1 Database', 'SynPUF-CDMV5', 'jdbc:postgresql://${PGHOST}:${PGPORT}/${PGDATABASE}', '$PGUSER', '$PGPASSWORD', 'postgresql', TRUE);

		INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
		VALUES (1, 2, 0, 'synpuf_cdm', 2);

		INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
		VALUES (2, 2, 1, 'synpuf_cdm', 2);

		INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
		VALUES (3, 2, 2, 'synpuf_results', 2);

		INSERT INTO ohdsi.source_daimon(source_daimon_id, source_id, daimon_type, table_qualifier, priority)
		VALUES (4, 2, 3, 'synpuf_results', 2);
	EOSQL

fi

if [ "$SETUP_SYNPUF" = "false" ] && [ "$SETUP_CDS" = "false" ] ; then
  echo ""
  echo "WARNING: Please set at least one of the possible flags to true (SETUP_CDS or SETUP_SYNPUF) to setup a cdm."
else
  echo "$(date): Refreshing sources"
  curl -s -L -o /dev/null --noproxy '*' "$WEBAPI_URL/source/refresh"
  echo "$(date): Completed initialization"
fi

exit 0