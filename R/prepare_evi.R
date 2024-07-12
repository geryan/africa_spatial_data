prepare_evi <- function(africa_mask, evidir, evifilename){


  evi <- list.files(
    path = evidir,
    full.names = TRUE
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast |>
    crop(africa_mask) |>
    mask(africa_mask)

  evi_names <- names(evi) %>%
    sub(
      pattern = ".*v6\\.",
      replacement = "",
      x = .
    ) %>%
    sub(
      pattern = "\\.Annual.*",
      replacement = "",
      x = .
    ) %>%
    paste0("evi_", .)

  names(evi) <- evi_names


  evi <- writereadrast(
    evi,
    evifilename
  )

  evi

}
