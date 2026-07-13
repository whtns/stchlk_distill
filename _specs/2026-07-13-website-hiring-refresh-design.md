# Website refresh for a hiring audience

Date: 2026-07-13
Status: approved, not yet implemented

## Problem

The site targets people evaluating Kevin professionally (PIs, hiring managers,
collaborators). Four things work against that reader:

1. The publications page renders a DT widget with one hidden-header column. No
   year, no venue, no link — a reader cannot click through to a single paper.
   Pagination hides anything past row 10.
2. The publications build fetches a live Google Sheet at knit time. If the sheet
   goes private or Google changes the export path, the build breaks.
3. The homepage is a bare postcards card: photo, name, three icon links. It never
   says what Kevin works on.
4. The blog's newest post is from May 2021, presented as a dated blog, so it
   reads as abandoned rather than as a reference archive.

Navbar search stays off: a four-page site with nine posts does not need it.

## Data model, as it exists

The Sheet's `entries` tab has columns `section | title | loc | institution |
start | end | description_1..3 | in_resume | in_website`. For the ten
`section == "publications"` rows:

- `title` holds the entire citation as one string, in reference-manager style:
  `Authors. Title. Venue (Year)[ doi:...].`
- `start` holds the year.
- `loc` and `institution` are empty.

One paper carries an inline `doi:` in the blob. The rest do not.

`create_CV_object()` in `R/cv_printing_functions_website.R` already has a
local-CSV branch, selected when `data_location` does not match
`docs\.google\.com`. It reads `entries.csv`, `language_skills.csv`,
`text_blocks.csv`, and `contact_info.csv` with `skip = 1`.

## Design

### 1. Refresh script — `R/refresh_data.R`

Run by hand when publications change. Never runs during a site build.

- Reads the four Sheet tabs and writes them to `data/*.csv`, committed to the
  repo. CSVs are written in the `skip = 1` shape the existing loader expects, so
  `create_CV_object()` needs no change.
- Parses each publication `title` blob into additive columns: `pub_authors`,
  `pub_title`, `pub_venue`, `pub_year`, `pub_doi`.
- `pub_doi` comes from an inline `doi:` in the blob when present, otherwise from
  the `loc` column, which Kevin fills in the Sheet with a DOI URL per paper.
- The original `title` blob is preserved unchanged. The `CV/` documents read it,
  and must keep working. All new columns are additive.
- The script prints the parsed table so a human can eyeball the split before
  committing.

The build reads only `data/*.csv`. It performs no network I/O.

### 2. Publication renderer — `R/publications.R`

One function, `render_publications(cv, n = NULL)`, called by both pages so the
two lists cannot drift apart.

- Groups papers by year, descending. Emits a year heading, then per paper:
  the author line with `Stachelek, K.` bolded, the title as a link to the DOI
  (plain text when no DOI exists yet), and the venue in italics.
- `n` limits output to the most recent N papers. The homepage passes `n = 3`.

### 3. Publications page — `research.Rmd`

- `data_location` switches from the Sheet URL to `"data/"`.
- DT is removed, along with the `thead` / `table.dataTable` CSS that only existed
  to style it and the JS chunk that retargeted PDF links in that table.
- The publications section calls `render_publications(CV)`.
- Presentations and Other Publications sections are unchanged.

### 4. Homepage — `index.Rmd`

The postcards card stays. Below it:

- A positioning paragraph of two to three sentences on what Kevin works on.
  Claude drafts it from the publication record; Kevin edits. No invented claims.
- A Selected Publications block: `render_publications(CV, n = 3)`.
- Links to the CV and to the full publications page.

### 5. Blog reframed as Notes

Navbar text and the `posts.Rmd` title become "Notes". The `href` stays
`posts.html`, so no existing link breaks. No posts are written or deleted.

## Verification

Rebuild with `Rscript R/build_site.R`, then confirm:

- All ten publications render, not ten-of-N behind pagination.
- No `datatables` directory under `docs/site_libs`.
- Every DOI link resolves.
- The build makes no request to `docs.google.com`.
- `docs/AGENTS.html` and `docs/CLAUDE.html` are still absent.

## Out of scope

Writing new posts. Redesigning the theme. Enabling search. Adding figure
thumbnails to publications.
