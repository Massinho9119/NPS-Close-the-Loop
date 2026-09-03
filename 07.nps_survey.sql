---- NPS
-- multi region sources -> vlt_mrt.survey_results, vlt_mrt.survey_url, vlt_mrt.survey_ctl
-- crea tabella ad hoc per ciascuna in looker_crm_analytics, full refresh ultimi due anni, aggiornamento daily @ 8.30, da creare dag
--SET @@location = 'us-east4';

-- survey_url
create or replace table elc-cdpcrm-prj-prd.looker_crm_analytics.survey_url
cluster by (brand_corr)
as

with
country_us as(select distinct country, region, country_description
                     from `elc-cdpcrm-prj-prd.crm_analytics.dim_country`),

excluding_na as (select invitation_date,
                        source_site,
                        UPPER(store_name) AS store_name,
                        survey_h_hid,
                        txnheader_h_hid,
                        survey_id,
                        survey_type,
                        receipt_number,
                        a.brand_name,
                        a.brand_id,
                        a.zone,
                        date_of_purchase,
                        case purchase_channel when "Internet" THEN "E-commerce" else "Brick and Mortar" end as purchase_channel,
                        case when SUBSTRING(a.brand_id,-2,2) in ('LO') THEN 'NA' ELSE SUBSTRING(a.brand_id,-2,2) END as country_brand_id,
                        c.banner as brand_corr,
                        d.type as business_type,
                        s.sales_organization,
                        
                        case when
                             case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                                  else SUBSTRING(a.brand_id,-2,2) end = "NA" then "NA" 
                             else b.country_description end as country_description,

                        case when
                             case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                                  else SUBSTRING(a.brand_id,-2,2) end = "NA" then "North America" 
                             else b.region end as region

                        from `elc-cdpcrm-prj-prd.vlt_mrt.survey_url` a
                      
                        left join country_us b                
                            on case when SUBSTRING(brand_id,-2,2) in ('LO') then 'NA'
                                    else SUBSTRING(brand_id,-2,2) end = b.country
                      
                        inner join elc-cdpcrm-prj-prd.crm_analytics.dim_brand_nps c 
                            on a.brand_id = c.brand_id
                        
                        left join (select distinct brand, type from elc-cdpcrm-prj-prd.crm_analytics.dim_brand_type) d 
                            on c.banner = d.brand
                        
                        left join elc-cdpcrm-prj-prd.vlt_mrt.sites s
                            on a.source_site = s.site_number
                      
                        where extract(year from invitation_date) >= extract(year from current_date)-2
                            and case when
                                     case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                                          else SUBSTRING(a.brand_id,-2,2) end = "NA" then "NA" 
                                     else b.country_description end != "NA"
                                     and banner not in ('LinsenMax', 'Kochoptik', 'McOptic', 'Visilab')), -- le survey VE fino ad aprile 2025 si trovano in US 

only_na as (select invitation_date,
                   source_site,
                   upper(store_name) as store_name,
                   survey_h_hid,
                   txnheader_h_hid,
                   survey_id,
                   survey_type,
                   receipt_number,
                   a.brand_name,
                   a.brand_id,
                   a.zone,
                   date_of_purchase,
                 
                   case purchase_channel when "Internet" then "E-commerce" else "Brick and Mortar" end as purchase_channel,
                   case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA' else SUBSTRING(a.brand_id,-2,2) end as country_brand_id,

                   c.banner as brand_corr,
                   d.type as business_type,
                   s.sales_organization,

                   case when
                        case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                             else SUBSTRING(a.brand_id,-2,2) end = "NA" then "NA" 
                        else b.country_description end as country_description,
                 
                   case when
                        case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                             else SUBSTRING(a.brand_id,-2,2) end = "NA" then "North America" 
                        else b.region end as region
                 
                   from `elc-cdpcrm-prj-prd.vlt_mrt.survey_url` a
                 
                   left join country_us b
                        on case when SUBSTRING(brand_id,-2,2) in ('LO') then 'NA'
                                else SUBSTRING(brand_id,-2,2) end = b.country
                 
                   inner join elc-cdpcrm-prj-prd.crm_analytics.dim_brand_nps c 
                        on a.brand_id = c.brand_id
                    
                   left join (select distinct brand, type from elc-cdpcrm-prj-prd.crm_analytics.dim_brand_type) d 
                        on c.banner = d.brand
                    
                   left join elc-cdpcrm-prj-prd.vlt_mrt.sites s
                        on a.source_site = s.site_number

                   where extract(year from invitation_date) >= extract(year from current_date)-2
                        and case when
                                 case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                                 else SUBSTRING(a.brand_id,-2,2) end = "NA" then "NA" 
                            else b.country_description end = "NA"),

country_emea as(select distinct country, region, country_description
                       from `elc-cdpcrm-prj-emea-prd.crm_analytics.dim_country`),

