# Epidemiology of Adult Sepsis Events 

## Objective

Identify adult sepsis events using the [CDC Adult Sepsis Event Toolkit](https://www.cdc.gov/sepsis/pdfs/sepsis-surveillance-toolkit-mar-2018_508.pdf) criteria using the [Common Longitudinal Intensive Format (CLIF) 2.0](https://clif-consortium.github.io/website/) data structure. 

## Required CLIF tables and fields

Please refer to the online [CLIF data dictionary](https://clif-consortium.github.io/website/data-dictionary.html), [ETL tools](https://github.com/clif-consortium/CLIF/tree/main/etl-to-clif-resources), and [specific table contacts](https://github.com/clif-consortium/CLIF?tab=readme-ov-file#relational-clif) for more information on constructing the required tables and fields. List all required tables for the project here, and provide a brief rationale for why they are required.

### To identify hospitalizations and describe demographics:
- **`patient`**
- **`hospitalization`**
- **`ADT`**

### To identify presumed infection
-  **`microbiology_culture`** for blood culture collection
-  **`medication_admin_intermittent`** for qualifying antibiotic days

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

## Expected Results

Describe the output of the analysis. The final project results should be saved in the [`output/final`](output/README.md) directory.

## Detailed Instructions for running the project

## 1. Setup Project Environment
Describe the steps to setup the project environment. 

Example for R:
```
# Setup R environment using renv
# Install renv if not already installed:
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
# Initialize renv for the project:
renv::init()
# Install required packages:
renv::install(c("knitr", "here", "tidyverse", "arrow", "gtsummary"))
# Save the project's package state:
renv::snapshot()
```

## 2. Update `config/config.json`
Follow instructions in the [config/README.md](config/README.md) file for detailed configuration steps.

## 3. Run code
Detailed instructions on the code workflow are provided in the [code directory](code/README.md)


## Example Repositories
* [CLIF Adult Sepsis Events](https://github.com/08wparker/CLIF_adult_sepsis_events) for R
* [CLIF Eligibility for mobilization](https://github.com/kaveriC/mobilization) for Python
---


