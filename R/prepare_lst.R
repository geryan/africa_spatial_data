prepare_lst <- function(
    africa_mask,
    lstdir,
    lstfilename,
    type
  ){


  lst <- list.files(
    path = lstdir,
    full.names = TRUE
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast |>
    crop(africa_mask) |>
    mask(africa_mask)

  lst_names <- names(lst) %>%
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
    sprintf(
      "lst_%s_%s",
      type,
      .
    )

  names(lst) <- lst_names

  writereadrast(
    lst,
    lstfilename
  )

}
