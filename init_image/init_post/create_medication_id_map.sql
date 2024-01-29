CREATE TABLE IF NOT EXISTS cds_etl_helper.medication_id_map (fhir_omop_id SERIAL NOT NULL, type varchar(64) NOT NULL, fhir_logical_id varchar(250), fhir_identifier varchar(250), atc varchar(64) NOT NULL, CONSTRAINT xpk_medication_id_map PRIMARY KEY (fhir_omop_id));
CREATE INDEX IF NOT EXISTS idx_fhir_logical_id_identifier_medication ON cds_etl_helper.medication_id_map (fhir_logical_id,fhir_identifier);

