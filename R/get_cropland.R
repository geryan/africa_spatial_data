get_cropland <- function(
    africa_mask,
    filename
){

  cropland_raw <- geodata::cropland(
    source = "QED",
    path = "data/raster/geodata"
  )

  crvals <- values(cropland_raw)

  cropland_raw_filled <- cropland_raw

  cropland_raw_filled[] <- ifelse(is.na(crvals), 0, crvals)

  cropland_raw_filled |>
    crop(africa_mask) |>
    mask(africa_mask) |>
    writereadrast(
      filename = filename,
      layernames = "cropland"
    )

}
