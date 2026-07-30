# Tutorial feedback notes

Notes on errors/issues found while working through `tutorial_code.Rmd` (from
https://github.com/StevenM1/rl_eam_tutorial), to pass on to the author.

## 1. `data_exp3.RData` missing from the repo (render fails)

- **Where:** chunk `sat-load-data` (line ~792), start of the speed-accuracy trade-off section (Sec. "Factors on parameters").
- **Symptom:** knitting halts with `Error in readChar(): cannot open the connection` from `load('./data/data_exp3.RData')`.
- **Cause:** the repo's `data/` folder only ships `data_exp1.RData` and `palminteri2017_exp2.RData`; `data_exp3.RData` was never committed (presumably present only in the author's local copy, so the shipped PDF/HTML rendered fine).
- **Workaround used:** downloaded the file from the Miletić et al. (2021) OSF repository — https://osf.io/ygrve/ (direct file link: https://osf.io/download/dcv5f/) — into `data/`. The `sat-load-data` chunk then runs cleanly (5,845 rows after exclusions, all expected columns present).
- **Suggested fix:** commit `data_exp3.RData` to the repo's `data/` folder, or add a note/download step in the tutorial pointing at the OSF link.

### Related minor point: `cue` factor levels

The prose in that section says the `cue` column has levels `"accuracy"` and `"speed"`, but the OSF data file uses `"ACC"` and `"SPD"`. The code still works (`as.factor(dat$cue)`, and the accuracy-minus-speed contrast is preserved since `"ACC"` sorts first), but the text and the data don't match.

## 2. Model fitting runs silently during knit

- **Where:** all seven hidden `*-fit-run` chunks (`rlrd`, `rlddm`, `rlard`, `sat` ×2, `2lr`, `2lr-reparam`, `confirmation`).
- **Issue:** each chunk uses `if (file.exists(cacheFile)) load else fit`. Since the repo ships no `cache/` files, a fresh knit silently launches all model fits (each with `cores_per_chain = 5`) as a side effect of rendering the document — hours of sampling with no warning, and a heavy hardware assumption for a tutorial.
- **Workaround used (in this fork):** added a `fit_models <- FALSE` master switch to the setup chunk; each fit chunk now stops with an informative error ("Cached fit not found: ... set fit_models <- TRUE") instead of fitting when its cached fit is missing.
- **Suggested fix:** make fitting an explicit opt-in (e.g. a YAML `params` flag or the same kind of master switch), document the expected runtime and core usage in the text, and/or provide the fitted `cache/` objects for download so readers can knit the document without refitting.
