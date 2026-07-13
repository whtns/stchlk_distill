use the distill-site skill if available
use the github pages site https://whtns.github.io/stchlk_distill/ instead of the netlify site
build with `Rscript R/build_site.R`, not `render_site()` directly — the wrapper keeps AGENTS.md/CLAUDE.md from being published as site pages