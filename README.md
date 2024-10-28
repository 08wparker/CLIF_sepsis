# Epidemiology of Adult Sepsis Events. 

## Objective

* Identify adult sepsis events using the [CDC Adult Sepsis Event Toolkit](https://www.cdc.gov/sepsis/pdfs/sepsis-surveillance-toolkit-mar-2018_508.pdf) criteria using the [Common Longitudinal Intensive Format (CLIF) 2.0](https://clif-consortium.github.io/website/) data structure. 
* Determine the effect of including lactate in the definition on sepsis prevalence and mortality rates

## Required CLIF tables and fields

Please refer to the online [CLIF data dictionary](https://clif-consortium.github.io/website/data-dictionary.html), [ETL tools](https://github.com/clif-consortium/CLIF/tree/main/etl-to-clif-resources), and [specific table contacts](https://github.com/clif-consortium/CLIF?tab=readme-ov-file#relational-clif) for more information on constructing the required tables and fields. List all required tables for the project here, and provide a brief rationale for why they are required.

### To identify hospitalizations and describe demographics:
- **`patient`**
- **`hospitalization`**
- **`ADT`**

### To identify presumed infection
-  **`microbiology_culture`** for blood culture collection
    - only blood culture collection data necessary, e.g. `fluid_category = "Blood/Buffy Coat"`, `collect_dttm`, and `component_category == "culture"` required
-  **`medication_admin_intermittent`** for qualifying antibiotic days
    - only `med_group == "qualifying_CMS_antibiotics` required (list of `med_categories` below)
    - `med_route_name` and `med_route_category` also required
 
![image](https://github.com/user-attachments/assets/9bbcfbd1-e171-4a99-9c6f-3aa0a6a578a3)


### To identify organ dysfunction
- **`labs`**
  - `lab_category %in% c("lactate", "creatinine", "bilirubin_total", "platelet_count")`
- **`vitals`**
- **`medication_admin_continuous`**
  - `med_category %in% c("norepinephrine", "epinephrine", "phenylephrine", "vasopressin", "dopamine", "angiotensin")`
- **`respiratory_support`**
  - only `hospitalization_id`, `recorded_dttm`, and `device_category == "IMV"` required
  

## Cohort identification

Adults admitted to inpatient status (`location_category %in% c("Ward", "ICU"`) from 1/1/2020 to 12/31/2021

``` r
start_date <- "2020-01-01"
end_date <- "2021-12-31"
```

## Expected Results:

**under construction**

## Detailed Instructions

## 1. Run [`code`](code) 

## 2. Deposit results:
Use this [file request link](https://uchicago.app.box.com/f/ceaca412782f47529f9f509f594ad9b0) to deposit your entire `result_[SITE_NAME]` folder.