emea as (select invitation_date,
                source_site,
                UPPER(store_name) AS store_name,
                survey_h_hid,
                txnheader_h_hid,
                survey_id,
                survey_type,
                receipt_number,
                a.brand_name,
                a.brand_id,
                a.zone,
                date_of_purchase,
                case purchase_channel when "Internet" THEN "E-commerce" else "Brick and Mortar" end as purchase_channel,
                case when SUBSTRING(a.brand_id,-2,2) in ('LO') THEN 'NA' ELSE SUBSTRING(a.brand_id,-2,2) END as country_brand_id,
                c.banner as brand_corr,
                d.type as business_type,
                s.sales_organization,
                        
                case when
                     case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                          else SUBSTRING(a.brand_id,-2,2) end = "NA" then "NA" 
                     else b.country_description end as country_description,

                case when
                     case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                          else SUBSTRING(a.brand_id,-2,2) end = "NA" then "North America" 
                     else b.region end as region

                from `elc-cdpcrm-prj-emea-prd.vlt_mrt.survey_url` a
                
                left join country_emea b                
                    on case when SUBSTRING(brand_id,-2,2) in ('LO') then 'NA'
                            else SUBSTRING(brand_id,-2,2) end = b.country
                      
                inner join elc-cdpcrm-prj-emea-prd.crm_analytics.dim_brand_nps c 
                    on a.brand_id = c.brand_id
                
                left join (select distinct brand, type from elc-cdpcrm-prj-emea-prd.crm_analytics.dim_brand_type) d 
                    on c.banner = d.brand
                
                left join elc-cdpcrm-prj-emea-prd.vlt_mrt.sites s
                    on a.source_site = s.site_number
                
                where extract(year from invitation_date) >= extract(year from current_date)-2
                    and case when
                             case when SUBSTRING(a.brand_id,-2,2) in ('LO') then 'NA'
                                  else SUBSTRING(a.brand_id,-2,2) end = "NA" then "NA" 
                             else b.country_description end != "NA"
                    and banner in ('LinsenMax', 'Kochoptik', 'McOptic', 'VisionExpress', 'Visilab')), -- le survey VE da aprile 2025 si trovano in EMEA

union_all as (select * from excluding_na
              union all
              select * from only_na
              union all
              select * from emea)

select CAST(invitation_date AS DATE) AS invitation_date,
       source_site,
       store_name,
       survey_h_hid,
       txnheader_h_hid,
       survey_id,
       survey_type,
       receipt_number,
       case when brand_name = 'Vision Express' then replace(brand_name,' ', '') else brand_name end as brand_name,
       brand_id,
       zone,
       date_of_purchase,
       purchase_channel,
       brand_corr,
       business_type,
       region,
       case when country_description = "NA" AND substr(sales_organization, 1,2) = "CA" THEN "Canada"
            when country_description = "NA" and substr(sales_organization, 1,2) = "US" THEN "United States"
            else country_description end country_description,
     
       max(invitation_date) OVER () AS max_invitation_date
     
       from union_all;


-- survey_results
create or replace table elc-cdpcrm-prj-prd.looker_crm_analytics.survey_results
cluster by (banner)
as

select banner,
       CAST(invitation_date AS DATE) AS invitation_date,
       score,
       google_review_yn,
       survey_h_hid,
       survey_id,
       survey_type,
       transaction_id,
       verbatim,
       opt_ltr_score,
       sun_ltr_score,
       doctor_ltr_score,
       product_ltr_score,
       opt_ltr_followup_comment,
       sun_ltr_followup_comment,
       product_ltr_followup_comment

       from `elc-cdpcrm-prj-prd.vlt_mrt.survey_results` a

       left join elc-cdpcrm-prj-prd.crm_analytics.dim_brand_nps c 
                            on a.brand_id = c.brand_id
       
       where extract(year from invitation_date) >= extract(year from current_date)-2
            and banner not in ('LinsenMax', 'Kochoptik', 'McOptic', 'Visilab')

union all

select banner,
       CAST(invitation_date AS DATE) AS invitation_date,
       score,
       google_review_yn,
       survey_h_hid,
       survey_id,
       survey_type,
       transaction_id,
       verbatim,
       opt_ltr_score,
       sun_ltr_score,
       doctor_ltr_score,
       product_ltr_score,
       opt_ltr_followup_comment,
       sun_ltr_followup_comment,
       product_ltr_followup_comment

       from `elc-cdpcrm-prj-emea-prd.vlt_mrt.survey_results` a

       left join elc-cdpcrm-prj-emea-prd.crm_analytics.dim_brand_nps c 
                            on a.brand_id = c.brand_id
       
       where extract(year from invitation_date) >= extract(year from current_date)-2
            and banner in ('LinsenMax', 'Kochoptik', 'McOptic', 'VisionExpress', 'Visilab');


-- survey_ctl -> manca un attributo che ci permetta di filtrare le tabelle in base ai banner, come procediamo?
-- opzioni: join con survey_url per filtrare, fanno richiesta per aggiunta brand_id
create or replace table elc-cdpcrm-prj-prd.looker_crm_analytics.survey_ctl
cluster by (survey_h_hid)
as

select survey_h_hid,
       survey_id,
       survey_type,
       cmmacro0,
       dispositioncode1,
       lcccomment,
       incidentid,
       incidentstatus,
       verifiedcategory1
       
       from `elc-cdpcrm-prj-prd.vlt_mrt.survey_ctl`;
/*
union all

select survey_h_hid,
       survey_id,
       survey_type,
       cmmacro0,
       dispositioncode1,
       lcccomment,
       incidentid,
       incidentstatus,
       verifiedcategory1
       
       from `elc-cdpcrm-prj-emea-prd.vlt_mrt.survey_ctl`;
       */