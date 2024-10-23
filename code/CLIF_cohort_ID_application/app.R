library(shiny)
library(shinyFiles)
library(tidyverse)
library(arrow)
library(gtsummary)
library(jsonlite)
library(gt)

tables <- c("vitals", "labs", 
            "medication_admin_continuous", "medication_admin_intermittent", "patient_assessments",
            "respiratory_support", "position", "dialysis", 
            "microbiology_culture")


# List of sites from the provided image
site_names <- c(
  "Emory University",
  "Johns Hopkins Health System",
  "Northwestern University",
  "Oregon Health & Science University",
  "RUSH University",
  "University of Chicago",
  "University of Michigan",
  "University of Minnesota"
)

# Define the UI
ui <- fluidPage(
  titlePanel("CLIF Cohort Identification for ATS 2024 projects"),
  
  # Custom CSS for buttons
  tags$head(
    tags$style(HTML("
      #identifyCohort, #tables_dir {
        background-color: maroon;
        color: white;
        border: none;
        padding: 10px 20px;
        font-size: 16px;
        cursor: pointer;
      }
      
      #identifyCohort:hover, #tables_dir:hover {
        background-color: darkred;
      }
    "))
  ),
  
  # Add description under the title
  HTML("<p>This app allows users to filter a cohort of <strong>inpatient  hospitalizations</strong>  from the CLIF dataset based on user-defined criteria. It performs cohort identification, filtering of hospitalization data, and generates a summary table of key characteristics (Table 1) for the cohort. Files are saved in a newly created study_cohort folder in the tables path directory. The app also creates a config JSON file that saves the user selections.</p>"),
  
  sidebarLayout(
    sidebarPanel(
      # Site Name (select input from pre-defined list)
      selectInput("site_name", "Site Name:", choices = site_names, selected = NULL),
      
      
      # Add description under the title
      HTML("<p><strong>CLIF tables location:<strong></p>"),
      
      # GUI to select the folder for the tables path
      shinyDirButton("tables_dir", "Choose Tables Directory", 
                     "Please select the directory containing the CLIF tables"),
      
      # Display the selected directory
      verbatimTextOutput("tables_path"),

      # File type selection (only parquet and csv)
      selectInput("file_type", "File Type:", choices = c("parquet", "csv"), selected = "parquet"),
      
      # output folder specification
      textInput("output_folder", "Output folder name:", value = "Sepsis_study_cohort"),
      
      # add title "Data Filters"
      HTML("<p><strong>Filtering options:</strong></p>"),
      
      # Date range input
      dateRangeInput("dateRange", "Date range:", start = "2020-01-01", end = "2021-12-31"),
      
      # Checkbox for pediatric admissions and ER deaths
      checkboxInput("includePediatric", "Include pediatric admissions", FALSE),
      checkboxInput("includeERDeaths", "Include ER deaths", TRUE),
      
      # Drop observations with missing time variables
      checkboxInput("dropMissingDttm", "Drop observations with missing time stamps?", TRUE),
      
      # Table selection with ADT forced to be selected
      checkboxGroupInput("selectedTables", "Select Tables to be filtered:",
                         choices = tables,
                         selected = c("vitals", "labs", 
                                      "medication_admin_continuous", "medication_admin_intermittent", 
                                      "respiratory_support", 
                                      "microbiology_culture")),
      
      helpText("Patient, Hospitalization, and ADT are required."),
      
      helpText("Remaining conceptual CLIF tables not yet implemented.")

    ),
    
    mainPanel(
      verbatimTextOutput("filePaths"),
      verbatimTextOutput("saveStatus"),  # This will display the success message
      # Button to trigger cohort identification
      actionButton("identifyCohort", "Identify Cohort"),
      gt_output("summaryTable")  
    )
  )
)


