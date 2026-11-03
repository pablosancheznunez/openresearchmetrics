# Mirrors src/engine.js. Both must produce identical reports for the same
# input; the tests compare the R report with tests/regression/carberry.json.
#
# Every procedure is tied to the methodology_version it implements. A catalog
# card whose version has no matching procedure is refused, so a definition can
# never change without its code.

publication_types <- c("article", "review", "book", "book-chapter", "conference-paper")

has <- function(e, field, values) isTRUE(e[[field]] %in% values)
is_publication <- function(e) has(e, "source", "openalex") && has(e, "type", publication_types)
is_data_or_software <- function(e) {
  has(e, "source", "datacite") && has(e, "type", c("Dataset", "Software", "ComputationalNotebook"))
}
keep <- function(ev, f) Filter(f, ev)

# Each procedure returns list(numerator = items, denominator = items or NULL).
procedures <- list(
  "oa-publications-share@1.0.0" = function(ev) {
    pubs <- keep(ev, is_publication)
    list(numerator = keep(pubs, function(e) isTRUE(e$is_oa)), denominator = pubs)
  },
  "oa-repository-share@1.0.0" = function(ev) {
    pubs <- keep(ev, is_publication)
    list(numerator = keep(pubs, function(e) isTRUE(e$repository_fulltext)), denominator = pubs)
  },
  "openaire-open-access-right-share@1.0.0" = function(ev) {
    all <- keep(ev, function(e) has(e, "source", "openaire"))
    list(numerator = keep(all, function(e) has(e, "access_right", "OPEN ACCESS")), denominator = all)
  },
  "datasets-shared@1.0.0" = function(ev) {
    list(numerator = keep(ev, function(e) has(e, "source", "datacite") && has(e, "type", "Dataset")),
         denominator = NULL)
  },
  "software-shared@1.0.0" = function(ev) {
    list(numerator = keep(ev, function(e) {
      has(e, "source", "datacite") && has(e, "type", c("Software", "ComputationalNotebook"))
    }), denominator = NULL)
  },
  "shared-outputs-cited-share@1.0.0" = function(ev) {
    shared <- keep(ev, is_data_or_software)
    list(numerator = keep(shared, function(e) (e$citations %||% 0) > 0), denominator = shared)
  },
  "data-software-per-publication@1.0.0" = function(ev) {
    list(numerator = keep(ev, is_data_or_software), denominator = keep(ev, is_publication))
  },
  "preprints-share@1.0.0" = function(ev) {
    all <- keep(ev, function(e) has(e, "source", "openalex"))
    list(numerator = keep(all, function(e) has(e, "type", "preprint")), denominator = all)
  },
  "study-registrations@1.0.0" = function(ev) {
    list(numerator = keep(ev, function(e) has(e, "source", "datacite") && has(e, "type", "StudyRegistration")),
         denominator = NULL)
  }
)

procedure_key <- function(indicator) paste0(indicator$id, "@", indicator$methodology_version)

# Math.round(x * 1000) / 1000, as in the web tool (halves round up).
round3 <- function(x) floor(x * 1000 + 0.5) / 1000

compute_indicator <- function(indicator, evidence, consulted) {
  procedure <- procedures[[procedure_key(indicator)]]
  if (is.null(procedure)) stop("No procedure implements ", procedure_key(indicator), call. = FALSE)
  base <- list(id = indicator$id, family = indicator$family,
               methodology_version = indicator$methodology_version)
  ok <- vapply(Filter(function(c) isTRUE(c$ok), consulted), function(c) c$source, "")
  failed <- setdiff(unlist(indicator$sources), ok)
  empty <- function(reason, numerator = NULL, denominator = NULL) {
    c(base, list(status = "unverifiable", reason = reason, value = NULL, numerator = numerator,
                 denominator = denominator, evidence = list()))
  }
  if (length(failed)) return(empty(paste0("Source unavailable: ", paste(failed, collapse = ", "))))
  r <- procedure(evidence)
  n <- length(r$numerator)
  if (is.null(r$denominator)) {
    return(c(base, list(status = "computed", reason = NULL, value = n, numerator = n,
                        denominator = NULL, evidence = r$numerator)))
  }
  d <- length(r$denominator)
  if (d == 0) {
    return(empty("Nothing to count in the sources consulted (denominator is zero).", 0L, 0L))
  }
  c(base, list(status = "computed", reason = NULL, value = round3(n / d), numerator = n,
               denominator = d, evidence = r$numerator))
}

