make_arid <- function(
    landcover,
    arid_lookup,
    filename
  ){

  lvals <- values(landcover)

  avals <- ifelse(lvals == 16, 0, 1)

  arid <- landcover

  arid[] <- avals

  levels(arid) <- arid_lookup

  writereadrast(
    arid,
    filename = filename,
    overwrite = TRUE,
    layernames = "arid"
  ) |>
    set_levels(levs = arid_lookup)

}
