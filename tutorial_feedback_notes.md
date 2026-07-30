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

## Changes made in this fork (2026-07-30, code-review follow-up)

A review of the working-tree changes surfaced several issues; the following
fixes were applied to `tutorial_code.Rmd` (and repo config):

- **`fit_models` reset to `FALSE`** in the setup chunk. It had been flipped to
  `TRUE` for a local refitting run; committing `TRUE` would have reintroduced
  issue 2 above (silent hours-long fitting on a fresh clone, since `cache/` is
  gitignored). Note the switch only affects chunks that actually execute:
  knitr's chunk caches (`cache/pdf/`, `cache/html/`) do not include
  `fit_models` in their cache keys, so forcing a refit requires deleting the
  relevant `./cache/*.RData` file *and* the knitr chunk caches.
- **`rlrd-fit-run` chunk brought in line with the other seven fit chunks**: its
  fit branch was the only one missing `add_ICs_MLL()` + `save()`, so a freshly
  fitted `./cache/exp1_rlrd.RData` lacked the IC/marginal-likelihood
  annotations that the `compare()` table (DIC/BPIC/MD) expects. Caveat: the
  `exp1_rlrd.RData` regenerated on 2026-07-30 was produced by the old code and
  still lacks ICs — delete it and refit (or run `add_ICs_MLL()` + `save()` on
  it manually) before trusting the model-comparison table.
- **Missing-data guard added to `2lr-data-design`**:
  `data/lefebvre2017/lefebvre_exp1.RData` is not in this repo and is also
  absent from the upstream repo (checked via the GitHub API), so with
  `fit_models <- TRUE` a knit previously ran the exp3 SAT fits for hours and
  then crashed at the bare `load()` with an uninformative "cannot open the
  connection". The chunk now stops immediately with an informative message.
  **Resolved (2026-07-30):** `data/lefebvre2017/lefebvre_exp1.RData` was
  reconstructed from the paper's published raw data
  (figshare, https://doi.org/10.6084/m9.figshare.4265408 — `BehavioralData.zip`,
  50 per-subject `.mat` files for experiment 1). Reconstruction details:
  - Columns mapped per the archive's own `Behavioral_Variables.m`: trial,
    condition (1-4), choice (-1/1 → `R` left/right), outcome (0/1 → `reward`),
    RT (ms → s, rounded to 3 dp).
  - Conditions mapped to `p_left`/`p_right` as 25/25, 75/25, 25/75, 75/75.
    Symbol positions are fixed within subject per condition (verified
    behaviorally: mean P(right) in late trials is 0.19 in the 75/25 condition
    and 0.84 in 25/75); symbols named `s1`-`s8` by condition and side.
  - 21 of 4,800 trials dropped (missed/invalid response or RT); no subject
    exclusions applied (none published); `subjects` uses the original IDs from
    the `.mat` `sub` field; `reward` coded 0/1 (with `v.q0 = 0` fixed, reward
    scaling is absorbed by the weight parameter, so learning-rate estimates are
    unaffected by the 0/1 vs 0/0.5-euro choice).
  - Validated by running the `2lr-data-design` chunk end-to-end
    (`design()` + `make_emc()` succeed; covariate columns correct).
  Caveat: the tutorial author's original preprocessing is unknown, so posterior
  values quoted in the prose may not match a refit on this reconstruction
  exactly. The author should ship his own copy of the file (or the
  preprocessing script) in the repo.
- **Two broken `dependson` declarations fixed**: `2lr-fit-run` depended on
  `"rlard-design"` (an exp1 chunk, apparent copy-paste) instead of
  `"2lr-data-design"`, and `confirmation-fit-run` depended on
  `"confirmation-data-design"`, a chunk label that does not exist (now
  `c("confirmation-data-functions", "confirmation-design")`). With
  `cache=TRUE`, both meant edits to the actual upstream design/data chunks
  would not invalidate the cached fits — silently stale results.
- **`RL_plotting_utils.R` now sourced locally** instead of fetched from the
  upstream GitHub raw URL (the only `source()` call in the document). The
  local copy was verified byte-identical to upstream before switching. This
  removes a network dependency from the render path and means local edits to
  the utils actually take effect.
- **`render_messages.log` untracked and gitignored**: it is truncated
  (`open = "wt"`) at the start of every knit and only receives messages from
  non-cached chunks, so its tracked content was nondeterministic churn; the
  95-line convergence record from the last full run remains available in git
  history. (Known minor issue, not yet fixed: the log connection is never
  `close()`d, and knitting both output formats overwrites the first format's
  log.)
- **Confirmation-bias fit refit on correct data (2026-07-30, later):** the
  cached `palminteri2017exp2_cf.RData` produced by the interrupted/restarted
  renders had been fit to the Lefebvre data (see issue 6). It was quarantined
  and refit on the Palminteri data via the tutorial's own chunks; the knitr
  chunk caches (`cache/pdf/`, `cache/html/`) were deleted to clear any stale
  `dat` state, and the final `credint` chunk was pointed at `emc_cf` (issue 5).
