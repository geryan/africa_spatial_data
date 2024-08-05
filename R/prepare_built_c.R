prepare_built_c <- function(africa_mask, bcdir, bcfilename){


  bc <- list.files(
    path = bcdir,
    full.names = TRUE
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast |>
    crop(africa_mask) |>
    mask(africa_mask)

  bc_names <- names(bc) |>
    sub(
      pattern = ".*Class-",
      replacement = "",
      x = _
    ) |>
    sub(
      pattern = "\\.2018.*",
      replacement = "",
      x = _
    ) %>%
    paste0("built_c_", .)

  names(bc) <- bc_names


  bc <- writereadrast(
    bc,
    bcfilename
  )

  bc

}
