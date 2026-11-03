# Connectors to OpenAlex, DataCite and the OpenAIRE Graph. They mirror
# src/connectors.js: every evidence item is
# list(source, type, title, year, url, is_oa, oa_status, repository_fulltext,
#      access_right, citations), with NULL for missing values.

orm_sources <- c("openalex", "datacite", "openaire")

`%||%` <- function(a, b) if (is.null(a)) b else a

utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

#' Validate an ORCID iD
#'
#' Checks the format and the ISO 7064 11,2 check digit. The
#' `https://orcid.org/` form is accepted by [orm_collect()] and [orm_assess()].
#'
#' @param id A bare ORCID iD.
#' @return `TRUE` or `FALSE`.
#' @export
#' @examples
#' orm_valid_orcid("0000-0002-1825-0097")
#' orm_valid_orcid("0000-0002-1825-0098")
orm_valid_orcid <- function(id) {
  if (!is.character(id) || length(id) != 1 || is.na(id) ||
      !grepl("^\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]$", id)) return(FALSE)
  digits <- strsplit(gsub("-", "", id), "")[[1]]
  total <- 0
  for (d in digits[1:15]) total <- (total + as.integer(d)) * 2
  check <- (12 - (total %% 11)) %% 11
  digits[16] == if (check == 10) "X" else as.character(check)
}

bare_orcid <- function(id) {
  bare <- sub("^https?://(www\\.)?orcid\\.org/", "", trimws(as.character(id)[1]))
  if (!orm_valid_orcid(bare)) stop("Not a valid ORCID iD: ", id, call. = FALSE)
  bare
}

finite_or_null <- function(x) {
  if (is.numeric(x) && length(x) == 1 && is.finite(x)) x else NULL
}

ev_item <- function(source, type = NULL, title = NULL, year = NULL, url = NULL, is_oa = NULL,
                    oa_status = NULL, repository_fulltext = NULL, access_right = NULL,
                    citations = NULL) {
  list(source = source, type = type, title = title, year = finite_or_null(year), url = url,
       is_oa = is_oa, oa_status = oa_status, repository_fulltext = repository_fulltext,
       access_right = access_right, citations = finite_or_null(citations))
}

#' Normalise API responses into evidence items
#'
#' Turn a parsed JSON response (from `jsonlite::fromJSON(simplifyVector =
#' FALSE)`) into a list of evidence items. These functions do not use the
#' network; [orm_collect()] calls them on live responses.
#'
#' @param json A parsed response of the corresponding API.
#' @return A list of evidence items, each a list with `source`, `type`,
#'   `title`, `year`, `url`, `is_oa`, `oa_status`, `repository_fulltext`,
#'   `access_right` and `citations` (`NULL` when the source does not say).
#' @name normalize
#' @examples
#' ex <- system.file("extdata", "examples", "openalex.json", package = "ORMetrics")
#' items <- orm_normalize_openalex(jsonlite::fromJSON(ex, simplifyVector = FALSE))
#' length(items)
#' str(items[[1]])
NULL

#' @rdname normalize
#' @export
orm_normalize_openalex <- function(json) {
  lapply(json$results %||% list(), function(w) {
    oa <- w$open_access %||% list()
    ev_item("openalex", type = w$type, title = w$title, year = w$publication_year,
            url = w$doi %||% w$id, is_oa = oa$is_oa, oa_status = oa$oa_status,
            repository_fulltext = oa$any_repository_has_fulltext)
  })
}

#' @rdname normalize
#' @export
orm_normalize_datacite <- function(json) {
  lapply(json$data %||% list(), function(d) {
    a <- d$attributes %||% list()
    url <- if (!is.null(a$doi)) paste0("https://doi.org/", a$doi) else a$url
    title <- if (length(a$titles)) a$titles[[1]]$title else NULL
    ev_item("datacite", type = a$types$resourceTypeGeneral, title = title,
            year = a$publicationYear, url = url, citations = a$citationCount)
  })
}

#' @rdname normalize
#' @export
orm_normalize_openaire <- function(json) {
  lapply(json$results %||% list(), function(r) {
    doi <- Filter(function(p) identical(p$scheme, "doi"), r$pids %||% list())
    url <- if (length(doi)) {
      paste0("https://doi.org/", doi[[1]]$value)
    } else {
      paste0("https://explore.openaire.eu/search/result?id=", utils::URLencode(r$id, reserved = TRUE))
    }
    year <- if (!is.null(r$publicationDate)) suppressWarnings(as.numeric(substr(r$publicationDate, 1, 4)))
    ev_item("openaire", type = r$type, title = r$mainTitle, year = year, url = url,
            access_right = r$bestAccessRight$label)
  })
}

