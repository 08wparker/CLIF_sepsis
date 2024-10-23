# Step 1: Define the repository URL
repo_url <- "https://github.com/08wparker/CLIF_cohort_identifier/archive/refs/heads/main.zip"
download_zip <- "CLIF_cohort_identifier.zip"

# Step 2: Download the repository ZIP
if (!file.exists(download_zip)) {
  message("Downloading the GitHub repository as a ZIP file...")
  download.file(repo_url, destfile = download_zip)
  message("Download complete.")
}

# Step 3: Unzip the repository
unzip_dir <- "CLIF_cohort_identifier-main"  # Adjust based on the folder structure after unzipping
if (!dir.exists(unzip_dir)) {
  message("Unzipping the repository...")
  unzip(download_zip)
  message("Unzipping complete.")
}

# Step 4: Run the Shiny app from the unzipped folder
app_dir <- file.path(unzip_dir, "CLIF_cohort_ID_application")  # Update to the path of your app
if (dir.exists(app_dir)) {
  message("Running the Shiny app...")
  shiny::runApp(app_dir)
} else {
  stop("App directory not found. Please check the path.")
}
