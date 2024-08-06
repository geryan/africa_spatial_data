get_bioclim <- function(
    africa_mask,
    filename,
    bioclim_var,
    layer_prefix
){

  geodata::worldclim_global(
    var = bioclim_var,
    res = 0.5,
    path = "data/raster/geodata"
  ) |>
    crop(africa_mask) |>
    mask(africa_mask) |>
    writereadrast(
      filename = filename,
      layernames = sprintf(
        "%s_%02d",
        layer_prefix,
        1:12
      )
    )

}