get_json <- function(url) {
  h <- curl::new_handle()
  curl::handle_setheaders(h, Accept = "application/json",
                          `User-Agent` = "ORMetrics R package (https://github.com/pablosancheznunez/openresearchmetrics)")
  res <- curl::curl_fetch_memory(url, handle = h)
  if (res$status_code >= 400) stop(res$status_code, " for ", url, call. = FALSE)
  jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)
}

max_pages <- 5

fetchers <- list(
  openalex = function(orcid) {
    # Basic paging: OpenAlex requires an API key for cursor paging.
    items <- list()
    for (page in seq_len(max_pages)) {
      json <- get_json(paste0("https://api.openalex.org/works?filter=author.orcid:", orcid,
                              "&per-page=200&page=", page,
                              "&select=id,doi,title,type,publication_year,open_access"))
      items <- c(items, orm_normalize_openalex(json))
      if (length(items) >= (json$meta$count %||% 0) || !length(json$results)) break
    }
    items
  },
  datacite = function(orcid) {
    orm_normalize_datacite(get_json(paste0("https://api.datacite.org/dois?user-id=", orcid,
                                           "&page[size]=1000")))
  },
  openaire = function(orcid) {
    items <- list()
    for (page in seq_len(max_pages)) {
      json <- get_json(paste0("https://api.openaire.eu/graph/v1/researchProducts?authorOrcid=",
                              orcid, "&pageSize=100&page=", page))
      items <- c(items, orm_normalize_openaire(json))
      if (length(items) >= (json$header$numFound %||% 0) || !length(json$results)) break
    }
    items
  }
)

#' Collect evidence for an ORCID iD
#'
#' Queries OpenAlex, DataCite and the OpenAIRE Graph. A source that fails is
#' recorded in `consulted` with its error and never stops the others; the
#' indicators that depend on it are then reported as unverifiable.
#'
#' @param orcid An ORCID iD, bare or as a URL.
#' @param sources Sources to query; by default all three.
#' @return A list with `evidence` (evidence items, see [normalize]) and
#'   `consulted` (one record per source: `source`, `ok`, `count`, `error`,
#'   `retrieved_at`).
#' @export
#' @examples
#' \donttest{
#' if (curl::has_internet()) {
#'   ev <- orm_collect("0000-0002-1825-0097")
#'   str(ev$consulted)
#' }
#' }
orm_collect <- function(orcid, sources = orm_sources) {
  orcid <- bare_orcid(orcid)
  sources <- match.arg(sources, orm_sources, several.ok = TRUE)
  evidence <- list()
  consulted <- lapply(sources, function(s) {
    res <- tryCatch(fetchers[[s]](orcid), error = function(e) e)
    ok <- !inherits(res, "error")
    if (ok) evidence <<- c(evidence, res)
    list(source = s, ok = ok, count = if (ok) length(res) else 0L,
         error = if (ok) NULL else conditionMessage(res), retrieved_at = utc_now())
  })
  list(evidence = evidence, consulted = consulted)
}

#' Recorded evidence for ORCID's public test record
#'
#' The responses of OpenAlex, DataCite and the OpenAIRE Graph for Josiah
#' Carberry (`0000-0002-1825-0097`), recorded on 2026-11-02 and shared with
#' the web tool's tests. Useful for examples and for working offline.
#'
#' @return A list with `evidence` and `consulted`, as from [orm_collect()].
#' @export
#' @examples
#' ex <- orm_example_evidence()
#' length(ex$evidence)
orm_example_evidence <- function() {
  read <- function(src) {
    jsonlite::fromJSON(system.file("extdata", "examples", paste0(src, ".json"),
                                   package = "ORMetrics"), simplifyVector = FALSE)
  }
  evidence <- c(orm_normalize_openalex(read("openalex")),
                orm_normalize_datacite(read("datacite")),
                orm_normalize_openaire(read("openaire")))
  consulted <- lapply(orm_sources, function(s) {
    list(source = s, ok = TRUE,
         count = sum(vapply(evidence, function(e) identical(e$source, s), TRUE)),
         error = NULL, retrieved_at = "2026-11-02T00:00:00Z")
  })
  list(evidence = evidence, consulted = consulted)
}
