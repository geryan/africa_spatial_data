# alt_targets.R ---------------------------------------------------------------
#
# Path-based alternative to _targets.R.
#
# WHAT IS DIFFERENT
#   _targets.R uses geotargets::tar_terra_rast(), which writes a second,
#   byte-identical copy of every raster into _targets/objects/. That is
#   ~11.9 GB of pure duplication of outputs/raster/.
#
#   Here every raster target is an ordinary tar_target(format = "file"):
#     * the command still writes the .tif to outputs/raster/ (unchanged)
#     * the target's VALUE is the file path -- a few dozen bytes
#     * targets tracks the .tif by content hash, so editing or deleting an
#       output correctly invalidates that target and everything downstream
#     * downstream targets read the raster back with read_rast(<path>)
#
#   Net effect: _targets/objects/ drops from ~11.9 GB to a few KB, and
#   outputs/raster/ becomes the single copy of the data.
#
# TO USE
#   targets::tar_make(script = "alt_targets.R")
#   targets::tar_read(evi_mean, store = "_targets")   # -> "outputs/raster/evi_mean.tif"
#   read_rast(tar_read(evi_mean))                     # -> SpatRaster
#
#   Run it against a SEPARATE store until you are happy with it, e.g.
#     tar_make(script = "alt_targets.R", store = "_targets_alt")
#   so the existing _targets/ store is left untouched.
#
# BEFORE YOU RUN IT -- two known blockers, neither introduced here
#
#   1. Every raster target changes storage format, so targets treats them all
#      as outdated on the first run. This rebuilds the whole pipeline,
#      including the four combined stacks that are already missing from disk
#      (~11.8 GB). Make sure there is headroom.
#
#   2. prepare_multi_layer() and prepare_built_c() call list.files() with no
#      `pattern`, and these directories gained a 5 km subdirectory in Nov 2024:
#         data/raster/MAP_covariates/EVI/EVI_v061_5km_Annual_mean_mean/
#         data/raster/MAP_covariates/TCB/TCB_v061_5km_Annual_mean_mean/
#         data/raster/MAP_covariates/TCW/TCW_v061_5km_Annual_mean_mean/
#         data/raster/MAP_covariates/LST_Day/LST_Day_v061_5km_annual_mean_mean/
#         data/raster/MAP_covariates/LST_Night/LST_Night_v061_5km_annual_mean_mean/
#      That subdirectory path gets handed to rast() and will error. Adding
#      `pattern = "\\.tif$"` to the list.files() call in R/prepare_multi_layer.R
#      fixes it, but that file is untouched here.
#
# -----------------------------------------------------------------------------

library(targets)

tar_option_set(
  packages = c(
    "terra",
    "tidyterra",
    "dplyr",
    "sdmtools",
    "geodata",
    "ggplot2",
    #"rgbif",
    "readr",
    "countrycode",
    "tidyr",
    "purrr",
    "ecmwfr"
  ),
  format = "qs",
  # format = "file" targets re-hash their files to check for changes. Some of
  # these are >1 GB, so let targets skip the re-hash when size and mtime are
  # unchanged. Set to FALSE if you ever edit outputs in place.
  trust_timestamps = TRUE
)

tar_source(files = "R")


# helpers ---------------------------------------------------------------------
# Kept here so the whole scheme is reviewable in one file. Move them into R/
# once you are happy with them, and delete them from here.

#' Path of the .tif that a writereadrast() result is backed by
#'
#' Every prepare_*/get_* helper in R/ ends in writereadrast(), which returns
#' terra::rast(filename) -- so the result is always file-backed and its source
#' is the file we just wrote. Returned relative to the project root, because
#' terra reports absolute paths and an absolute path in the store would break
#' if the project ever moves.
rast_path <- function(x) {
  src <- unique(terra::sources(x))
  if (length(src) != 1L || !nzchar(src)) {
    stop(
      "rast_path(): expected a SpatRaster backed by exactly one file on disk. ",
      "Did the command forget writereadrast()?",
      call. = FALSE
    )
  }
  sub(
    paste0("^", normalizePath(getwd(), winslash = "/"), "/"),
    "",
    normalizePath(src, winslash = "/")
  )
}

