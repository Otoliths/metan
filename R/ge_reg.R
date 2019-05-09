#' Eberhart and Russell's regression model
#'
#' Regression-based stability analysis using the Eberhart and Russell (1966) model.
#'
#' @param .data The dataset containing the columns related to Environments, Genotypes,
#'              replication/block and response variable(s)
#' @param env The name of the column that contains the levels of the
#' environments.
#' @param gen The name of the column that contains the levels of the genotypes.
#' @param rep The name of the column that contains the levels of the
#' replications/blocks
#' @param resp The response variable(s). To analyze multiple variables in a
#' single procedure use, for example, \code{resp = c(var1, var2, var3)}.
#' @param verbose Logical argument. If \code{verbose = FALSE} the code will run silently.
#'
#' @author Tiago Olivoto, \email{tiagoolivoto@@gmail.com}
#' @export
#' @examples
#' library(METAAB)
#'reg = ge_reg(data_ge2,
#'             env = ENV,
#'             gen = GEN,
#'             rep = REP,
#'             resp = PH)
#'plot(reg)
#'
#' @seealso \code{\link{superiority}, \link{ecovalence}, \link{ge_stats}}
#'
#' @references Eberhart, S.A., and W.A. Russell. 1966. Stability parameters for comparing Varieties.
#' Crop Sci. 6:36-40. \href{https://www.crops.org/publications/cs/abstracts/6/1/CS0060010036}{doi:10.2135/cropsci1966.0011183X000600010011x}.