# Define the server logic
server <- function(input, output, session) {
  
  # Enable file system access with shinyFiles
  shinyDirChoose(input, "tables_dir", roots = c(home = "~", root = "/"), session = session)
  
  # Reactively get the tables directory path
  tables_dir <- reactive({
    if (is.null(input$tables_dir)) return(NULL)
    return(parseDirPath(roots = c(home = "~"), input$tables_dir))
  })
  
  # Display the selected directory
  output$tables_path <- renderPrint({
    req(tables_dir())
    cat(tables_dir())
  })
  
  # Event that triggers cohort identification when the button is clicked
  observeEvent(input$identifyCohort, {
    
    # Show a progress bar during filtering and saving
    withProgress(message = 'Filtering and Saving Data...', value = 0, {
      
      # Fetch user inputs for configuration
      site_name <- input$site_name
      tables_path <- tables_dir()  # Get the selected directory path
      file_type <- input$file_type
      save_path <- file.path(tables_path, input$output_folder)
      
      # Create the directory to store filtered files if it doesn't exist
      if (!dir.exists(save_path)) {
        dir.create(save_path)
      }

      # Required tables (these are always included)
      required_tables <- c("patient", "hospitalization", "adt")
      
      # Add the required tables to the list of tables to be processed
      selected_tables <- input$selectedTables  # Get the tables selected by the user
      all_tables <- unique(c(required_tables, selected_tables))
      # Step 0.1 Check that required and selected tables are in the tables_path folder
      
      # Required tables (these are always included)
      required_tables <- c("patient", "hospitalization", "adt")
      
      # Add the required tables to the list of tables to be processed
      selected_tables <- input$selectedTables  # Get the tables selected by the user
      all_tables <- unique(c(required_tables, selected_tables))
      
      # Step 0.1 Check that required and selected tables are in the tables_path folder
      # List all CLIF files in the directory with the specified file type (parquet or csv)
      clif_table_filenames <- list.files(path = tables_path, 
                                         pattern = paste0("^clif_.*\\.", file_type, "$"), 
                                         full.names = TRUE)
      
      # Extract the base names of the files (without the extension)
      clif_table_basenames <- basename(clif_table_filenames) %>%
        str_remove(paste0("\\.", file_type, "$"))
      
      # Create a lookup table for the required filenames based on the user-selected and required tables
      expected_filenames <- paste0("clif_", all_tables)
      
      # Check if all required files are present
      missing_files <- setdiff(expected_filenames, clif_table_basenames)
      
      # If there are missing tables, stop execution and show an error message
      if (length(missing_files) > 0) {
        output$saveStatus <- renderPrint({
          cat("Error: Missing required tables in the directory:\n")
          cat(paste(missing_files, collapse = "\n"), "\n")
        })
        
        # Interrupt the code execution here using validate and need
        validate(need(length(missing_files) == 0, "Missing required files, cannot proceed."))
      }

      # Step 0.2 Convert CSV files to Parquet if the user selects "csv" 
      if (file_type == "csv") {
        incProgress(0.05, detail = "Converting CSV files to Parquet...")
        
        # List all CSV files in the directory
        csv_files <- list.files(path = tables_path, pattern = "\\.csv$", full.names = TRUE)
        
        # Convert each CSV to Parquet
        for (csv_file in csv_files) {
          table_name <- gsub("\\.csv$", "", basename(csv_file))  # Get table name from file name
          data <- read_csv(csv_file)  # Read the CSV file
          
          # Write the Parquet file with the same name
          write_parquet(data, file.path(tables_path, paste0(table_name, ".parquet")))
          
          remove(data)
        }
        
        incProgress(0.1, detail = "CSV to Parquet conversion completed.")
      }
      
      
      # Step 0.3: Save user settings as a JSON file
      incProgress(0.15, detail = "Saving configuration settings...")
      
      # Define the config file path (modify according to the correct structure)
      config_path <- file.path("../../config")
      
      # Create the directory if it doesn't exist
      if (!dir.exists(config_path)) {
        dir.create(config_path, recursive = TRUE)
      }
      # Collect user settings
      user_settings <- list(
        site_name = site_name,
        tables_path = tables_path,
        file_type = file_type,
        date_range = list(start = input$dateRange[1], end = input$dateRange[2]),
        include_pediatric = input$includePediatric,
        include_er_deaths = input$includeERDeaths,
        drop_missing_dttm = input$dropMissingDttm,
        selected_tables = selected_tables
      )
      
      # Save the settings to a JSON file
      write_json(user_settings, file.path(config_path, "config.json"), pretty = TRUE, auto_unbox = TRUE)
      
      
      # Step 1: Filtering hospitalization table by time and age
      incProgress(0.3, detail = "Loading and filtering required tables...")
     
      # Initialize a list to store the filtered tables
      tables_to_filter <- list()
      
      # When loading the patient, hospitalization, and ADT tables, use file.path() for correct path concatenation
      tables_to_filter$clif_patient <- open_dataset(file.path(tables_path, "clif_patient.parquet"))
      tables_to_filter$clif_hospitalization <- open_dataset(file.path(tables_path, "clif_hospitalization.parquet"))
      tables_to_filter$clif_adt <- open_dataset(file.path(tables_path, "clif_adt.parquet"))
      
      
      ## apply admission date time filter
      start_date <- input$dateRange[1]
      end_date <- input$dateRange[2]
      clif_hospitalization_filtered <- tables_to_filter$clif_hospitalization %>%
        filter(admission_dttm >= start_date & admission_dttm <= end_date)
      
      # Apply pediatric exclusion if necessary
      include_pediatric <- input$includePediatric
      if (!include_pediatric) {
        clif_hospitalization_filtered <- clif_hospitalization_filtered %>%
          filter(age_at_admission >= 18)
      }
      
      clif_hospitalization_filtered <- collect(clif_hospitalization_filtered)
      cohort_hospitalization_ids <- clif_hospitalization_filtered$hospitalization_id
      
      # Step 2: apply ADT criteria filters
      incProgress(0.4, detail = "Filtering ADT table...")

      inpatient_hospitalization_ids <- tables_to_filter$clif_adt %>%
        filter(tolower(location_category) %in% c("ward", "icu")) %>%
        filter(hospitalization_id %in% cohort_hospitalization_ids) %>%
        select(hospitalization_id) %>%
        collect() %>%
        pull(hospitalization_id)
      
      cohort_hospitalization_ids <- intersect(cohort_hospitalization_ids, inpatient_hospitalization_ids)
      
      include_er_deaths <- input$includeERDeaths
      ## Identify patients who died in the ER and include if specified
      if (include_er_deaths) {
        # identify hospitalization_ids with only ER location_category
        ER_only_hospitalization_ids <- tables_to_filter$clif_adt %>%
          filter(hospitalization_id %in% clif_hospitalization_filtered$hospitalization_id) %>%
          collect() %>%
          group_by(hospitalization_id) %>%
          filter(all(tolower(location_category) == "er")) %>%
          pull(hospitalization_id)
        
        ER_death_ids <- tables_to_filter$clif_hospitalization %>%
          filter(hospitalization_id %in% ER_only_hospitalization_ids) %>%
          filter(discharge_category == "Expired") %>%
          collect() %>%
          pull(hospitalization_id)
        
        cohort_hospitalization_ids <- union(cohort_hospitalization_ids, ER_death_ids)
      }
      
      clif_hospitalization_filtered <- clif_hospitalization_filtered %>%
        filter(hospitalization_id %in% cohort_hospitalization_ids)
      
      # Step 3: Dynamically load and filter additional tables based on user selection
      incProgress(0.5, detail = "Loading and filtering additional tables...")
      
      # Iterate over the user-selected tables and filter them based on the cohort_hospitalization_ids
      for (table_name in selected_tables) {
        
        # Load the dataset for the current table using file.path()
        tables_to_filter[[paste0("clif_", table_name)]] <- open_dataset(file.path(tables_path, paste0("clif_", table_name, ".parquet")))
        
        # Apply the filtering on hospitalization_id
        tables_to_filter[[paste0("clif_", table_name, "_cohort")]] <- tables_to_filter[[paste0("clif_", table_name)]] %>%
          filter(hospitalization_id %in% cohort_hospitalization_ids) %>%
          collect()
      }
      
      # Step 4: Save the filtered cohort tables as Parquet files
      incProgress(0.7, detail = "Saving filtered cohort tables...")
      
      patient_ids <- clif_hospitalization_filtered %>% pull(patient_id)
      
      clif_patient_filtered <- tables_to_filter$clif_patient %>%
        filter(patient_id %in% patient_ids) %>%
        collect()
      
      write_parquet(clif_patient_filtered, file.path(save_path, "clif_patient_cohort.parquet"))

      
      # Save filtered hospitalization table
      clif_hospitalization_filtered <- clif_hospitalization_filtered %>%
        filter(hospitalization_id %in% cohort_hospitalization_ids)
      
      write_parquet(clif_hospitalization_filtered, file.path(save_path, "clif_hospitalization_cohort.parquet"))
      
      # Save filtered ADT table
      clif_adt_filtered <- tables_to_filter$clif_adt %>%
        filter(hospitalization_id %in% cohort_hospitalization_ids) %>%
        collect()
      
      write_parquet(clif_adt_filtered, file.path(save_path, "clif_adt_cohort.parquet"))
      
    
      # Save all required and user-selected tables
      for (table_name in  all_tables) {
        
        # Dynamically construct the cohort version of the table
        filtered_data <- tables_to_filter[[paste0("clif_", table_name, "_cohort")]]
        
        # Construct the file name and save the Parquet file
        file_name <- paste0("clif_", table_name, "_cohort.parquet")
        
        # Save the table if it was successfully filtered and collected
        if (!is.null(filtered_data)) {
          write_parquet(filtered_data, file.path(save_path, file_name))
        }
      }

      incProgress(0.8, detail = "Creating table one...")
      # Generate Table 1 summary
      
      # Generate 'ever_icu' variable
      ever_icu_id <- clif_adt_filtered %>%
        filter(tolower(location_category) == "icu") %>%
        pull(hospitalization_id) %>%
        unique()
      
      
      table_one_hospitalization <- clif_hospitalization_filtered %>%
        mutate(length_of_stay = as.numeric(as.Date(discharge_dttm) - 
                                             as.Date(admission_dttm), units = "days")) %>%
        select(patient_id, hospitalization_id, age_at_admission, discharge_category, 
               length_of_stay) %>%
        left_join(clif_patient_filtered %>% 
                    select(patient_id, race_category, sex_category, 
                           ethnicity_category), by = "patient_id") %>%
        mutate(ever_icu = ifelse(hospitalization_id %in% ever_icu_id, "ICU stay", "Floor only")) %>% 
        select(-patient_id, -hospitalization_id) %>%
        tbl_summary(by = "ever_icu") %>%
        as_gt()
      
      # Display Table 1 in the main panel
      output$summaryTable <- render_gt({
        table_one_hospitalization
      })
      
      
      # Step 5: Completion message
      incProgress(1, detail = "Completed!")
      
      # Show the notification message in the main panel
      output$saveStatus <- renderPrint({
        cat("Cohort files saved successfully in the folder:", save_path, "\n")
        cat("Saved files:\n")
        
        # Dynamically loop through all the saved tables (both required and selected)
        for (table_name in all_tables) {
          file_name <- paste0("clif_", table_name, "_cohort.parquet")
          cat(" -", file_name, "\n")
        }
        
      })
    })
  })
  
  # Optionally output the file paths or error messages
  output$filePaths <- renderPrint({
    cat("Site Name:", input$site_name, "\n")
    cat("Tables Path:", tables_dir(), "\n")
    cat("File Type:", input$file_type, "\n")
  })
}

# Run the application 
shinyApp(ui = ui, server = server)