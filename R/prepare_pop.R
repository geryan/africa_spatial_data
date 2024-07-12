prepare_pop <- function(popdir, africa_mask){

  pop <- list.files(
    path = popdir,
    full.names = TRUE
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast |>
    crop(africa_mask) |>
    mask(africa_mask)

  pop_names <- names(pop) %>%
    sub(
      pattern = ".*fix\\.",
      replacement = "",
      x = .
    ) %>%
    sub(
      pattern = "\\.Annual.*",
      replacement = "",
      x = .
    ) %>%
    paste0("pop_", .)

  names(pop) <- pop_names

  pvals <- values(pop)

  idxna <- which(is.na(pvals))

  pvals[idxna] <- 0

  pop[] <- pvals

  pop <- mask(pop, africa_mask)

  pop


}
