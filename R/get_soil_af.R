get_soil_af <- function(
    africa_mask,
    filename,
    var,
    layername
){

  soil_raw <- geodata::soil_af(
    var = var,
    depth = 5,
    path = "data/raster"
  )

  srvals <- values(soil_raw)

  soil_raw_filled <- soil_raw

  soil_raw_filled[] <- ifelse(is.na(srvals), 0, srvals)

  soil_raw_filled |>
    crop(africa_mask) |>
    extend(africa_mask) |>
    mask(africa_mask) |>
    writereadrast(
      filename = filename,
      layernames = layername
    )

}
