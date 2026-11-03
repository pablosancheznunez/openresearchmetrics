canonical <- function(x) {
  jsonlite::fromJSON(jsonlite::toJSON(unclass(x), auto_unbox = TRUE, null = "null", na = "null", digits = NA),
                     simplifyVector = FALSE)
}

test_that("the R report equals the web tool's regression report", {
  ex <- orm_example_evidence()
  report <- orm_compute(ex$evidence, ex$consulted, orcid = "0000-0002-1825-0097",
                        generated_at = "2026-11-02T00:00:00Z")
  expected <- jsonlite::fromJSON(test_path("fixtures", "carberry.json"), simplifyVector = FALSE)
  expect_identical(canonical(report), expected)
})

test_that("every catalogue card has a procedure for its exact version", {
  for (ind in orm_catalog()$indicators) {
    expect_true(procedure_key(ind) %in% names(procedures), info = procedure_key(ind))
  }
  cat_ <- orm_catalog()
  cat_$indicators[[1]]$methodology_version <- "9.9.9"
  ex <- orm_example_evidence()
  expect_error(orm_compute(ex$evidence, ex$consulted, catalog = cat_), "No procedure implements")
})

test_that("a failed source makes its indicators unverifiable, never zero", {
  ex <- orm_example_evidence()
  ex$consulted[[3]]$ok <- FALSE
  df <- as.data.frame(orm_compute(ex$evidence, ex$consulted))
  row <- df[df$indicator == "openaire-open-access-right-share", ]
  expect_equal(row$status, "unverifiable")
  expect_true(is.na(row$value))
  expect_match(row$reason, "openaire")
  expect_true(all(df$status[df$indicator != "openaire-open-access-right-share"] == "computed"))
})

test_that("an empty denominator is unverifiable", {
  consulted <- lapply(c("openalex", "datacite", "openaire"), function(s) list(source = s, ok = TRUE))
  df <- as.data.frame(orm_compute(list(), consulted))
  expect_true(all(df$status[df$indicator == "oa-publications-share"] == "unverifiable"))
  expect_equal(df$value[df$indicator == "datasets-shared"], 0)
})

test_that("normalisers tolerate empty responses", {
  expect_equal(orm_normalize_openalex(list()), list())
  expect_equal(orm_normalize_datacite(list(data = list())), list())
  expect_equal(orm_normalize_openaire(list(results = list())), list())
})

test_that("ORCID iDs are validated", {
  expect_true(orm_valid_orcid("0000-0002-1694-233X"))
  expect_false(orm_valid_orcid("0000-0002-1825-0098"))
  expect_false(orm_valid_orcid(NA_character_))
  expect_error(orm_assess("1234"), "Not a valid ORCID")
})

test_that("reports print, flatten and round-trip through JSON", {
  ex <- orm_example_evidence()
  report <- orm_compute(ex$evidence, ex$consulted, generated_at = "2026-11-02T00:00:00Z")
  expect_output(print(report), "no composite score")
  df <- as.data.frame(report)
  expect_equal(nrow(df), length(orm_catalog()$indicators))
  expect_false(any(grepl("score|total|index", names(df))))
  path <- tempfile(fileext = ".json")
  orm_write_json(report, path)
  expect_identical(jsonlite::fromJSON(path, simplifyVector = FALSE), canonical(report))
})

test_that("the bundled catalogue matches the web tool's catalogue", {
  web <- file.path(test_path(), "..", "..", "..", "data", "indicators.json")
  skip_if_not(file.exists(web), "Not run inside the repository")
  expect_identical(orm_catalog(), jsonlite::read_json(web, simplifyVector = FALSE))
})
