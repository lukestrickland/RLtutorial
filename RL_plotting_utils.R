#' Add exposure column: how many times this stimulus pair has been shown
#' to each subject up to and including each trial.
#'
#' Stimuli are identified by the sorted combination of s_left and s_right,
#' so order doesn't matter (s_D+s_e == s_e+s_D).
#'
#' @param df Data frame containing `subjects`, `s_left`, `s_right`.
#' @return integer vector `exposure`
get_exposure <- function(df) {
  stimulus_id <- apply(df[, c("s_left", "s_right")], 1, function(x) {
    paste(sort(x), collapse = "_")
  })
  if('postn' %in% names(df)) {
    exposure <- ave(rep(1, nrow(df)), df$postn, df$subjects, stimulus_id, FUN = cumsum)
  } else {
    exposure <- ave(rep(1, nrow(df)), df$subjects, stimulus_id, FUN = cumsum)
  }
  exposure
}

#' @param dat       Data frame of observed data.
#' @param pp        Data frame of posterior predictive samples (must contain a
#'                  `postn` column identifying the posterior draw).
#' @param x.var     Character. Column name to use as the x-axis. The column
#'                  must already exist in both `dat` and `pp` before calling
#'                  (e.g. add `exposure` via `get_exposure()` first).
#' @param acc.var   Character or NULL. Column name for the accuracy variable.
#'                  If NULL (default), accuracy is computed internally as
#'                  `S == R`. If provided, the column must already exist in
#'                  both `dat` and `pp`.
#' @param row.factor Character or NULL. If supplied, a column name whose levels
#'                  each produce one row of panels (accuracy | correct RT |
#'                  error RT). If NULL a single row is produced.
#' @param xlim      Numeric length-2. x-axis limits (passed to all panels).
#'                  Defaults to the observed range of `x.var`.
#' @param acc.ylim  Numeric length-2. y-axis limits for accuracy panels.
#'                  Default c(0.4, 0.9).
#' @param n.breaks  Integer. Number of breaks used when `x.var` is `"bin"` and
#'                  the bin column needs to be created from a `trials` column.
#'                  Ignored when the column already exists. Default 10.
plot_learning <- function(dat, pp, x.var, acc.var = NULL, row.factor = NULL, 
                          xlim = NULL, acc.ylim = c(0.4, 0.9), n.breaks = 10,
                          set.par = TRUE) {
  
  ## ── 0. Resolve accuracy column ────────────────────────────────────────────
  if (is.null(acc.var)) {
    dat$accuracy <- dat$S == dat$R
    pp$accuracy  <- pp$S  == pp$R
    acc.var <- "accuracy"
  } else {
    if (!acc.var %in% colnames(dat))
      stop(sprintf("acc.var '%s' not found in dat.", acc.var))
    if (!acc.var %in% colnames(pp))
      stop(sprintf("acc.var '%s' not found in pp.", acc.var))
  }
  
  ## ── 1. Resolve x.var ──────────────────────────────────────────────────────
  if (!x.var %in% colnames(dat))
    stop(sprintf("x.var '%s' not found in dat.", x.var))
  if (!x.var %in% colnames(pp))
    stop(sprintf("x.var '%s' not found in pp.", x.var))
  if (!is.null(n.breaks)) {
    dat[[x.var]] <- ave(dat[[x.var]], dat$subjects,
                        FUN = function(x) as.numeric(cut(x, breaks = n.breaks)))
    pp[[x.var]]  <- ave(pp[[x.var]], pp$subjects,
                        FUN = function(x) as.numeric(cut(x, breaks = n.breaks)))
  }
  ## ── 2. Determine row levels ────────────────────────────────────────────────
  if (!is.null(row.factor)) {
    if (!row.factor %in% colnames(dat)) stop(sprintf("row.factor '%s' not found in dat.", row.factor))
    row.levels <- sort(unique(dat[[row.factor]]))
  } else {
    row.levels <- NULL
  }
  n.rows <- max(1L, length(row.levels))
  
  ## ── 3. x limits ───────────────────────────────────────────────────────────
  if (is.null(xlim)) xlim <- range(dat[[x.var]], na.rm = TRUE)
  
  ## ── 4. Set up plot layout ─────────────────────────────────────────────────
  if(set.par) par(mfrow = c(n.rows, 3))
  
  ## ── 5. Helper: aggregate one row's worth of data ──────────────────────────
  .agg_row <- function(d, p, x.var, acc.var) {
    
    ## Accuracy
    aggAccS <- aggregate(
      as.formula(paste(acc.var, "~ subjects *", x.var)), d, mean)
    aggAccG <- aggregate(
      as.formula(paste(acc.var, "~", x.var)), aggAccS, mean)
    
    ppaggAccS <- aggregate(
      as.formula(paste(acc.var, "~ subjects *", x.var, "* postn")), p, mean)
    ppaggAccG <- aggregate(
      as.formula(paste(acc.var, "~", x.var, "* postn")), ppaggAccS, mean)
    ppaggAcc  <- aggregate(
      as.formula(paste(acc.var, "~", x.var)), ppaggAccG,
      quantile, c(0.025, 0.5, 0.975))
    
    ## RT
    aggRTS <- aggregate(
      as.formula(paste("rt ~ subjects *", x.var, "*", acc.var)),
      d, quantile, c(0.1, 0.5, 0.9))
    aggRTG <- aggregate(
      as.formula(paste("rt ~", x.var, "*", acc.var)),
      aggRTS, mean)
    
    pphasrt <- !all(is.na(p$rt))
    ppaggRT <- NULL
    if (pphasrt) {
      ppaggRTS <- aggregate(
        as.formula(paste("rt ~ subjects *", x.var, "*", acc.var, "* postn")),
        p, quantile, c(0.1, 0.5, 0.9))
      ppaggRTG <- aggregate(
        as.formula(paste("rt ~", x.var, "*", acc.var, "* postn")),
        ppaggRTS, mean)
      ppaggRT  <- aggregate(
        as.formula(paste("cbind(`10%`,`50%`,`90%`) ~", x.var, "*", acc.var)),
        ppaggRTG, quantile, c(0.025, 0.5, 0.975))
    }
    
    list(aggAccG  = aggAccG,
         ppaggAcc = ppaggAcc,
         aggRTG   = aggRTG,
         ppaggRT  = ppaggRT,
         pphasrt  = pphasrt)
  }
  
  ## ── 6. Helper: draw one row of panels ─────────────────────────────────────
  .draw_row <- function(agg, x.var, acc.var, xlim, acc.ylim, row.label = NULL) {
    
    aggAccG  <- agg$aggAccG
    ppaggAcc <- agg$ppaggAcc
    aggRTG   <- agg$aggRTG
    ppaggRT  <- agg$ppaggRT
    pphasrt  <- agg$pphasrt
    
    ## Panel 1 – Accuracy ──────────────────────────────────────────────────────
    plot(0, 0, type = "n",
         xlim = xlim, ylim = acc.ylim,
         xlab = x.var, ylab = "Accuracy",
         main = if (!is.null(row.label)) as.character(row.label) else "")
    abline(h = seq(0, 1, 0.1), col = "lightgray", lty = 2)
    
    pp.x <- ppaggAcc[[x.var]]
    polygon(c(pp.x, rev(pp.x)),
            c(ppaggAcc[[acc.var]][, 1], rev(ppaggAcc[[acc.var]][, 3])),
            col = adjustcolor(2, alpha.f = 0.3), border = FALSE)
    lines(aggAccG[[x.var]], aggAccG[[acc.var]], lwd = 1.5)
    points(aggAccG[[x.var]], aggAccG[[acc.var]], pch = 19, lwd = 1.5)
    
    ## Panels 2 & 3 – RT (correct / error) ────────────────────────────────────
    for (acc.val in c(1, 0)) {
      
      d.sub  <- aggRTG[aggRTG[[acc.var]] == acc.val, ]
      pp.sub <- if (pphasrt) ppaggRT[ppaggRT[[acc.var]] == acc.val, ] else NULL
      
      if (pphasrt) {
        ylim <- range(c(pp.sub[, 3:5], d.sub[, grep("^rt", colnames(d.sub))]),
                      na.rm = TRUE)
      } else {
        ylim <- range(d.sub[, grep("^rt", colnames(d.sub))], na.rm = TRUE)
      }
      
      plot(0, 0, type = "n",
           xlim = xlim, ylim = ylim,
           xlab = x.var, ylab = "RT (s)",
           main = if (acc.val == 1) "Correct" else "Error")
      abline(h = seq(0, ceiling(ylim[2]), 0.1), col = "lightgray", lty = 2)
      
      for (q_ in c("10%", "50%", "90%")) {
        if (pphasrt) {
          pp.x <- pp.sub[[x.var]]
          polygon(c(pp.x, rev(pp.x)),
                  c(pp.sub[[q_]][, "2.5%"], rev(pp.sub[[q_]][, "97.5%"])),
                  col = adjustcolor(2, alpha.f = 0.3), border = FALSE)
        }
        lines(d.sub[[x.var]],  d.sub[, q_], lwd = 1.5)
        points(d.sub[[x.var]], d.sub[, q_], pch = 19, lwd = 1.5)
      }
    }
  }
  
  ## ── 7. Loop over rows ─────────────────────────────────────────────────────
  if (is.null(row.levels)) {
    agg <- .agg_row(dat, pp, x.var, acc.var)
    .draw_row(agg, x.var, acc.var, xlim, acc.ylim)
  } else {
    for (lv in row.levels) {
      d.sub <- dat[dat[[row.factor]] == lv, ]
      p.sub <- pp[pp[[row.factor]]  == lv, ]
      agg   <- .agg_row(d.sub, p.sub, x.var, acc.var)
      .draw_row(agg, x.var, acc.var, xlim, acc.ylim, row.label = lv)
    }
  }
  
  invisible(NULL)
}