#' Read a raster target (a file path) back off disk
#'
#' `lookup` re-applies categorical levels, which do not always survive the
#' write/read round trip -- prepare_landcover() and prepare_categorical_layer()
#' both re-apply them for the same reason.
read_rast <- function(path, lookup = NULL) {
  r <- terra::rast(path)
  if (!is.null(lookup)) {
    for (i in seq_len(terra::nlyr(r))) {
      levels(r[[i]]) <- lookup
    }
  }
  r
}

#' Read several raster paths back as a SpatRasterCollection
read_sprc <- function(paths) {
  terra::sprc(lapply(paths, terra::rast))
}

#' Stack several single-layer raster paths into one multi-layer SpatRaster
#'
#' `standardise = TRUE` applies terra::scale() to each layer except those whose
#' layer name is listed in `except`.
combine_rasts <- function(paths, standardise = FALSE, except = character(0)) {
  terra::rast(
    lapply(
      paths,
      function(p) {
        r <- terra::rast(p)
        if (standardise && !(names(r)[1] %in% except)) {
          r <- terra::scale(r)
        }
        r
      }
    )
  )
}


# pipeline --------------------------------------------------------------------

list(

  ## Image alignment / plotting layers

  tar_target(
    africa_mask,
    sdmtools::make_africa_mask(
      filename = "data/raster/africa_mask.tif",
      type = "raster",
      res = "high"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_africa_mask,
    plot_and_save(
      read_rast(africa_mask),
      "africa_mask.png",
      title = "Africa",
      rm_guides = TRUE,
      end = 0.3
    )
  ),

  tar_target(
    cod_mask,
    make_country_mask(
      africa_mask = read_rast(africa_mask),
      country = "COD",
      filename = "data/raster/cod_mask.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    nga_mask,
    make_country_mask(
      africa_mask = read_rast(africa_mask),
      country = "NGA",
      filename = "data/raster/nga_mask.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    tza_mask,
    make_country_mask(
      africa_mask = read_rast(africa_mask),
      country = "TZA",
      filename = "data/raster/tza_mask.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  # was tar_terra_sprc(); now just the three paths. The files themselves are
  # already tracked by cod_mask/nga_mask/tza_mask, so this stays a plain target
  # to avoid hashing them twice. Rebuild the collection with read_sprc().
  tar_target(
    country_masks,
    c(
      cod_mask,
      nga_mask,
      tza_mask
    )
  ),

  tar_target(
    country_mask_names,
    c(
      "COD",
      "NGA",
      "TZA"
    )
  ),

  tar_target(
    africa_countries,
    global_regions |>
      filter(continent == "Africa") |>
      select(country, iso2, iso3)
  ),

  ## Northing and easting layers

  # easting
  tar_target(
    easting,
    init(
      read_rast(africa_mask),
      fun = "x"
    ) |>
      mask(read_rast(africa_mask)) |>
      writereadrast(
        filename = "outputs/raster/easting.tif",
        layernames = "easting"
      ) |>
      rast_path(),
    format = "file"
  ),

  # northing
  tar_target(
    northing,
    init(
      read_rast(africa_mask),
      fun = "y"
    ) |>
      mask(read_rast(africa_mask)) |>
      writereadrast(
        filename = "outputs/raster/northing.tif",
        layernames = "northing"
      ) |>
      rast_path(),
    format = "file"
  ),

  ########################################################
  # anthropocentric vars

  ## Research travel time by country
  # custom layer from this project
  #
  # NB output filename keeps the existing "reseach" typo so it matches the
  # file already on disk. Rename it here and in any downstream project together.
  tar_target(
    research_tt_by_country,
    rast("data/raster/tt_by_country.tif") |>
      crop(read_rast(africa_mask)) |>
      mask(read_rast(africa_mask)) |>
      std_rast(reverse = TRUE) |>
      writereadrast(
        filename = "outputs/raster/reseach_tt_by_country.tif",
        layernames = "research_tt_by_country"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_research_tt_by_country,
    plot_and_save(
      read_rast(research_tt_by_country),
      filename = "research_tt_by_country.png",
      title = "Inverse relative travel time from research station",
      fill_label = "",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  ## Culex gbif data

  # Citation Info:
  #   Please always cite the download DOI when using this data.
  # https://www.gbif.org/citation-guidelines
  # DOI: 10.15468/dl.xywxdt
  # Citation:
  #   GBIF Occurrence Download https://doi.org/10.15468/dl.xywxdt Accessed from R via rgbif (https://github.com/ropensci/rgbif) on 2024-10-14
  # tar_target(
  #   culicidae_bias_lyr,
  #   make_culicidae_bias_lyr(
  #     africa_countries = africa_countries,
  #     read_rast(africa_mask)
  #   ) |>
  #     rast_path(),
  #   format = "file"
  # ),


  # Worldpop
  # Annual 1km UN-adjusted population counts
  # from WorldPop v3
  # (https://www.worldpop.org/geodata/listing?id=75).
  # This version has been derived by mosaicing the
  # country outputs and aligning to MAP's master
  # coastline template (reallocating population from
  # cells falling outside the MAP coastline into the
  # nearest land pixel).
  tar_target(
    pop_all,
    prepare_pop(
      read_rast(africa_mask),
      popdir = "data/raster/MAP_covariates/WorldPop/",
      popfilename = "outputs/raster/pop_all.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  # for single layer select most recent (2020)
  tar_target(
    pop,
    read_rast(pop_all)[[6]] |>
      writereadrast(
        filename = "outputs/raster/pop.tif",
        layernames = "pop"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_pop,
    plot_and_save(
      read_rast(pop),
      filename = "population.png",
      title = "Population",
      fill_label = "Population\ndensity",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    accessibility,
    prepare_single_layer(
      read_rast(africa_mask),
      filename = "data/raster/MAP_covariates/Accessibility/accessibility_to_cities_2015_v1.0.tif",
      lyrnm = "accessibility",
      outputdir = "outputs/raster/"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_accessibility,
    plot_and_save(
      read_rast(accessibility),
      title = "Accessibility",
      fill_label = "Minutes\ntravel\ntime\nto city",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    built_height,
    prepare_single_layer(
      read_rast(africa_mask),
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_H_AGBH_R23A.2018.Annual.Data.1km.mean.tif",
      lyrnm = "built_height",
      outputdir = "outputs/raster/"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_built_height,
    plot_and_save(
      read_rast(built_height),
      title = "Built height",
      fill_label = "Average\nheight",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    settlement,
    prepare_categorical_layer(
      read_rast(africa_mask),
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_SMOD_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "settlement",
      outputdir = "outputs/raster/",
      lookup = settlement_lookup
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_settlement,
    plot_and_save(
      read_rast(settlement),
      title = "Settlement",
      fill_label = "Settlement\ntype",
      lookup = settlement_lookup,
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  ### GHS_BUILT_S (built surface)
  # Built-up surface grid for 2020 from GHSL, for total
  # residential and non-residential
  # (https://ghsl.jrc.ec.europa.eu/ghs_buS2023.php). Pixel
  # values are built square meters in the grid cell. The
  # version here has been reprojected from the 1km
  # mollweide dataset to wgs84 using bilinear resampling.

  tar_target(
    built_surface,
    prepare_single_layer(
      read_rast(africa_mask),
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_S_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "built_surface",
      outputdir = "outputs/raster/"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_built_surface,
    plot_and_save(
      read_rast(built_surface),
      title = "Built Surface",
      fill_label = "Sq. m",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    built_volume,
    prepare_single_layer(
      read_rast(africa_mask),
      filename = "data/raster/MAP_covariates/GHSL_2023/GHS_BUILT_V_R23A.2020.Annual.Data.1km.Data.tif",
      lyrnm = "built_volume",
      outputdir = "outputs/raster/"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_built_volume,
    plot_and_save(
      read_rast(built_volume),
      title = "Built Volume",
      fill_label = "Cu. m",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  tar_target(
    plot_log10_built_volume,
    plot_and_save(
      log10(read_rast(built_volume)),
      title = "log Built Volume",
      fill_label = "log10\ncu. m",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    built_c,
    prepare_built_c(
      read_rast(africa_mask),
      bcdir = "data/raster/MAP_covariates/GHSL_2023/GHS-BUILT-C/",
      bcfilename = "outputs/raster/built_c.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  ########### Cropland
  # via `geodata` via https://maps.qed.ai/map/geosurvey_h2o_nnet_crp_predictions#lat=1.56012&lng=16.75000&zoom=4.0&layers=geosurvey_h2o_nnet_crp_predictions
  tar_target(
    cropland,
    get_cropland(
      read_rast(africa_mask),
      filename = "outputs/raster/cropland.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_cropland,
    plot_and_save(
      read_rast(cropland),
      title = "Cropland",
      fill_label = "%",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  ###### Human settlement probability
  # The prediction of human settlement probabilities uses
  # a gaussian kernel model trained on a million-point
  # dataset collected using Geosurvey.
  # https://maps.qed.ai/map/RSPKDs#lat=5.62965&lng=5.30090&zoom=8.0&layers=RSPKDs

  tar_target(
    settlement_prob,
    prepare_single_layer_qed(
      read_rast(africa_mask),
      filename = "data/raster/RSPKDs.tif/RSPKDs.tif",
      lyrnm = "settlement_prob"
    ) |>
      rast_path(),
    format = "file"
  ),

  # FIXED: _targets.R plotted `cropland` here and saved it as
  # "settlement_prob.tif" (which is why outputs/figures/ contains four .tif
  # files). Now plots settlement_prob and saves a .png. Revert if the old
  # behaviour was deliberate.
  tar_target(
    plot_settlement_prob,
    plot_and_save(
      read_rast(settlement_prob),
      filename = "settlement_prob.png",
      title = "Human Settlement Probability",
      fill_label = "Probability?",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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
  tar_target(
    evi_all,
    prepare_multi_layer(
      read_rast(africa_mask),
      data_dir = "data/raster/MAP_covariates/EVI/",
      output_filename = "outputs/raster/evi_all.tif",
      layer_prefix = "evi",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*",
      filetype_suffix = ".tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    evi_mean,
    mean(read_rast(evi_all)) |>
      writereadrast(
        filename = "outputs/raster/evi_mean.tif",
        layernames = "evi_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_evi_mean,
    plot_and_save(
      read_rast(evi_mean),
      title = "Enhanced Vegetation Index",
      fill_label = "EVI",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    landcover_all,
    prepare_landcover(
      read_rast(africa_mask),
      landcoverdir = "data/raster/MAP_covariates/Landcover/",
      landcoverfilename = "outputs/raster/landcover_all.tif",
      lookup = landcover_lookup
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    landcover,
    {
      la <- read_rast(landcover_all, lookup = landcover_lookup)

      la[[nlyr(la)]] |>
        writereadrast(
          filename = "outputs/raster/landcover.tif",
          layernames = "landcover"
        ) |>
        rast_path()
    },
    format = "file"
  ),

  tar_target(
    plot_landcover,
    plot_and_save(
      read_rast(landcover),
      title = "Landcover",
      fill_label = "Landcover\ntype",
      lookup = landcover_lookup,
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    arid,
    make_arid(
      read_rast(landcover),
      arid_lookup,
      filename = "outputs/raster/arid.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_arid,
    plot_and_save(
      read_rast(arid),
      title = "Aridity",
      fill_label = "Arid",
      lookup = arid_lookup,
      begin = 0.2,
      end = 0.65,
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    lst_day_all,
    prepare_multi_layer(
      read_rast(africa_mask),
      data_dir = "data/raster/MAP_covariates/LST_Day/",
      output_filename = "outputs/raster/lst_day_all.tif",
      layer_prefix = "lst_day",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*",
      filetype_suffix = ".tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    lst_day_mean,
    mean(read_rast(lst_day_all)) |>
      writereadrast(
        filename = "outputs/raster/lst_day_mean.tif",
        layernames = "lst_day_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_lst_day_mean,
    plot_and_save(
      read_rast(lst_day_mean),
      title = "Daytime Land Surface Temperature",
      fill_label = "°C", # degree symbol C
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    lst_night_all,
    prepare_multi_layer(
      africa_mask = read_rast(africa_mask),
      data_dir = "data/raster/MAP_covariates/LST_Night/",
      output_filename = "outputs/raster/lst_night_all.tif",
      layer_prefix = "lst_night",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*",
      filetype_suffix = ".tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    lst_night_mean,
    mean(read_rast(lst_night_all)) |>
      writereadrast(
        filename = "outputs/raster/lst_night_mean.tif",
        layernames = "lst_night_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_lst_night_mean,
    plot_and_save(
      read_rast(lst_night_mean),
      title = "Nighttime Land Surface Temperature",
      fill_label = "°C", # degree symbol C
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  #### rainfall
  # Annual rainfall totals from the CHIRPS dataset
  # (https://www.chc.ucsb.edu/data/chirps).
  # The 1km version here is a neareast-neighbour
  # resample of the lower resolution data
  # available from CHIRPS.

  tar_target(
    rainfall_all,
    prepare_multi_layer(
      read_rast(africa_mask),
      data_dir = "data/raster/MAP_covariates/Rainfall/",
      output_filename = "outputs/raster/rainfall_all.tif",
      layer_prefix = "rainfall",
      file_id_prefix = ".*v2-0\\.",
      file_id_suffix = "\\.Annual.*",
      filetype_suffix = ".tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    rainfall_mean,
    mean(read_rast(rainfall_all)) |>
      writereadrast(
        filename = "outputs/raster/rainfall_mean.tif",
        layernames = "rainfall_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_rainfall_mean,
    plot_and_save(
      read_rast(rainfall_mean),
      title = "Rainfall Annual Mean",
      fill_label = "mm",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    tcb_all,
    prepare_multi_layer(
      read_rast(africa_mask),
      data_dir = "data/raster/MAP_covariates/TCB/",
      output_filename = "outputs/raster/tcb_all.tif",
      layer_prefix = "tcb",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*",
      filetype_suffix = ".tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    tcb_mean,
    mean(read_rast(tcb_all)) |>
      writereadrast(
        filename = "outputs/raster/tcb_mean.tif",
        layernames = "tcb_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_tcb_mean,
    plot_and_save(
      read_rast(tcb_mean),
      title = "Tasselated Cap Brightness",
      fill_label = "TCB",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
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

  tar_target(
    tcw_all,
    prepare_multi_layer(
      read_rast(africa_mask),
      data_dir = "data/raster/MAP_covariates/TCW/",
      output_filename = "outputs/raster/tcw_all.tif",
      layer_prefix = "tcw",
      file_id_prefix = ".*v6\\.",
      file_id_suffix = "\\.Annual.*",
      filetype_suffix = ".tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    tcw_mean,
    mean(read_rast(tcw_all)) |>
      writereadrast(
        filename = "outputs/raster/tcw_mean.tif",
        layernames = "tcw_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_tcw_mean,
    plot_and_save(
      read_rast(tcw_mean),
      title = "Tasselated Cap Wetness",
      fill_label = "TCW",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  ## Surface water
  # Global Surface Water Explorer dataset
  # Joint Research Centre Data Catalogue
  # downloaded from
  # https://data.jrc.ec.europa.eu/dataset/jrc-gswe-global-surface-water-explorer-v1
  # using script data/download_surface_water.sh
  #
  # NB prepare_surface_water() short-circuits on outputs/raster/sw.tif if it
  # exists. Keep that file -- its source tiles (data/raster/surface_water/) are
  # no longer on disk, so it cannot be regenerated without re-downloading them.
  tar_target(
    surface_water,
    prepare_surface_water(
      read_rast(africa_mask)
    ) |>
      crop(read_rast(africa_mask)) |>
      mask(read_rast(africa_mask)) |>
      writereadrast(
        filename = "outputs/raster/surface_water.tif",
        layernames = "surface_water"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_surface_water,
    plot_and_save(
      read_rast(surface_water),
      filename = "surface_water.png",
      title = "Surface Water",
      fill_label = "%",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),


  ###### Geodata

  #### Wind speed
  # via `geodata` via bioclim

  tar_target(
    windspeed_all,
    get_bioclim(
      read_rast(africa_mask),
      filename = "outputs/raster/windspeed.tif",
      bioclim_var = "wind",
      layer_prefix = "windspeed"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    windspeed_mean,
    mean(read_rast(windspeed_all)) |>
      writereadrast(
        filename = "outputs/raster/windspeed_mean.tif",
        layernames = "windspeed_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_windspeed,
    plot_and_save(
      read_rast(windspeed_mean),
      filename = "windspeed.png",
      title = "Wind Speed Annual Mean",
      fill_label = expression(paste("m", "s"^{-1})),
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  #### Incident Solar Radiation
  # via `geodata` via bioclim

  tar_target(
    solrad_all,
    get_bioclim(
      read_rast(africa_mask),
      filename = "outputs/raster/solrad.tif",
      bioclim_var = "srad",
      layer_prefix = "solrad"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    solrad_mean,
    mean(read_rast(solrad_all)) |>
      writereadrast(
        filename = "outputs/raster/solrad_mean.tif",
        layernames = "solrad_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_solrad,
    plot_and_save(
      read_rast(solrad_mean),
      filename = "solrad.png",
      title = "Incident Solar Radiation",
      fill_label = expression(paste("kJ", "m"^{-2}, "d"^{-1})),
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  #### Vapour pressure
  # via `geodata` via bioclim

  tar_target(
    pressure_all,
    get_bioclim(
      read_rast(africa_mask),
      filename = "outputs/raster/pressure.tif",
      bioclim_var = "vapr",
      layer_prefix = "pressure"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    pressure_mean,
    mean(read_rast(pressure_all)) |>
      writereadrast(
        filename = "outputs/raster/pressure_mean.tif",
        layernames = "pressure_mean"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_pressure,
    plot_and_save(
      read_rast(pressure_mean),
      filename = "pressure.png",
      title = "Vapour Pressure",
      fill_label = "kPa",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  # elevation
  # via `geodata`

  tar_target(
    elevation,
    get_elevation(
      read_rast(africa_mask),
      filename = "outputs/raster/elevation.tif"
    ) |>
      rast_path(),
    format = "file"
  ),

  # tar_target(
  #   plot_elevation,
  #   plot_and_save(
  #     r = read_rast(elevation),
  #     title = "Elevation",
  #     #fill_label = "m",
  #     sub_plot_masks = read_sprc(country_masks),
  #     sub_plot_names = country_mask_names
  #   )
  # ),

  # footprint
  # via `geodata`
  # from https://www.nature.com/articles/sdata201667
  tar_target(
    footprint,
    footprint(
      year = 2009,
      path = "data/raster/geodata"
    ) |>
      crop(read_rast(africa_mask)) |>
      mask(read_rast(africa_mask)) |>
      writereadrast(
        filename = "outputs/raster/footprint.tif",
        layernames = "footprint"
      ) |>
      rast_path(),
    format = "file"
  ),

  # Soil data
  # via `geodata`

  # clay

  tar_target(
    soil_clay,
    get_soil_af(
      read_rast(africa_mask),
      filename = "outputs/raster/soil_clay.tif",
      var = "clay",
      layername = "soil_clay"
    ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_soil_clay,
    plot_and_save(
      read_rast(soil_clay),
      filename = "soil_clay.png",
      title = "Clay",
      fill_label = "%",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),

  ########################### gbif data




  ######################

  # microclimatic suitability for gambiae

  tar_target(
    ag_microclim,
    rast(x = "data/raster/An_gambiae_mechanistic_abundance.tif") |>
      max() |>
      match_ref(read_rast(africa_mask)) |>
      std_rast() |>
      writereadrast(
        filename = "outputs/raster/ag_microclim.tif",
        layernames = "ag_microclim"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    plot_ag_microclim,
    plot_and_save(
      read_rast(ag_microclim),
      filename = "ag_microclim.png",
      title = expression(italic("Anopheles gambiae")~microclimate~suitability),
      fill_label = "Relative\nsuitability",
      sub_plot_masks = read_sprc(country_masks),
      sub_plot_names = country_mask_names
    )
  ),


  ######################

  # Combine static layers

  # The layer list, in stack order. Kept as a plain target (not format = "file")
  # because each of these files is already hashed by its own target -- tracking
  # them again here would hash ~2 GB twice on every run.
  tar_target(
    static_var_files,
    c(
      ag_microclim,
      research_tt_by_country,
      accessibility,
      arid,
      built_height,
      built_surface,
      built_volume,
      cropland,
      elevation,
      evi_mean,
      footprint,
      # landcover, # factorial
      lst_day_mean,
      lst_night_mean,
      pop,
      pressure_mean,
      rainfall_mean,
      # settlement, # factorial
      settlement_prob,
      soil_clay,
      solrad_mean,
      surface_water,
      tcb_mean,
      tcw_mean,
      windspeed_mean,
      easting,
      northing
    )
  ),

  # layers left unstandardised in the _std stack (already on a 0-1 scale)
  tar_target(
    static_vars_unscaled,
    c(
      "ag_microclim",
      "research_tt_by_country",
      "arid"
    )
  ),

  tar_target(
    combined_africa_static_vars,
    combine_rasts(static_var_files) |>
      writereadrast(
        filename = "outputs/raster/combined_africa_static_vars.tif"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    combined_africa_static_vars_std,
    combine_rasts(
      static_var_files,
      standardise = TRUE,
      except = static_vars_unscaled
    ) |>
      writereadrast(
        filename = "outputs/raster/combined_africa_static_vars_std.tif"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    valid_cells_vect_combined,
    valid_cells_check(
      read_rast(africa_mask),
      read_rast(combined_africa_static_vars_std)
    )
  ),

  tar_target(
    new_mask,
    mask_from_all(read_rast(combined_africa_static_vars_std)) |>
      writereadrast(
        filename = "outputs/raster/new_mask.tif",
        layernames = "new_mask"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    africa_static_vars,
    read_rast(combined_africa_static_vars) |>
      mask(read_rast(new_mask)) |>
      writereadrast(
        filename = "outputs/raster/africa_static_vars.tif"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    africa_static_vars_std,
    read_rast(combined_africa_static_vars_std) |>
      mask(read_rast(new_mask)) |>
      writereadrast(
        filename = "outputs/raster/africa_static_vars_std.tif"
      ) |>
      rast_path(),
    format = "file"
  ),

  tar_target(
    valid_cells_vect,
    valid_cells_check(
      read_rast(new_mask),
      read_rast(africa_static_vars_std)
    )
  ),



  ######################

  # ESA CCI / C3S annual land cover from the Copernicus CDS
  # `satellite-land-cover`: 300 m, 1992-2022, 22-class UN FAO LCCS legend.
  # https://cds.climate.copernicus.eu/datasets/satellite-land-cover
  #
  # Branched by year. Each branch pulls one year and rescales it onto the
  # new_mask grid, so neither the global grid nor the 31-year stack is ever
  # held whole -- every terra step streams to disk, see
  # R/prepare_esa_landcover.R. An interrupted run resumes at the year it
  # stopped on, and years already downloaded are never re-fetched.
  #
  # NEEDS A CDS TOKEN. Once per machine:
  #   ecmwfr::wf_set_key(key = "<token from cds.climate.copernicus.eu/profile>")
  # plus accepting the ESA CCI and VITO licences on the dataset page above,
  # or every request comes back 403.
  #
  # MOVING THESE TARGETS TO ANOTHER PROJECT
  # The four R/esa_* and R/*_esa_landcover files are self-contained apart from
  # terra and ecmwfr, but these target definitions are NOT. They depend on two
  # things that live in this file, not in R/, and so will not travel:
  #   read_rast()  -- defined at the top of _targets.R
  #   new_mask     -- this project's analysis grid, itself a path target
  # In a new project either port read_rast() across as well, or drop it and
  # pass the reference grid straight in, e.g.
  #   prepare_esa_landcover(archive = ..., new_mask = terra::rast(<ref path>))
  # Nothing in the functions assumes the grid is 1 km or African: any
  # SpatRaster works as the target grid, and mode-resampling handles the rest.
  #
  # AS BUILT (2026-08-27, 1992-2022):
  #   esa_landcover_all  31 layers, 8705 x 8405, INT1U, categorical, 40 MB
  #   per-year tifs      225 MB total   |  source zips  13 GB (446 MB/year)
  #   legend             38 LCCS classes, read from the file, 0 = no_data
  # The zips are only needed to rebuild esa_landcover_year; they can be
  # deleted once the per-year tifs exist, at the cost of a re-download if a
  # branch is ever invalidated.

  tar_target(
    esa_landcover_years,
    1992:2022
  ),

  # c(N, W, S, E) for the CDS server-side subset, taken from the analysis grid
  # so the 129600 x 64800 global product never has to come down the wire
  tar_target(
    esa_landcover_box,
    esa_landcover_area(read_rast(new_mask)),
  ),

  tar_target(
    esa_landcover_zip,
    download_esa_landcover(
      year = esa_landcover_years,
      dest_dir = "data/raster/esa_landcover",
      area = esa_landcover_box
    ),
    pattern = map(esa_landcover_years),
    format = "file"
  ),

  # legend read from the NetCDF's own flag_values/flag_meanings
  tar_target(
    esa_landcover_lookup,
    esa_landcover_legend(esa_landcover_zip[1])
  ),

  tar_target(
    esa_landcover_year,
    prepare_esa_landcover(
      archive = esa_landcover_zip,
      new_mask = read_rast(new_mask),
      year = esa_landcover_years,
      outputdir = "outputs/raster/esa_landcover"
    ),
    pattern = map(esa_landcover_zip, esa_landcover_years),
    format = "file"
  ),

  # the deliverable: one multi-layer raster, one layer per year, on new_mask
  tar_target(
    esa_landcover_all,
    stack_esa_landcover(
      paths = esa_landcover_year,
      years = esa_landcover_years,
      lookup = esa_landcover_lookup,
      filename = "outputs/raster/esa_landcover_all.tif"
    ),
    format = "file"
  ),
  #####################

  tar_target(
    so_i_dont_have_to_go_backward_and_add_commas,
    print("Targets great in theory but kinda annoying to work with")
  )

)
