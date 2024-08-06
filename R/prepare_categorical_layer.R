prepare_categorical_layer <- function(
    africa_mask,
    filename,
    lyrnm,
    outputdir = "outputs/raster/",
    lookup,
    overwrite = TRUE
){
  z <- rast(x = filename)  |>
    crop(africa_mask) |>
    mask(africa_mask)

  levels(z) <- lookup

  r <- writereadrast(
    z,
    filename = sprintf(
      "%s/%s.tif",
      outputdir,
      lyrnm
    ),
    layernames = lyrnm,
    overwrite = overwrite
  )

  levels(r) <- lookup

  r
}