## RL functions
plot_exp1 <- function(dat, pp, do.par=TRUE) {
  dat$accuracy <- dat$S==dat$R
  pp$accuracy <- pp$S==pp$R

  ## Aggregations for Exp 1
  if(!'trials' %in% colnames(dat)) dat <- EMC2:::add_trials(dat)

  # dat$bin <- dat$trialBin #as.numeric(cut(dat$trials, breaks=10))
  # pp$bin <- pp$trialBin #as.numeric(cut(pp$trials, breaks=10))
  dat$bin <- as.numeric(cut(dat$trials, breaks=10))
  pp$bin <- as.numeric(cut(pp$trials, breaks=10))

  # Part 1. Plot fit
  aggAccS <- aggregate(accuracy~subjects*bin, dat, mean)
  aggAccG <- aggregate(accuracy~bin, aggAccS, mean)
  
  aggRTS <- aggregate(rt~subjects*bin*accuracy, dat,quantile, c(0.1,.5,.9))
  aggRTG <- aggregate(rt~bin*accuracy, aggRTS, mean)

  # pp
  ppaggAccS <- aggregate(accuracy~subjects*bin*postn, pp, mean)
  ppaggAccG <- aggregate(accuracy~bin*postn, pp, mean)
  ppaggAcc <- aggregate(accuracy~bin, ppaggAccG, quantile, c(0.025, 0.5, 0.975))
  
  pphasrt <- !all(is.na(pp$rt))
  if(pphasrt) {
    ppaggRTS <- aggregate(rt~subjects*bin*accuracy*postn, pp, quantile, c(0.1,.5,.9))
    ppaggRTG <- aggregate(rt~bin*accuracy*postn, ppaggRTS, mean)
    ppaggRT <- aggregate(cbind(`10%`,`50%`,`90%`)~bin*accuracy, ppaggRTG, quantile, c(0.025, 0.5, 0.975))
  }
  
  ## plot: 1. accuracy
  if(do.par) par(mfrow=c(1,3))
  plot(0,0,type='n', xlim=c(1,10), ylim=c(0.4,.9), ylab='', xlab='Trial bin', main='')#, xaxt=ifelse(condition_=='SPD', 's', 'n'))
  abline(h=seq(0,1,.1), col='lightgray', lty=2)
  polygon(c(1:10, 10:1), c(ppaggAcc$accuracy[,1],rev(ppaggAcc$accuracy[,3])),col=adjustcolor(2, alpha.f=.3), border = FALSE)
  lines(aggAccG$bin, aggAccG$accuracy, lwd=1.5)
  points(aggAccG$bin, aggAccG$accuracy, pch=19, lwd=1.5)

  # 2. RT (correct)
  if(pphasrt) ylim <- range(c(ppaggRT[,3:5],aggRTG[,3:5])) else ylim <- range(c(aggRTG[,3:5]))
  plot(0,0,type='n', xlim=c(1,10), ylim=ylim, xlab='Trial bin', ylab='RT (s)', main='')#, xaxt=ifelse(condition_=='SPD', 's', 'n'))
  abline(h=seq(0,2,.1), col='lightgray', lty=2)
  for(quantile_ in c('10%', '50%', '90%')) {
    if(pphasrt) {
      polygon(c(1:10, 10:1), c(ppaggRT[ppaggRT$accuracy==1,quantile_][,'2.5%'],
                               rev(ppaggRT[ppaggRT$accuracy==1,quantile_][,'97.5%'])),
              col=adjustcolor(2, alpha.f=.3), border = FALSE)
    }

    lines(aggRTG$bin[aggRTG$accuracy==1], aggRTG[aggRTG$accuracy==1, quantile_], lwd=1.5) # data
    points(aggRTG$bin[aggRTG$accuracy==1], aggRTG[aggRTG$accuracy==1, quantile_], pch=19, lwd=1.5) # data
  }

  if(pphasrt) ylim <- range(c(ppaggRT[,3:5],aggRTG[,3:5])) else ylim <- range(c(aggRTG[,3:5]))
  plot(0,0,type='n', xlim=c(1,10), ylim=ylim, xlab='Trial bin', ylab='RT (s)', main='')#, xaxt=ifelse(condition_=='SPD', 's', 'n'))
  abline(h=seq(0,2,.1), col='lightgray', lty=2)
  for(quantile_ in c('10%', '50%', '90%')) {
    if(pphasrt) {
      polygon(c(1:10, 10:1), c(ppaggRT[ppaggRT$accuracy==0,quantile_][,'2.5%'],
                               rev(ppaggRT[ppaggRT$accuracy==0,quantile_][,'97.5%'])),
              col=adjustcolor(2, alpha.f=.3), border = FALSE)
    }
    
    lines(aggRTG$bin[aggRTG$accuracy==0], aggRTG[aggRTG$accuracy==0, quantile_], lwd=1.5) # data
    points(aggRTG$bin[aggRTG$accuracy==0], aggRTG[aggRTG$accuracy==0, quantile_], pch=19, lwd=1.5) # data
  }
}