- Also noted during review, not yet addressed: posterior values quoted in the
  prose are hard-coded literals (e.g. the ~0.17 / ~0.064 learning rates in the
  2lr section) and fits are unseeded, so any refit can silently drift from the
  text; and the fitted `./cache/*.RData` files live in the same tree as
  knitr's disposable chunk caches, so `rm -rf cache/` destroys hours of fits.

## 3. Stray `cue` contrast in the 2lr design (apparent copy-paste)

- **Where:** chunk `2lr-data-design`, the `design()` call for the Lefebvre two-learning-rates model.
- **Issue:** the call passes `contrasts = list(cue = ADmat)` with an accuracy-minus-speed `ADmat`, but the Lefebvre data has no `cue` column and no formula term uses `cue` (`B ~ 1, v ~ 1, t0 ~ 1`). This appears to be copy-paste from the SAT section. `design()` silently ignores it (verified by running the chunk), so it's harmless, but it's confusing for readers trying to understand which arguments matter.
- **Suggested fix:** drop the `contrasts` argument (and the `ADmat` definition if unused) from this chunk.

## 4. Suggestion: point estimates + coarser binning in the final posterior predictive plot

- **Where:** the confirmation-bias learning plot (chunk `confirmation-pp-run`) and `plot_learning()` in `RL_plotting_utils.R`.
- **Issue (a) — no point estimate:** the posterior predictives are shown only as a 95% credible band, which is wide here, making it hard to judge how well the model's central tendency tracks the data (misfit could sit at the band's edge and be invisible). Notably, `plot_learning()` already computes the posterior predictive median in both panels — the accuracy aggregation takes quantiles `c(0.025, 0.5, 0.975)` and the RT aggregation keeps a `"50%"` column — but only the outer quantiles are ever drawn. Adding the median as a red line in the accuracy and RT panels is a two-line change using values already computed.
- **Issue (b) — thin bins:** the default `n.breaks = 10` over exposure leaves ~2-3 trials per subject per bin for the Palminteri data (20 subjects, ~24 exposures per condition), so both the data line and the credible band are noisy/wide. Aggregating into fewer bins (e.g. 5-6) would make the condition-level learning patterns more readable. Caveat: the fourth condition reverses after 13 trials, so keep enough resolution there for the post-reversal dip to remain visible rather than being averaged away.

## 5. Wrong object in the final `credint` chunk

- **Where:** chunk `factualcounterfactual-credint` (end of the confirmation-bias section).
- **Issue:** the chunk calls `credint(emc, map=TRUE)`, but `emc` is the Lefebvre 2lr fit from the previous section — the last table in the document therefore shows the wrong model's parameters, while the surrounding prose interprets the confirmation-bias interaction (`v.alphaPos`/`v.alphaNeg` by `chosen`). Should be `credint(emc_cf, map=TRUE)`. Fixed locally in this fork.

## 6. Shared global `dat` + `cache=TRUE` produced a fit on the wrong dataset

- **Where:** document-wide design; bit us concretely in `confirmation-fit-run`.
- **What happened:** on a re-knit after edits, the cached confirmation-bias fit turned out to have been fit to the *Lefebvre* data (4,779 rows, 50 subjects) instead of the Palminteri data (3,840 rows, 20 subjects) — discovered only because the posterior predictive plot crashed on the missing `condition_label` column. The fit itself sampled happily on the wrong data with no warning; the corrupted `cache/palminteri2017exp2_cf.RData` was quarantined and refit.
- **Mechanism:** every section loads its dataset into the same global `dat`, and knitr's cache only stores objects a chunk *creates*, not objects it *modifies* (a documented knitr limitation). `confirmation-data-functions` overwrites the pre-existing `dat` via `load()`, so when that chunk is replayed from cache while a chunk from an *earlier* section re-executes (here: the edited `2lr-data-design`), downstream chunks silently see the earlier section's `dat`. Any cross-section edit can trigger this; it will affect other sections the same way.
- **Suggested fix:** give each section its own data object (`dat_exp1`, `dat_sat`, `dat_lef`, `dat_cf`) instead of reusing `dat`; or set `cache=FALSE` on the data-loading chunks; and cheaply assert before each fit (e.g. `stopifnot(nrow(dat) == 3840)`) so a wrong-data fit fails fast instead of sampling for half an hour.

## 7. Suggestion: show the feedback generator in Figure 1

- **Where:** overview figure `fig-rlrd-overview` (tikz chunk ~line 179) and the text introducing it.
- **Issue:** the text enumerates four implementation steps — (1) specify covariates, (2) apply the delta rule, (3) map covariates to drift rates, (4) specify a feedback generator — and says the figure "illustrates how these steps connect", but the figure only depicts steps 1-3 (Data → DADM → covariate coding × delta rule × weight → drift rates). The feedback generator is absent.
- **Suggestion:** add the feedback generator as a dashed feedback arrow (labelled e.g. "`feedback_generator()` — simulation only") from the drift rates / simulated response back to the `rew` column of the data. A plain extra box in the existing chain would be misleading, since the generator isn't part of the fitting data flow (where rewards are observed) — it only closes the choice → reward → delta-rule loop during posterior predictive simulation. The dashed styling keeps that distinction honest; the caption would need a sentence explaining the dashed path.
