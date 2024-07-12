library(targets)
library(geotargets)

tar_option_set(
  packages = c(
    "terra",
    "tidyterra",
    "dplyr",
    "sdmtools",
    "geodata",
    "geotargets"
  ),
  format = "qs"
)

tar_source(files = "R")

list(
  tar_terra_rast(
    africa_mask,
    sdmtools::make_africa_mask(
      filename = "data/raster/africa_mask.tif",
      type = "raster",
      res = "high",
    )
  ),

  # anthropocentric vars

  # Worldpop
  # Annual 1km UN-adjusted population counts
  # from WorldPop v3
  # (https://www.worldpop.org/geodata/listing?id=75).
  # This version has been derived by mosaicing the
  # country outputs and aligning to MAP's master
  # coastline template (reallocating population from
  # cells falling outside the MAP coastline into the
  # nearest land pixel).
  tar_terra_rast(
    pop_all,
    prepare_pop(
      popdir = "data/raster/MAP_covariates/WorldPop/",
      africa_mask
    )
  ),

  ### GHS_BUILT_H
  # Average of the Gross Building Height (AGBH) and Average
  # of the Net Building Height (ANBH) for 2018 from GHSL
  # (https://ghsl.jrc.ec.europa.eu/ghs_buH2023.php). Pixel
  # values are average height of the built surfaces in
  # meters. The versions here have been aggregated from the
  # 100m originals first using a mean in the original
  # mollweide projection, and then reporjected to wgs84
  # using bilinear resampling.

  # here using gross built height (AGBH not ANBH)
  tar_terra_rast(
    built_height,
    rast(x = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_H_AGBH_R23A.2018.Annual.Data.1km.mean.tif")  |>
      crop(africa_mask) |>
      mask(africa_mask)
  )

  # environmental vars
)
