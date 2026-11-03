#' ORMetrics: transparent open science indicators
#'
#' The R counterpart of the OpenResearchMetrics web tool. Both read the same
#' catalogue (`orm_catalog()`), normalise the same API responses and must
#' produce the same report for the same evidence; the tests compare the R
#' report with the one stored in the web tool's regression test.
#'
#' * [orm_assess()]: collect the evidence for an ORCID iD and compute every
#'   indicator in one call;
#' * [orm_collect()], [orm_compute()]: the two steps separately, so that the
#'   evidence can be archived and the report recomputed offline;
#' * [orm_catalog()], [orm_indicators()]: the indicator cards.
#'
#' Principles: each indicator stands alone and is never added to others; an
#' indicator that cannot be verified is `unverifiable`, never zero; the
#' indicators describe open practices, not research quality.
#'
#' @keywords internal
"_PACKAGE"
