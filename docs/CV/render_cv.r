# This script builds both the HTML and PDF versions of your CV

# If you wanted to speed up rendering for googlesheets driven CVs you could use
# this script to cache a version of the CV_Printer class with data already
# loaded and load the cached version in the .Rmd instead of re-fetching it twice
# for the HTML and PDF rendering. This exercise is left to the reader.

library(here)
# Knit the HTML version
  rmarkdown::render("CV/cv-stachelek.rmd")
  
  file.copy(here("CV", "cv-stachelek.html"),
              here("cv-stachelek.html"), overwrite = T)
 

# Convert to PDF using Pagedown
pagedown::chrome_print(input = "/Users/kevinstachelek/rpkgs/stachelek_distill/cv-stachelek.html",
                       output = here::here("CV", "cv-stachelek.pdf"))

file.copy(here("CV", "cv-stachelek.pdf"),
          here("cv-stachelek.pdf"), overwrite = T)

rmarkdown::render_site(encoding = 'UTF-8')


# CUSTO
# pagedown::chrome_print(input = "/Users/kevinstachelek/rpkgs/stachelek_distill/CV/cv-stachelek-custom.html",
#                        output = here::here("CV", "cv-stachelek-custom.pdf"))
