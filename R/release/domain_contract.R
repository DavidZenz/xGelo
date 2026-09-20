#' Shared forecast-domain contract for national and club consumers.
#'
#' A compatible R object is not authority by itself.  Every consumer must pass
#' its expected domain explicitly and the object/metadata must carry the same
#' closed vocabulary value.

phase19_domain_abort <- function(message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = "domain_mismatch"), data),
    class = c("phase19_domain_error", "error", "condition")
  ))
}

phase19_domain_value <- function(metadata) {
  if (is.null(metadata)) return(NA_character_)
  value <- if (is.data.frame(metadata)) {
    if (!"forecast_domain" %in% names(metadata) || !nrow(metadata)) NA_character_ else metadata$forecast_domain[[1L]]
  } else if (is.list(metadata)) {
    if (!is.null(metadata$forecast_domain)) metadata$forecast_domain[[1L]] else if (!is.null(metadata$model_domain)) metadata$model_domain[[1L]] else NA_character_
  } else {
    NA_character_
  }
  if (length(value) != 1L || is.na(value)) NA_character_ else as.character(value)
}

#' Assert one explicit expected forecast domain.
#'
#' @param metadata A list or one-row data frame carrying `forecast_domain`.
#' @param expected_domain One of `club` or `national_team`.
#' @return `metadata`, invisibly, when the assertion passes.
#' @export
assert_forecast_domain <- function(metadata, expected_domain) {
  if (length(expected_domain) != 1L || is.na(expected_domain) ||
      !as.character(expected_domain) %in% c("club", "national_team")) {
    phase19_domain_abort("Expected forecast domain is outside the closed vocabulary")
  }
  expected_domain <- as.character(expected_domain)
  actual <- phase19_domain_value(metadata)
  if (!identical(actual, expected_domain)) {
    phase19_domain_abort(
      paste0("Forecast domain mismatch: expected ", expected_domain,
             ", observed ", if (nzchar(actual)) actual else "<missing>"),
      list(expected_domain = expected_domain, observed_domain = actual)
    )
  }
  invisible(metadata)
}

phase19_assert_forecast_domain <- assert_forecast_domain
phase19_expected_domain_guard <- assert_forecast_domain

