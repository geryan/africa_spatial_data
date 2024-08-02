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
    amp,
    plot_and_save(
      africa_mask,
      "am.png",
      title = "Africa",
      rm_guides = TRUE,
      end = 0.3
    )
  ),

  tar_target(
    africa_mask_plot,
    ggplot() +
      geom_spatraster(
        data = africa_mask
      ) +
      scale_fill_viridis_c(
        option = "G",
        begin = 1,
        end = 0.3,
        na.value = "white"
      ) +
      theme_void() +
      labs(title = "Africa") +
      guides(fill = "none")
  ),

  tar_target(
    africa_mask_plot_save,
    ggsave(
      filename = "outputs/figures/africa_mask.png",
      plot = africa_mask_plot,
      width = 2000,
      height = 1600,
      units = "px"
    ),
    format = "file"
  ),
#
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
    pop_plot,
    print(ggplot() +
      geom_spatraster(
        data = pop
      ) +
      scale_fill_viridis_c(
        option = "G",
        begin = 1,
        end = 0,
        na.value = "white"
      ) +
      theme_void() +
      labs(title = "Population")) |>
      ggsave(
        filename = "outputs/figures/population.png",
        plot = _,
        width = 2000,
        height = 1600,
        units = "px"
      ),
    format = "file"
  ),
#
#   tar_target(
#     pop_plot_save,
#     ggsave(
#       filename = "outputs/figures/population.png",
#       plot = pop_plot,
#       width = 2000,
#       height = 1600,
#       units = "px"
#     ),
#     format = "file"
#   ),
#
# tar_target(
#   africa_mask_plot_save,
#   ggsave(
#     filename = "outputs/figures/africa_mask.png",
#     plot = africa_mask_plot,
#     width = 2000,
#     height = 1600,
#     units = "px"
#   ),
#   format = "file"
# ),


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

  # #### GHS SMOD (settlement)
  # # Settlement grids delineating and classifying settlement
  # # typologies via a logic of population size, population
  # # and built-up area densities
  # # (https://ghsl.jrc.ec.europa.eu/ghs_smod2019.php).
  # # The pixel classification criteria are available in the
  # # supporting data package PDF.

  tar_terra_rast(
    settlement,
    prepare_categorical_layer(
      africa_mask,
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_SMOD_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "settlement",
      outputdir = "outputs/raster/",
      lookup = tribble(
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
