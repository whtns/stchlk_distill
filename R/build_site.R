# Build the site.
#
# rmarkdown's site generator renders every root-level .md file that does not
# start with "_" (only README.md is special-cased), and _site.yml has no hook to
# opt files out. AGENTS.md / CLAUDE.md must live at the repo root for the agent
# tooling to find them, so hide them behind an underscore for the duration of
# the build, otherwise they are published as pages and land in sitemap.xml.

build_site <- function() {
  agent_files <- c("AGENTS.md", "CLAUDE.md")
  agent_files <- agent_files[file.exists(agent_files)]
  hidden <- paste0("_", agent_files)

  file.rename(agent_files, hidden)
  on.exit(file.rename(hidden, agent_files), add = TRUE)

  rmarkdown::render_site()
}

if (identical(environment(), globalenv()) && !interactive()) {
  build_site()
}
