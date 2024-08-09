get_elevation <- function(
    africa_mask,
    filename
){


  global_regions |>
    filter(continent == "Africa") |>
    pull(iso3) |>
    lapply(
      FUN = function(x){
        elevation_30s(
          country = x,
          path = "data/raster/geodata"
        )
      }
    ) |>
    sprc() |>
    merge() |>
    crop(africa_mask) |>
    mask(africa_mask) |>
    scale() |>
    writereadrast(
      filename =  filename,
      layernames = "elevation"
    )


}
