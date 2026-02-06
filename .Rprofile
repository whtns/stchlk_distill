# Ensure pandoc is discoverable by R Markdown
if (nzchar(Sys.which("pandoc")) == FALSE) {
  Sys.setenv(PATH = paste("/opt/homebrew/bin", Sys.getenv("PATH"), sep = ":"))
}
Sys.setenv(RSTUDIO_PANDOC = "/opt/homebrew/bin")