ge_reg = function(.data,
                  env,
                  gen,
                  rep,
                  resp,
                  verbose = TRUE){
  datain <- .data
  GEN <- factor(eval(substitute(gen), eval(datain)))
  ENV <- factor(eval(substitute(env), eval(datain)))
  REP <- factor(eval(substitute(rep), eval(datain)))
  listres <- list()
  d <- match.call()
  nvar <- as.numeric(ifelse(length(d$resp) > 1, length(d$resp) - 1, length(d$resp)))
  for (var in 2:length(d$resp)) {
    if (length(d$resp) > 1) {
      Y <- eval(substitute(resp)[[var]], eval(datain))
      varnam = paste(d$resp[var])
    } else {
      Y <- eval(substitute(resp), eval(datain))
      varnam = paste(d$resp)
    }
    data <- data.frame(ENV, GEN, REP, Y)
    names(data) = c("ENV", "GEN", "REP", "mean")
    data2 =  data  %>%
      dplyr::group_by(ENV, GEN) %>%
      dplyr::summarise(mean = mean(mean)) %>%
      as.data.frame()
    model1 <- lm(mean ~ GEN + ENV + ENV/REP + ENV * GEN, data = data)
    modav <- anova(model1)
    mydf = data.frame(aggregate(mean ~ GEN + ENV, data = data, mean))
    myAgg = aggregate(mean ~ GEN, mydf, "c")
    iamb = data.frame(aggregate(mean ~ ENV, data = data, mean))
    iamb = dplyr::mutate(iamb, IndAmb = mean - mean(mean))
    iamb2 = data.frame(aggregate(mean ~ ENV + GEN, data = data, mean))
    iamb2 = suppressMessages(dplyr::mutate(iamb2,
                                           IndAmb = dplyr::left_join(iamb2, iamb %>% select(ENV, IndAmb))$IndAmb))
    matx <- myAgg$mean
    myAgg$GEN
    meandf = data.frame(GEN = myAgg$GEN, myAgg$mean)
    names(meandf) = c("GEN", levels(mydf$ENV))
    gradyt = mean(matx)
    iij = apply(matx, 2, mean) - gradyt
    sqiij = sum((iij)^2)
    YiIj = matx %*% iij
    bij = YiIj/sqiij
    svar = (apply(matx^2, 1, sum)) - (((apply(matx, 1, sum))^2)/ncol(matx))
    bYijIj = bij * YiIj
    dij = svar - bYijIj
    devtab <- data.frame(GEN = meandf$GEN, svar, bij, YiIj, bYijIj, dij)
    S2e = modav$"Mean Sq"[5]
    rps = length(levels(data$REP))
    en = length(levels(data$ENV))
    S2di = (dij/(en - 2)) - (S2e/rps)
    data2 = data2
    model2 <- lm(mean ~ GEN + ENV, data = data2)
    amod2 <- anova(model2)
    SSL = amod2$"Sum Sq"[2]
    SSGxL = amod2$"Sum Sq"[3]
    SS.L.GxL = SSL + SSGxL
    SSL.Linear = (1/length(levels(data$GEN))) * (colSums(matx) %*% iij)^2/sum(iij^2)
    SS.L.GxL.linear = sum(bYijIj) - SSL.Linear
    ge = length(levels(mydf$GEN))
    Df <- c(en * ge - 1, ge - 1, ge * (en - 1), 1, ge - 1, ge * (en - 2),
            replicate(length(dij), en - 2), en * ge * (rps - 1))
    poolerr = modav$"Sum Sq"[5]/rps
    SSS <- c(sum(amod2$"Sum Sq"), amod2$"Sum Sq"[1], SSL + SSGxL,
             SSL.Linear, SS.L.GxL.linear, sum(dij), dij, poolerr) * rps
    MSSS = (SSS/Df)
    FVAL = c(NA, MSSS[2]/MSSS[6], NA, NA, MSSS[5]/MSSS[6], NA,
             MSSS[7:(length(MSSS) - 1)]/MSSS[length(MSSS)], NA)
    PLINES = 1 - pf(FVAL[7:(length(MSSS) - 1)], Df[7], Df[length(Df)])
    pval = c(NA, 1 - pf(FVAL[2], Df[2], Df[6]), NA, NA, 1 -
               pf(FVAL[5], Df[5], Df[6]), NA, PLINES, NA)
    anovadf <- data.frame(Df, `Sum Sq` = SSS, `Mean Sq` = MSSS,
                          `F value` = FVAL, `Pr(>F)` = pval, check.names = FALSE)
    rownames(anovadf) <- c("Total", "GEN", "ENV + (GEN x ENV)", "ENV (linear)",
                           " GEN x ENV (linear)", "Pooled deviation",
                           levels(data$GEN), "Pooled error")
    p = ggplot2::ggplot(iamb2, aes(x = IndAmb, y = mean))+
      ggplot2::geom_point(aes(colour = factor(GEN)), size = 1.5)+
      geom_smooth(aes(colour = factor(GEN)), method = "lm", se = FALSE)+
      ggplot2::theme_bw()+
      ggplot2::labs(x = "Environmental index", y = varnam)+
      ggplot2::theme(axis.ticks.length = unit(.2, "cm"),
                     axis.text = element_text(size = 12, colour = "black"),
                     axis.title = element_text(size = 12, colour = "black"),
                     axis.ticks = element_line(colour = "black"),
                     plot.margin = margin(0.5, 0.5, 0.2, 0.6, "cm"),
                     axis.title.y = element_text(margin = margin(r=16)),
                     legend.title = element_blank(),
                     legend.text = element_text(size=12),
                     panel.border = element_rect(colour = "black", fill=NA, size=1),
                     panel.grid.major.x = element_blank(), panel.grid.major.y = element_blank(),
                     panel.grid.minor.x = element_blank(), panel.grid.minor.y = element_blank())
    temp = list(plot = p,
                anova = anovadf,
                regression = data.frame(GEN = devtab$GEN,
                                        bij = devtab$bij,
                                        sdij = S2di))
    if (length(d$resp) > 1) {
      listres[[paste(d$resp[var])]] <- temp
      if (verbose == TRUE) {
        cat("Evaluating variable", paste(d$resp[var]), round((var - 1)/(length(d$resp) -
                                                                          1) * 100, 1), "%", "\n")
      }
    } else {
      listres[[paste(d$resp)]] <- temp
    }
  }
  return(structure(listres, class = "ge_reg"))
}