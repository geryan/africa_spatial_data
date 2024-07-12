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

  ########################################################
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
      africa_mask,
      popdir = "data/raster/MAP_covariates/WorldPop/",
      popfilename = "outputs/raster/pop_all.tif"
    )
  ),
  # for single layer select most recent (2020)
  tar_terra_rast(
    pop,
    pop_all[[6]] |>
      writereadrast(
        filename = "outputs/raster/pop.tif",
        layernames = "pop"
      )
  ),

  ### GHS_BUILT_H
  # Average of the Gross Building Height (AGBH) and Average
  # of the Net Building Height (ANBH) for 2018 from GHSL
  # (https://ghsl.jrc.ec.europa.eu/ghs_buH2023.php). Pixel
  # values are average height of the built surfaces in
  # meters. The versions here have been aggregated from the
  # 100m originals first using a mean in the original
  # mollweide projection, and then reprojected to wgs84
  # using bilinear resampling.

  # here using gross built height (AGBH not ANBH)
  tar_terra_rast(
    built_height,
    prepare_single_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_H_AGBH_R23A.2018.Annual.Data.1km.mean.tif",
      lyrnm = "built_height",
      outputdir = "outputs/raster/"
    )
  ),

  ##### accessibility
  # Accessibility to cities for a nonimal year 2015.
  # "Cities" are defined as contiguous areas with 1,500
  # or more inhabitants per square kilometre or a majority
  # of built-up land cover types coincident with a
  # population centre of at least 50,000 inhabitants. Pixel
  # values show estimated fasted land-based travel time to
  # the nearest city in minutes. Produced by Dr Dan Weiss
  # (https://doi.org/10.1038/nature25181).

  tar_terra_rast(
    accessibility,
    prepare_single_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/Accessibility/accessibility_to_cities_2015_v1.0.tif",
      lyrnm = "accessibility",
      outputdir = "outputs/raster/"
    )
  ),

  ########################################################
  # environmental vars

  #### EVI
  # EVI is derived from the 8-daily global 1km MODIS
  # v6 MCD43D62, MCD43D63 and MCD43D64 products.
  # This is then gapfilled using an algorithm
  # developed by Dr Dan Weiss and implemented
  # globally by Dr Harry Gibson
  # (https://doi.org/10.1016/j.isprsjprs.2014.10.001).
  # The gapfilled outputs are aggregated temporally
  # to the annual level using a mean.
  tar_terra_rast(
    evi_all,
    prepare_evi(
      africa_mask,
      evidir = "data/raster/MAP_covariates/EVI/",
      evifilename = "outputs/raster/evi_all.tif"
    )
  ),
  tar_terra_rast(
    evi_mean,
    mean(evi_all) |>
      writereadrast(
        filename = "outputs/raster/evi_mean.tif",
        layernames = "evi_mean"
      )
  )


)
