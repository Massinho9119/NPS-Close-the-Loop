
CREATE TABLE IF NOT EXISTS `elc-cdpcrm-prj-prd.looker_crm_analytics.nps_gemini_comment_transl`
(survey_h_hid STRING,
invitation_date TIMESTAMP,
comment STRING,
brand STRING,
result STRING,
translated_comment STRING);

MERGE `elc-cdpcrm-prj-prd.looker_crm_analytics.nps_gemini_comment_transl` T
USING (
  with 
    mydata AS (
      SELECT
        survey_h_hid,
        invitation_date,
        CONCAT(
          IFNULL(opt_ltr_followup_comment, ''),
          IFNULL(sun_ltr_followup_comment, ''),
          IFNULL(product_ltr_followup_comment, ''),
          IFNULL(verbatim, '')
        ) AS comment,
        CASE 
          WHEN brand_id LIKE 'OP%' THEN 'Oliver Peoples'
          WHEN brand_id LIKE 'VO%' THEN 'Vogue'
          WHEN brand_id LIKE 'SGH%' THEN 'Sunglass Hut'
          WHEN brand_id LIKE 'PO%' THEN 'Persol'
          WHEN brand_id LIKE 'SLS%' THEN 'Solaris'
          WHEN brand_id LIKE 'O2%' THEN 'Oakley'
          WHEN brand_id LIKE 'RB%' THEN 'Ray-Ban'
          WHEN brand_id LIKE 'ARN%' THEN 'Arnette'
          WHEN brand_id LIKE 'VD%' THEN 'VisionDirect'
          ELSE NULL
        END AS brand
      FROM `elc-cdpcrm-prj-prd.tmp_looker_crm.tmp_nps_survey_results_partitioned`
      WHERE 
        CONCAT(
          IFNULL(opt_ltr_followup_comment, ''),
          IFNULL(sun_ltr_followup_comment, ''),
          IFNULL(product_ltr_followup_comment, ''),
          IFNULL(verbatim, '')
        ) != ""
        AND CASE 
          WHEN brand_id LIKE 'OP%' THEN 'Oliver Peoples'
          WHEN brand_id LIKE 'VO%' THEN 'Vogue'
          WHEN brand_id LIKE 'SGH%' THEN 'Sunglass Hut'
          WHEN brand_id LIKE 'PO%' THEN 'Persol'
          WHEN brand_id LIKE 'SLS%' THEN 'Solaris'
          WHEN brand_id LIKE 'O2%' THEN 'Oakley'
          WHEN brand_id LIKE 'RB%' THEN 'Ray-Ban'
          WHEN brand_id LIKE 'ARN%' THEN 'Arnette'
          WHEN brand_id LIKE 'VD%' THEN 'VisionDirect'
          ELSE NULL
        END IS NOT NULL
    ),
    a AS (
      SELECT
        ml_generate_text_llm_result AS result,
        comment,
        survey_h_hid,
        invitation_date,
        brand
      FROM
        ML.GENERATE_TEXT (
          MODEL `elc-cdpcrm-prj-prd.looker_crm_analytics.gemini_flash`,
          (
              SELECT
                CONCAT(
                    'Translate the following text to English. The output must be in JSON format as follows: {"translation": "translated text"}. Please do not include any additional information, only the JSON object. The text to translate is the following:',
                    NULLIF(comment, "")
                ) AS prompt,
                comment,
                survey_h_hid,
                invitation_date,
                brand
              FROM mydata
          ),
          STRUCT(
              0.2 AS temperature,
              1000 AS max_output_tokens,
              TRUE AS flatten_json_output
          )
        )
    )

  SELECT
    survey_h_hid,
    invitation_date,
    comment,
    brand,
    result,
      JSON_VALUE(CASE
    WHEN REGEXP_CONTAINS(result, r'^\s*```json\s*(.+?)\s*```\s*$') THEN
      REGEXP_EXTRACT(result, r'^\s*```json\s*(.+?)\s*```\s*$')
    ELSE result
  END, "$.translation") AS translated_comment
  FROM (
    SELECT
      survey_h_hid,
      invitation_date,
      comment,
      brand,
      result,
      REGEXP_EXTRACT(result, r'```json\s*(\{[\s\S]*?\})\s*```') AS result_json
    FROM a
  )
  
) S

ON  
  (T.survey_h_hid = S.survey_h_hid  OR (T.survey_h_hid IS NULL AND S.survey_h_hid IS NULL)) AND
  (T.invitation_date = S.invitation_date  OR (T.invitation_date IS NULL AND S.invitation_date IS NULL))

WHEN MATCHED THEN
    UPDATE SET 
        T.comment = S.comment,
        T.brand = S.brand,
        T.result = S.result,
        T.translated_comment = S.translated_comment

  WHEN NOT MATCHED THEN
    INSERT (
        survey_h_hid,
        invitation_date,
        comment,
        brand,
        result,
        translated_comment
        )
    VALUES (
        S.survey_h_hid,
        S.invitation_date,
        S.comment,
        S.brand,
        S.result,
        S.translated_comment
    )

