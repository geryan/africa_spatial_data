prepare_multi_layer <- function(
    africa_mask,
    data_dir,
    output_filename,
    layer_prefix,
    file_id_prefix,
    file_id_suffix
  ){


  r <- list.files(
    path = data_dir,
    full.names = TRUE
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast |>
    crop(africa_mask) |>
    mask(africa_mask)

  r_names <- names(r) %>%
    sub(
      pattern = file_id_prefix,
      replacement = "",
      x = .
    ) %>%
    sub(
      pattern = file_id_suffix,
      replacement = "",
      x = .
    ) %>%
    sprintf(
      "%s_%s",
      layer_prefix,
      .
    )

  names(r) <- r_names

  writereadrast(
    r,
    output_filename
  )

}
