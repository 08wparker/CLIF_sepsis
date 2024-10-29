# render_quality_check_report.R

# Load required libraries
library(here)
library(rmarkdown)

# Load the configuration utility
source(here("utils/config.R"))

# Define the site name and the output folder path
site_name <- config$site_name
output_folder <- here::here(paste0("result_", site_name))  # Creates folder in parent directory

output_folder

# Create the output directory if it doesn’t exist
if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}

# Define the path for the output HTML file
output_file <- file.path(output_folder, "02_quality_check_report.html")

# Render the R Markdown file with the specified output path
rmarkdown::render(
  input = here("code", "rmd code", "02_quality_check_report.Rmd"),  # Updated path to the Rmd file
  output_file = output_file,
  output_format = "html_document"
)

# Notify the user
message("Report has been saved to: ", output_file)
