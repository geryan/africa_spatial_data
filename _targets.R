library(targets)
library(geotargets)

tar_option_set(
  packages = c(
    "terra",
    "tidyterra",
    "dplyr",
    "sdmtools",
    "geodata",
    "geotargets",
    "ggplot2"
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
      res = "high"
    )
  ),

  tar_target(
    plot_africa_mask,
    plot_and_save(
      africa_mask,
      "africa_mask.png",
      title = "Africa",
      rm_guides = TRUE,
      end = 0.3
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

  tar_target(
    plot_pop,
    plot_and_save(
      pop,
      filename = "population.png",
      title = "Population",
      fill_label = "Population\ndensity"
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

  tar_target(
    plot_accessibility,
    plot_and_save(
      accessibility,
      title = "Accessibility",
      fill_label = "Minutes\ntravel\ntime\nto city"
    )
  ),

  ### GHS_BUILT_H (built height)
  # Average of the Gross Building Height (AGBH) and Average
  # of the Net Building Height (ANBH) for 2018 from GHSL
  # (https://ghsl.jrc.ec.europa.eu/ghs_buH2023.php). Pixel
  # values are average height of the built surfaces in
  # meters. The versions here have been aggregated from the
  # 100m originals first using a mean in the original
  # mollweide projection, and then reprojected to wgs84
  # using bilinear resampling.

  # here using gross built height (AGBH not ANBH; though
  # this layer also available)

  tar_terra_rast(
    built_height,
    prepare_single_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_H_AGBH_R23A.2018.Annual.Data.1km.mean.tif",
      lyrnm = "built_height",
      outputdir = "outputs/raster/"
    )
  ),

  tar_target(
    plot_built_height,
    plot_and_save(
      built_height,
      title = "Built height",
      fill_label = "Average\nheight"
    )
  ),

  # #### GHS SMOD (settlement)
  # # Settlement grids delineating and classifying settlement
  # # typologies via a logic of population size, population
  # # and built-up area densities
  # # (https://ghsl.jrc.ec.europa.eu/ghs_smod2019.php).
  # # The pixel classification criteria are available in the
  # # supporting data package PDF.

  tar_target(
    settlement_lookup,
    tribble(
      ~value, ~category,
      30, "URBAN CENTRE",
      23, "DENSE URBAN CLUSTER",
      22, "SEMI-DENSE URBAN CLUSTER",
      21, "SUBURBAN OR PERI-URBAN",
      13, "RURAL CLUSTER",
      12, "LOW DENSITY RURAL",
      11, "VERY LOW DENSITY RURAL",
      10, "WATER"
    ) %>%
      as.data.frame()
  ),

  tar_terra_rast(
    settlement,
    prepare_categorical_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_SMOD_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "settlement",
      outputdir = "outputs/raster/",
      lookup = settlement_lookup
    )
  ),

  tar_target(
    plot_settlement,
    plot_and_save(
      settlement,
      title = "Settlement",
      fill_label = "Settlement\ntype",
      lookup = settlement_lookup
    )
  ),

  ### GHS_BUILT_S (built surface)
  # Built-up surface grid for 2020 from GHSL, for total
  # residential and non-residential
  # (https://ghsl.jrc.ec.europa.eu/ghs_buS2023.php). Pixel
  # values are built square meters in the grid cell. The
  # version here has been reprojected from the 1km
  # mollweide dataset to wgs84 using bilinear resampling.

  tar_terra_rast(
    built_surface,
    prepare_single_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_S_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "built_surface",
      outputdir = "outputs/raster/"
    )
  ),

  tar_target(
    plot_built_surface,
    plot_and_save(
      built_surface,
      title = "Built Surface",
      fill_label = "Sq. m"
    )
  ),

  ### GHS_BUILT_V
  # The spatial raster dataset depicts the distribution
  # of built-up volumes, expressed as number of cubic
  # metres.
  # Built-up volume grid for 2020 from GHSL, for total
  # residential and non-residential
  # (https://ghsl.jrc.ec.europa.eu/ghs_buV2023.php).
  # Pixel values are built cubic meters in the grid cell.
  # The version here has been reprojected from the 1km
  # mollweide dataset to wgs84 using bilinear resampling.

  tar_terra_rast(
    built_volume,
    prepare_single_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_V_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "built_volume",
      outputdir = "outputs/raster/"
    )
  ),

  tar_target(
    plot_built_volume,
    plot_and_save(
      built_volume,
      title = "Built Volume",
      fill_label = "Cu. m"
    )
  ),

  # tar_target(
  #   plot_log10_built_volume,
  #   p_log10_built_volume(
  #     built_volume,
  #     africa_mask
  #   )
  # ),

  tar_target(
    plot_log10_built_volume,
    plot_and_save(
      log10(built_volume),
      title = "log Built Volume",
      fill_label = "log10\ncu. m"
    )
  ),

  # GHS_BUILT_C
  # Grids which dilineate the boundaries of human settlements
  # and describe their inner characteristics in terms of the
  # morphology of the built environment and the functional
  # use (https://ghsl.jrc.ec.europa.eu/ghs_buC2023.php). The
  # pixel classification criteria are available in the
  # supporting data package PDF. The percentage grids here
  # have been aggregated from the 10m classification grid,
  # first by getting the per-class percentages at 1km
  # resolution in the original mollweide coordinate system,
  # and then reprojecting the output to wgs84 using bilinear
  # resampling.

  # classes
  # 00 : other (doesn't fit these classifications)
  # 01 : MSZ, open spaces, low vegetation surfaces NDVI <= 0.3
  # 02 : MSZ, open spaces, medium vegetation surfaces 0.3 < NDVI <=0.5
  # 03 : MSZ, open spaces, high vegetation surfaces NDVI > 0.5
  # 04 : MSZ, open spaces, water surfaces LAND < 0.5
  # 05 : MSZ, open spaces, road surfaces
  # 11 : MSZ, built spaces, residential, building height <= 3m
  # 12 : MSZ, built spaces, residential, 3m < building height <= 6m
  # 13 : MSZ, built spaces, residential, 6m < building height <= 15m
  # 14 : MSZ, built spaces, residential, 15m < building height <= 30m
  # 15 : MSZ, built spaces, residential, building height > 30m
  # 21 : MSZ, built spaces, non-residential, building height <= 3m
  # 22 : MSZ, built spaces, non-residential, 3m < building height <= 6m
  # 23 : MSZ, built spaces, non-residential, 6m < building height <= 15m
  # 24 : MSZ, built spaces, non-residential, 15m < building height <= 30m
  # 25 : MSZ, built spaces, non-residential, building height > 30m

  tar_terra_rast(
    built_c,
    prepare_built_c(
      africa_mask,
      bcdir = "data/raster/MAP_covariates/GHSL_2023/GHS-BUILT-C/",
      bcfilename = "outputs/raster/built_c.tif"
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
    prepare_multi_layer(
      africa_mask,
      data_dir ="data/raster/MAP_covariates/EVI/",
      output_filename = "outputs/raster/evi_all.tif",
      layer_prefix = "evi",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*"
    )
  ),

  tar_terra_rast(
    evi_mean,
    mean(evi_all) |>
      writereadrast(
        filename = "outputs/raster/evi_mean.tif",
        layernames = "evi_mean"
      )
  ),

  tar_target(
    plot_evi_mean,
    plot_and_save(
      evi_mean,
      title = "Enhanced Vegetation Index",
      fill_label = "EVI"
    )
  ),

  ### Landcover
  # Landcover classification data derived from MODIS v6
  # MCD12Q1, using the IGBP classification. Annual
  # majority rasters (class number covering the majority
  # of each pixel) are available, derived and aggregated
  # from the 500m original datasets.
  #
  # IGBP Landcover Classes:
  # 00 Unclassified
  # 01 Evergreen_Needleleaf_Forest
  # 02 Evergreen_Broadleaf_Forest
  # 03 Deciduous_Needleleaf_Forest
  # 04 Deciduous_Broadleaf_Forest
  # 05 Mixed_Forest
  # 06 Closed_Shrublands
  # 07 Open_Shrublands
  # 08 Woody_Savannas
  # 09 Savannas
  # 10 Grasslands
  # 11 Permanent_Wetlands
  # 12 Croplands
  # 13 Urban_And_Built_Up
  # 14 Cropland_Natural_Vegetation_Mosaic
  # 15 Snow_And_Ice
  # 16 Barren_Or_Sparsely_Populated
  # 17 Water

  tar_target(
    landcover_lookup,
    tibble::tribble(
      ~value, ~category,
      00, "Unclassified",
      01, "Evergreen_Needleleaf_Forest",
      02, "Evergreen_Broadleaf_Forest",
      03, "Deciduous_Needleleaf_Forest",
      04, "Deciduous_Broadleaf_Forest",
      05, "Mixed_Forest",
      06, "Closed_Shrublands",
      07, "Open_Shrublands",
      08, "Woody_Savannas",
      09, "Savannas",
      10, "Grasslands",
      11, "Permanent_Wetlands",
      12, "Croplands",
      13, "Urban_And_Built_Up",
      14, "Cropland_Natural_Vegetation_Mosaic",
      15, "Snow_And_Ice",
      16, "Barren_Or_Sparsely_Populated",
      17, "Water"
    ) %>%
      as.data.frame()
  ),

  tar_terra_rast(
    landcover_all,
    prepare_landcover(
      africa_mask,
      landcoverdir = "data/raster/MAP_covariates/Landcover/",
      landcoverfilename = "outputs/raster/landcover_all.tif",
      lookup = landcover_lookup
    )
  ),

  tar_terra_rast(
    landcover,
    landcover_all[[nlyr(landcover_all)]] |>
      writereadrast(
        filename = "outputs/raster/landcover.tif",
        layernames = "landcover"
      )
  ),

  tar_target(
    plot_landcover,
    plot_and_save(
      landcover,
      title = "Landcover",
      fill_label = "Landcover\ntype",
      lookup = landcover_lookup
    )
  ),

  ### Arid
  # Just made from the barren land class in landcover
  tar_target(
    arid_lookup,
    tibble::tribble(
      ~value, ~category,
      00, "Arid",
      01, "Not Arid"
    ) %>%
      as.data.frame()
  ),

  tar_terra_rast(
    arid,
    make_arid(
      landcover,
      arid_lookup,
      filename = "outputs/raster/arid.tif"
    )
  ),

  tar_target(
    plot_arid,
    plot_and_save(
      arid,
      title = "Aridity",
      fill_label = "Arid",
      lookup = arid_lookup,
      begin = 0.2,
      end = 0.65
    )
  ),

  ######################## Land surface temperature

  #### LST Day
  # LST_Day is derived from the 8-daily global 1km
  # MODIS MOD11A2 v6 products. This is then
  # gapfilled using an algorithm developed by Dr
  # Dan Weiss and implemented globally by Dr Harry
  # Gibson
  # (https://doi.org/10.1016/j.isprsjprs.2014.10.001).
  # The gapfilled outputs are aggregated
  # temporally to the annual level using a mean.

  tar_terra_rast(
    lst_day_all,
    prepare_multi_layer(
      africa_mask,
      data_dir ="data/raster/MAP_covariates/LST_Day/",
      output_filename = "outputs/raster/lst_day_all.tif",
      layer_prefix = "lst_day",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*"
    )
  ),

  tar_terra_rast(
    lst_day_mean,
    mean(lst_day_all) |>
      writereadrast(
        filename = "outputs/raster/lst_day_mean.tif",
        layernames = "lst_day_mean"
      )
  ),

  tar_target(
    plot_lst_day_mean,
    plot_and_save(
      lst_day_mean,
      title = "Daytime Land Surface Temperature",
      fill_label = "\u00B0C" # degree symbol C
    )
  ),

  #### LST NIGHT
  # LST_NIGHT is derived from the 8-daily global 1km
  # MODIS MOD11A2 v6 products. This is then
  # gapfilled using an algorithm developed by Dr
  # Dan Weiss and implemented globally by Dr Harry
  # Gibson
  # (https://doi.org/10.1016/j.isprsjprs.2014.10.001).
  # The gapfilled outputs are aggregated
  # temporally to the annual level using a mean.

  tar_terra_rast(
    lst_night_all,
    prepare_multi_layer(
      africa_mask,
      data_dir ="data/raster/MAP_covariates/LST_Night/",
      output_filename = "outputs/raster/lst_night_all.tif",
      layer_prefix = "lst_night",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*"
    )
  ),

  tar_terra_rast(
    lst_night_mean,
    mean(lst_night_all) |>
      writereadrast(
        filename = "outputs/raster/lst_night_mean.tif",
        layernames = "lst_night_mean"
      )
  ),

  tar_target(
    plot_lst_night_mean,
    plot_and_save(
      lst_night_mean,
      title = "Nighttime Land Surface Temperature",
      fill_label = "\u00B0C" # degree symbol C
    )
  ),

  #### rainfall
  # Annual rainfall totals from the CHIRPS dataset
  # (https://www.chc.ucsb.edu/data/chirps).
  # The 1km version here is a neareast-neighbour
  # resample of the lower resolution data
  # available from CHIRPS.

  tar_terra_rast(
    rainfall_all,
    prepare_multi_layer(
      africa_mask,
      data_dir = "data/raster/MAP_covariates/Rainfall/",
      output_filename = "outputs/raster/rainfall_all.tif",
      layer_prefix = "rainfall",
      file_id_prefix = ".*v2-0\\.",
      file_id_suffix = "\\.Annual.*"
    )
  ),

  tar_terra_rast(
    rainfall_mean,
    mean(rainfall_all) |>
      writereadrast(
        filename = "outputs/raster/rainfall_mean.tif",
        layernames = "rainfall_mean"
      )
  ),

  tar_target(
    plot_rainfall_mean,
    plot_and_save(
      rainfall_mean,
      title = "Rainfall Annual Mean",
      fill_label = "mm"
    )
  ),

  ######## Tasselated cap brightness
  # TCB
  # TCB is derived from the 8-daily global 1km MODIS
  # v6 MCD43D62, MCD43D63 and MCD43D64 products.
  # This is then gapfilled using an algorithm
  # developed by Dr Dan Weiss and implemented
  # globally by Dr Harry Gibson
  # (https://doi.org/10.1016/j.isprsjprs.2014.10.001).
  # The gapfilled outputs are aggregated temporally
  # to the annual level using a mean.


  tar_terra_rast(
    tcb_all,
    prepare_multi_layer(
      africa_mask,
      data_dir = "data/raster/MAP_covariates/TCB/",
      output_filename = "outputs/raster/tcb_all.tif",
      layer_prefix = "tcb",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*"
    )
  ),

  tar_terra_rast(
    tcb_mean,
    mean(tcb_all) |>
      writereadrast(
        filename = "outputs/raster/tcb_mean.tif",
        layernames = "tcb_mean"
      )
  ),

  tar_target(
    plot_tcb_mean,
    plot_and_save(
      tcb_mean,
      title = "Tasselated Cap Brightness",
      fill_label = "TCB"
    )
  ),

  ####### Tasselated cap wetness
  # TCW
  # TCW is derived from the 8-daily global 1km MODIS
  # v6 MCD43D62, MCD43D63 and MCD43D64 products.
  # This is then gapfilled using an algorithm
  # developed by Dr Dan Weiss and implemented
  # globally by Dr Harry Gibson
  # (https://doi.org/10.1016/j.isprsjprs.2014.10.001).
  # The gapfilled outputs are aggregated temporally
  # to the annual level using a mean.


  tar_terra_rast(
    tcw_all,
    prepare_multi_layer(
      africa_mask,
      data_dir = "data/raster/MAP_covariates/TCW/",
      output_filename = "outputs/raster/tcw_all.tif",
      layer_prefix = "tcw",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*"
    )
  ),

  tar_terra_rast(
    tcw_mean,
    mean(tcw_all) |>
      writereadrast(
        filename = "outputs/raster/tcw_mean.tif",
        layernames = "tcw_mean"
      )
  ),

  tar_target(
    plot_tcw_mean,
    plot_and_save(
      tcw_mean,
      title = "Tasselated Cap Wetness",
      fill_label = "TCW"
    )
  ),



  #####################

  tar_target(
    so_i_dont_have_to_go_backward_and_add_commas,
    print("Targets great in theory but kinda annoying to work with")
  )





)
