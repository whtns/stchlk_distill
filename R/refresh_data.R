# Snapshot the CV Google Sheet to data/*.csv.
#
# Run by hand whenever the sheet changes:
#
#   Rscript R/refresh_data.R
#
# The site build reads only data/*.csv and never touches the network. This is the
# only script allowed to hit Google or Crossref.
#
# Publication rows are enriched with structured columns (pub_authors, pub_title,
# pub_venue, pub_year, pub_doi) resolved from Crossref by DOI, since the sheet
# stores each citation as one free-text blob and the blobs are not in a single
# consistent style. The original `title` blob is left untouched — the CV/
# documents render from it.

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
})

SHEET <- "https://docs.google.com/spreadsheets/d/1IY5sQS_JlNAYvsmCaEVTNHl6Zl7dOuhY4ulfnAeBBJ0/edit"
DATA_DIR <- "data"
SELF <- "Stachelek"

# Crossref asks for a contact address so they can reach you about heavy usage.
CROSSREF_MAILTO <- "stachele@usc.edu"

# Crossref titles carry JATS markup (<scp>, <i>, <sub>) and hard line breaks.
clean_text <- function(x) {
  if (is.na(x)) return(NA_character_)
  x <- str_replace_all(x, "<[^>]+>", "")
  x <- str_replace_all(x, "&amp;", "&")
  x <- str_squish(x)
  # removing an inline tag can strand a space before its punctuation
  str_replace_all(x, "\\s+([,.;:])", "\\1")
}

crossref_by_doi <- function(doi) {
  empty <- list(authors = NA_character_, title = NA_character_,
                venue = NA_character_, year = NA_character_)
  if (is.na(doi) || !nzchar(doi)) return(empty)

  url <- paste0("https://api.crossref.org/works/", utils::URLencode(doi, reserved = TRUE),
                "?mailto=", utils::URLencode(CROSSREF_MAILTO, reserved = TRUE))
  res <- tryCatch(jsonlite::fromJSON(url), error = function(e) NULL)
  if (is.null(res) || is.null(res$message)) {
    warning("Crossref lookup failed for DOI: ", doi, call. = FALSE)
    return(empty)
  }
  m <- res$message

  authors <- if (!is.null(m$author)) {
    given <- m$author$given
    family <- m$author$family
    initials <- vapply(
      str_split(given %||% rep("", length(family)), "[ -]+"),
      function(parts) paste0(str_sub(parts[nzchar(parts)], 1, 1), collapse = ""),
      character(1)
    )
    paste(paste(family, initials), collapse = ", ")
  } else {
    NA_character_
  }

  # issued is the canonical publication date; online-first papers can carry a
  # different year in `published-print`, so prefer `issued`.
  year <- tryCatch(as.character(m$issued$`date-parts`[[1]][1]), error = function(e) NA_character_)

  list(
    authors = clean_text(authors),
    title   = clean_text(m$title[1] %||% NA_character_),
    venue   = clean_text(m$`container-title`[1] %||% NA_character_),
    year    = year
  )
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x[1])) y else x

# Fallback for rows with no DOI: pull what we can out of the citation blob.
parse_blob <- function(blob) {
  blob <- str_squish(blob)
  year <- str_match(blob, "\\((\\d{4})\\)")[, 2]
  list(authors = NA_character_, title = blob, venue = NA_character_, year = year)
}

main <- function() {
  googlesheets4::gs4_deauth()

  tabs <- c("entries", "language_skills", "text_blocks", "contact_info")
  sheets <- lapply(tabs, function(tab) {
    googlesheets4::read_sheet(SHEET, sheet = tab, skip = 1, col_types = "c")
  })
  names(sheets) <- tabs

  entries <- sheets$entries
  pubs <- entries$section == "publications"

  meta <- lapply(seq_len(nrow(entries)), function(i) {
    if (!pubs[i]) return(list(authors = NA_character_, title = NA_character_,
                              venue = NA_character_, year = NA_character_))
    doi <- entries$loc[i]
    if (is.na(doi) || !nzchar(doi)) {
      message("No DOI for publication row ", i, "; falling back to blob parse.")
      parse_blob(entries$title[i])
    } else {
      Sys.sleep(0.2)
      crossref_by_doi(doi)
    }
  })

  entries <- entries %>%
    mutate(
      pub_authors = vapply(meta, function(m) m$authors %||% NA_character_, character(1)),
      pub_title   = vapply(meta, function(m) m$title   %||% NA_character_, character(1)),
      pub_venue   = vapply(meta, function(m) m$venue   %||% NA_character_, character(1)),
      pub_year    = vapply(meta, function(m) m$year    %||% NA_character_, character(1)),
      pub_doi     = if_else(pubs, loc, NA_character_)
    )
  # The sheet's year wins: Crossref `issued` reports the issue date, which for
  # online-first papers lands a year after the one the author cites. Fall back to
  # Crossref only when the sheet has no year.
  from_sheet <- pubs & !is.na(entries$start)
  entries$pub_year[from_sheet] <- entries$start[from_sheet]

  sheets$entries <- entries

  dir.create(DATA_DIR, showWarnings = FALSE)
  for (tab in tabs) {
    path <- file.path(DATA_DIR, paste0(tab, ".csv"))
    # create_CV_object() reads these with skip = 1, matching the sheet's banner row.
    writeLines(paste0("# snapshot of the '", tab, "' sheet tab -- do not edit by hand"), path)
    readr::write_csv(sheets[[tab]], path, append = TRUE, col_names = TRUE)
  }

  cat("\nPublications written:\n\n")
  entries %>%
    filter(pubs) %>%
    arrange(desc(pub_year)) %>%
    transmute(
      pub_year,
      self_found = str_detect(pub_authors %||% "", SELF),
      pub_doi,
      pub_venue = str_trunc(pub_venue, 30),
      pub_title = str_trunc(pub_title, 60)
    ) %>%
    as.data.frame() %>%
    print(right = FALSE)

  missing <- entries %>% filter(pubs, is.na(pub_title) | is.na(pub_authors))
  if (nrow(missing) > 0) {
    warning(nrow(missing), " publication(s) did not resolve; check the DOIs.", call. = FALSE)
  }
  cat("\nCheck self_found is TRUE for every row, then commit data/.\n")
}

if (!interactive()) main()