plot_revl <- function(dat, pp, plot_all_RT_quantiles=TRUE,xlim=c(-30,30)) {
  dat$RS <- RS(dat)
  dat$Racc <- dat$chosen_symbol_was_correct_prereversal <- Smatch_prereversal(dat)
  pp$RS <- RS(pp)
  pp$Racc <- pp$chosen_symbol_was_correct_prereversal <- Smatch_prereversal(pp)
  
  ##
  nReversals <- sum(grepl('trialNrelativetoreversal', colnames(dat)))
  par(mfcol=c(2,nReversals))
  for(i in 1:nReversals) {
    dat$trialNreversal <- dat[,paste0('trialNrelativetoreversal',i)]
    pp$trialNreversal <- pp[,paste0('trialNrelativetoreversal',i)]
  
    aggRT <- aggregate(rt~trialNreversal,dat,quantile, c(.1, .5,.9))
    aggRTpp <- aggregate(rt~trialNreversal, aggregate(rt~trialNreversal*postn, pp, quantile, c(.1, .5, .9)), quantile, c(.025, .5,.975))
  
    aggChoice <- aggregate(Racc~trialNreversal,dat,mean)
    aggChoicepp <- aggregate(Racc~trialNreversal, aggregate(Racc~trialNreversal*postn,pp,mean), quantile, c(0.025, .5, .975))
  
    plot(aggChoice$trialNreversal, aggChoice$Racc, type='b', lwd=2, ylab='Choice = accurate prerev', xlab='Trial N (relative to reversal)',xlim=xlim, main=paste0('Reversal ', i))
    polygon(c(aggChoicepp$trialNreversal, rev(aggChoicepp$trialNreversal)),
            c(aggChoicepp$Racc[,1], rev(aggChoicepp$Racc[,3])), col=adjustcolor(2, alpha.f=.4))
    abline(v=0, lty=2)
    
    
    ## RTs: median
    if(plot_all_RT_quantiles) {
      ylim <- range(c(aggRT$rt[,2], quantile(as.matrix(aggRTpp[,-1]), c(0.025, .975))))
    } else {
      ylim <- range(c(aggRT$rt[,2], aggRTpp$`50%`))
    }
    plot(aggRT$trialNreversal, aggRT$rt[,2], type='b', lwd=2, ylab='RT (s)', xlab='Trial N (relative to reversal)', ylim=ylim, xlim=xlim)
    polygon(c(aggRTpp$trialNreversal, rev(aggRTpp$trialNreversal)),
            c(aggRTpp$`50%`[,1], rev(aggRTpp$`50%`[,3])), col=adjustcolor(2, alpha.f=.4))
    abline(v=0, lty=2)
    
    if(plot_all_RT_quantiles) {
      # and 10th, 90th quantile
      points(aggRT$trialNreversal, aggRT$rt[,1], type='b', lwd=2)
      points(aggRT$trialNreversal, aggRT$rt[,3], type='b', lwd=2)
      polygon(c(aggRTpp$trialNreversal, rev(aggRTpp$trialNreversal)),
              c(aggRTpp$`10%`[,1], rev(aggRTpp$`10%`[,3])), col=adjustcolor(2, alpha.f=.4))
      polygon(c(aggRTpp$trialNreversal, rev(aggRTpp$trialNreversal)),
              c(aggRTpp$`90%`[,1], rev(aggRTpp$`90%`[,3])), col=adjustcolor(2, alpha.f=.4))
    }
  }
}


