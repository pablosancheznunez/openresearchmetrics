#' The indicator catalogue
#'
#' `orm_catalog()` returns the versioned catalogue shared with the web tool:
#' principles, families and one card per indicator (definition, rationale,
#' numerator, denominator, sources, limitations and methodology version).
#' `orm_indicators()` flattens the cards into a data frame.
#'
#' @return `orm_catalog()`: a list. `orm_indicators()`: a data frame with one
#'   row per indicator.
#' @export
#' @examples
#' cat_ <- orm_catalog()
#' cat_$catalog_version
#' orm_indicators()[, c("id", "family", "methodology_version")]
orm_catalog <- function() {
  jsonlite::read_json(system.file("extdata", "indicators.json", package = "openresearchmetrics"),
                      simplifyVector = FALSE)
}

#' @rdname orm_catalog
#' @export
orm_indicators <- function() {
  ind <- orm_catalog()$indicators
  data.frame(
    id = vapply(ind, `[[`, "", "id"),
    name = vapply(ind, `[[`, "", "name"),
    family = vapply(ind, `[[`, "", "family"),
    definition = vapply(ind, `[[`, "", "definition"),
    sources = vapply(ind, function(i) paste(unlist(i$sources), collapse = ", "), ""),
    limitations = vapply(ind, function(i) paste(unlist(i$limitations), collapse = " "), ""),
    methodology_version = vapply(ind, `[[`, "", "methodology_version"),
    stringsAsFactors = FALSE
  )
}