#' Compute the indicators from evidence
#'
#' Applies every indicator of the catalogue to the evidence. The function is
#' pure: the same evidence always gives the same report, which makes an
#' assessment reproducible when its evidence is archived.
#'
#' Each indicator gets a `status`:
#'
#' * `computed`: the value is reported with its numerator, denominator and the
#'   evidence items counted in the numerator;
#' * `unverifiable`: a source it needs failed, or there was nothing to count.
#'   The value is `NULL`, never zero.
#'
#' @param evidence,consulted As returned by [orm_collect()] or
#'   [orm_example_evidence()].
#' @param catalog The catalogue; by default [orm_catalog()].
#' @param orcid The ORCID iD, recorded in the report.
#' @param generated_at Timestamp recorded in the report (ISO 8601, UTC).
#' @return An object of class `orm_report`: a list with the structure of the
#'   web tool's JSON report (schema `orm-report/1`). It has `print()` and
#'   `as.data.frame()` methods; [orm_write_json()] writes it.
#' @export
#' @examples
#' ex <- orm_example_evidence()
#' report <- orm_compute(ex$evidence, ex$consulted, orcid = "0000-0002-1825-0097")
#' report
#' as.data.frame(report)
orm_compute <- function(evidence, consulted, catalog = orm_catalog(), orcid = NULL,
                        generated_at = utc_now()) {
  if (!is.list(catalog) || is.null(catalog$indicators)) stop("`catalog` must come from orm_catalog().", call. = FALSE)
  report <- list(
    schema = "orm-report/1", catalog_version = catalog$catalog_version, orcid = orcid,
    generated_at = generated_at, sources_consulted = consulted,
    indicators = lapply(catalog$indicators, compute_indicator, evidence = evidence, consulted = consulted)
  )
  structure(report, class = "orm_report")
}

#' Collect and compute in one call
#'
#' @param orcid An ORCID iD (bare or as a URL).
#' @param ... Passed to [orm_collect()].
#' @return An `orm_report`; see [orm_compute()].
#' @export
#' @examples
#' \donttest{
#' if (curl::has_internet()) orm_assess("0000-0002-1825-0097")
#' }
orm_assess <- function(orcid, ...) {
  orcid <- bare_orcid(orcid)
  ev <- orm_collect(orcid, ...)
  orm_compute(ev$evidence, ev$consulted, orcid = orcid)
}

#' @export
as.data.frame.orm_report <- function(x, ...) {
  null_na <- function(v, na) if (is.null(v)) na else v
  do.call(rbind, lapply(x$indicators, function(r) {
    data.frame(indicator = r$id, family = r$family, status = r$status,
               value = null_na(r$value, NA_real_), numerator = null_na(r$numerator, NA_integer_),
               denominator = null_na(r$denominator, NA_integer_),
               methodology_version = r$methodology_version, reason = null_na(r$reason, NA_character_),
               stringsAsFactors = FALSE)
  }))
}

#' @export
print.orm_report <- function(x, ...) {
  cat("OpenResearchMetrics report (catalogue ", x$catalog_version, ")\n", sep = "")
  if (!is.null(x$orcid)) cat("ORCID iD: ", x$orcid, "\n", sep = "")
  cat("Sources: ", paste(vapply(x$sources_consulted, function(c) {
    paste0(c$source, if (isTRUE(c$ok)) "" else " (failed)")
  }, ""), collapse = ", "), "\n\n", sep = "")
  for (r in x$indicators) {
    shown <- if (r$status == "unverifiable") {
      paste0("unverifiable: ", r$reason)
    } else if (is.null(r$denominator)) {
      as.character(r$value)
    } else {
      paste0(r$value, " (", r$numerator, "/", r$denominator, ")")
    }
    cat(sprintf("  %-36s %s\n", r$id, shown))
  }
  cat("\nEach indicator stands alone; there is no composite score.\n")
  invisible(x)
}

#' Write a report as JSON
#'
#' Writes the report in the web tool's format, so that a report made in R can
#' be read by the web tool and vice versa.
#'
#' @param report An `orm_report`.
#' @param path File to write.
#' @return `path`, invisibly.
#' @export
#' @examples
#' ex <- orm_example_evidence()
#' report <- orm_compute(ex$evidence, ex$consulted)
#' orm_write_json(report, tempfile(fileext = ".json"))
orm_write_json <- function(report, path) {
  if (!inherits(report, "orm_report")) stop("`report` must come from orm_compute().", call. = FALSE)
  jsonlite::write_json(unclass(report), path, auto_unbox = TRUE, null = "null", na = "null",
                       digits = NA, pretty = TRUE)
  invisible(path)
}
