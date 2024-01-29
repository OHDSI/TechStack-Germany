CREATE TABLE IF NOT EXISTS cds_etl_helper.post_process_map(data_id bigserial, type varchar(64) not null, data_one varchar(255), data_two varchar(255), omop_id bigint, omop_table varchar(64) not null, fhir_logical_id varchar(250), fhir_identifier varchar(250));
CREATE INDEX IF NOT EXISTS idx_fhir_type ON cds_etl_helper.post_process_map (type);
CREATE INDEX IF NOT EXISTS idx_omop_table ON cds_etl_helper.post_process_map (omop_table);
CREATE INDEX IF NOT EXISTS idx_data_one ON cds_etl_helper.post_process_map (data_one ASC);
CREATE INDEX IF NOT EXISTS idx_data_two ON cds_etl_helper.post_process_map (data_two ASC);
CREATE INDEX IF NOT EXISTS idx_fhir_logical_id_identifier_post_process ON cds_etl_helper.post_process_map (fhir_logical_id,fhir_identifier);

