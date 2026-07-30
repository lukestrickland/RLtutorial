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
