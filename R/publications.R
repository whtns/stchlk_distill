# Render the publication list used by both index.Rmd and research.Rmd.
#
# Reads the structured pub_* columns written by R/refresh_data.R. Emits HTML
# grouped by year, newest first: author line with Kevin's name bolded, title
# linked to its DOI, venue in italics.

SELF_PATTERN <- "Stachelek [A-Z]+"

bold_self <- function(authors) {
  if (is.na(authors)) return("")
  stringr::str_replace(authors, paste0("(", SELF_PATTERN, ")"), "<strong>\\1</strong>")
}

#' @param cv a CV object from create_CV_object()
#' @param n show only the n most recent publications; NULL shows all
render_publications <- function(cv, n = NULL) {
  pubs <- cv$entries_data %>%
    dplyr::filter(section == "publications", in_website == "TRUE") %>%
    dplyr::arrange(dplyr::desc(pub_year))

  if (!is.null(n)) pubs <- utils::head(pubs, n)

  years <- unique(pubs$pub_year)

  html <- lapply(years, function(yr) {
    entries <- dplyr::filter(pubs, pub_year == yr)

    items <- lapply(seq_len(nrow(entries)), function(i) {
      e <- entries[i, ]
      title <- if (!is.na(e$pub_doi) && nzchar(e$pub_doi)) {
        sprintf('<a href="https://doi.org/%s" class="pub-title">%s</a>', e$pub_doi, e$pub_title)
      } else {
        sprintf('<span class="pub-title">%s</span>', e$pub_title)
      }
      sprintf(
        '<div class="pub">
           <div class="pub-authors">%s</div>
           <div>%s</div>
           <div class="pub-venue">%s</div>
         </div>',
        bold_self(e$pub_authors), title, e$pub_venue
      )
    })

    sprintf(
      '<section class="pub-year-group">
         <h3 class="pub-year">%s</h3>
         %s
       </section>',
      yr, paste(unlist(items), collapse = "\n")
    )
  })

  htmltools::HTML(paste(unlist(html), collapse = "\n"))
}