## RL functions
plot_exp3 <- function(dat, pp, do.par=TRUE) {
  dat$accuracy <- dat$S==dat$R
  pp$accuracy <- pp$S==pp$R
  
  ## Aggregations for Exp 1
  if(!'trials' %in% colnames(dat)) dat <- EMC2:::add_trials(dat)
  
  # dat$bin <- dat$trialBin #as.numeric(cut(dat$trials, breaks=10))
  # pp$bin <- pp$trialBin #as.numeric(cut(pp$trials, breaks=10))
  if('trial_bin' %in% names(dat)) {
    dat$bin <- dat$trial_bin
    pp$bin <- pp$trial_bin
  }
  # dat$bin <- as.numeric(cut(dat$trials, breaks=10))
  # pp$bin <- as.numeric(cut(pp$trials, breaks=10))
  
  # Part 1. Plot fit
  aggAccS <- aggregate(accuracy~subjects*bin, dat, mean)
  aggAccG <- aggregate(accuracy~bin, aggAccS, mean)
  
  aggRTS <- aggregate(rt~subjects*bin*accuracy, dat,quantile, c(0.1,.5,.9))
  aggRTG <- aggregate(rt~bin*accuracy, aggRTS, mean)
  
  # pp
  ppaggAccS <- aggregate(accuracy~subjects*bin*postn, pp, mean)
  ppaggAccG <- aggregate(accuracy~bin*postn, pp, mean)
  ppaggAcc <- aggregate(accuracy~bin, ppaggAccG, quantile, c(0.025, 0.5, 0.975))
  
  pphasrt <- !all(is.na(pp$rt))
  if(pphasrt) {
    ppaggRTS <- aggregate(rt~subjects*bin*accuracy*postn, pp, quantile, c(0.1,.5,.9))
    ppaggRTG <- aggregate(rt~bin*accuracy*postn, ppaggRTS, mean)
    ppaggRT <- aggregate(cbind(`10%`,`50%`,`90%`)~bin*accuracy, ppaggRTG, quantile, c(0.025, 0.5, 0.975))
  }
  
  ## plot: 1. accuracy
  if(do.par) par(mfrow=c(1,3))
  plot(0,0,type='n', xlim=c(1,10), ylim=c(0.4,.9), ylab='', xlab='Trial bin', main='')#, xaxt=ifelse(condition_=='SPD', 's', 'n'))
  abline(h=seq(0,1,.1), col='lightgray', lty=2)
  polygon(c(1:10, 10:1), c(ppaggAcc$accuracy[,1],rev(ppaggAcc$accuracy[,3])),col=adjustcolor(2, alpha.f=.3), border = FALSE)
  lines(aggAccG$bin, aggAccG$accuracy, lwd=1.5)
  points(aggAccG$bin, aggAccG$accuracy, pch=19, lwd=1.5)
  
  # 2. RT (correct)
  if(pphasrt) ylim <- range(c(ppaggRT[,3:5],aggRTG[,3:5])) else ylim <- range(c(aggRTG[,3:5]))
  plot(0,0,type='n', xlim=c(1,10), ylim=ylim, xlab='Trial bin', ylab='RT (s)', main='')#, xaxt=ifelse(condition_=='SPD', 's', 'n'))
  abline(h=seq(0,2,.1), col='lightgray', lty=2)
  for(quantile_ in c('10%', '50%', '90%')) {
    if(pphasrt) {
      polygon(c(1:10, 10:1), c(ppaggRT[ppaggRT$accuracy==1,quantile_][,'2.5%'],
                               rev(ppaggRT[ppaggRT$accuracy==1,quantile_][,'97.5%'])),
              col=adjustcolor(2, alpha.f=.3), border = FALSE)
    }
    
    lines(aggRTG$bin[aggRTG$accuracy==1], aggRTG[aggRTG$accuracy==1, quantile_], lwd=1.5) # data
    points(aggRTG$bin[aggRTG$accuracy==1], aggRTG[aggRTG$accuracy==1, quantile_], pch=19, lwd=1.5) # data
  }
  
  if(pphasrt) ylim <- range(c(ppaggRT[,3:5],aggRTG[,3:5])) else ylim <- range(c(aggRTG[,3:5]))
  plot(0,0,type='n', xlim=c(1,10), ylim=ylim, xlab='Trial bin', ylab='RT (s)', main='')#, xaxt=ifelse(condition_=='SPD', 's', 'n'))
  abline(h=seq(0,2,.1), col='lightgray', lty=2)
  for(quantile_ in c('10%', '50%', '90%')) {
    if(pphasrt) {
      polygon(c(1:10, 10:1), c(ppaggRT[ppaggRT$accuracy==0,quantile_][,'2.5%'],
                               rev(ppaggRT[ppaggRT$accuracy==0,quantile_][,'97.5%'])),
              col=adjustcolor(2, alpha.f=.3), border = FALSE)
    }
    
    lines(aggRTG$bin[aggRTG$accuracy==0], aggRTG[aggRTG$accuracy==0, quantile_], lwd=1.5) # data
    points(aggRTG$bin[aggRTG$accuracy==0], aggRTG[aggRTG$accuracy==0, quantile_], pch=19, lwd=1.5) # data
  }
}
