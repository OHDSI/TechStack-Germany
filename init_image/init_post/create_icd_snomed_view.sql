CREATE MATERIALIZED
VIEW icd_snomed_domain_lookup AS
SELECT
    c1.concept_code AS icd_gm_code,
    c1.concept_id AS icd_gm_concept_id,
    cr.concept_id_2 AS snomed_concept_id,
    c2.domain_id AS snomed_domain_id,
    c3.domain_concept_id AS snomed_domain_concept_id,
    c1.valid_start_date AS icd_gm_valid_start_date,
    c1.valid_end_date AS icd_gm_valid_end_date
FROM
    cds_cdm.concept c1
    JOIN
    cds_cdm.concept_relationship cr
    ON
    c1.concept_id = cr.concept_id_1
    JOIN
    cds_cdm.concept c2
    ON
    cr.concept_id_2 = c2.concept_id
    JOIN
    cds_cdm.domain c3
    ON
    c2.domain_id = c3.domain_id
WHERE
    1=1
    AND c1.vocabulary_id = 'ICD10GM'
    AND cr.relationship_id = 'Maps to'
