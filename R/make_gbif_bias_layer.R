make_gbif_bias_lyr <- function(
  africa_countries,
  africa_mask
){
  # set up github credentials
  # https://docs.ropensci.org/rgbif/articles/gbif_credentials.html
  # usethis::edit_r_environ()
  # specify and save the below into the .Renviron file
  # GBIF_USER="jwaller"
  # GBIF_PWD="safe_fake_password_123"
  # GBIF_EMAIL="jwaller@gbif.org"
  # need to restart R after doing this


  # #### anopheles aedes culex only
  # occ_download(
  #   pred_or(
  #     pred("taxonKey", 7924646), # Aedes
  #     pred("taxonKey", 1650098), # Anopheles
  #     pred("taxonKey", 1497010) # Culex
  #   ),
  #   pred_in('country', africa_countries$iso2),
  #   pred("hasCoordinate", TRUE),
  #   format = "SIMPLE_CSV"
  # )

  # gbif_moz <- occ_download_get('0012794-241007104925546') |>
  #   occ_download_import(
  #     path = "data/gbif"
  #   )
  # Citation Info:
  #   Please always cite the download DOI when using this data.
  # https://www.gbif.org/citation-guidelines
  # DOI: 10.15468/dl.xywxdt
  # Citation:
  #   GBIF Occurrence Download https://doi.org/10.15468/dl.xywxdt Accessed from R via rgbif (https://github.com/ropensci/rgbif) on 2024-10-14

  mpoints <- gbif_moz |>
    select(
      lon = decimalLongitude,
      lat = decimalLatitude
    ) |>
    vect() |>
    writeVector(
      filename = "data/gbif/mpoints.gpkg"
    )

  gbif_moz |>
    select(
      lon = decimalLongitude,
      lat = decimalLatitude
    )

  mpoints <- vect("data/gbif/mpoints.gpkg")


  r <- rasterize(
    mpoints,
    africa_mask,
    fun = sum
  )

  count_rast <- africa_mask

  count_rast[which(!is.na(values(count_rast)))] <- 0

  rvs <- values(r)

  count_rast[which(!is.na(rvs))] <- rvs[which(!is.na(rvs))]


  window_count_rast <- focal(
    count_rast,
    w = 101,
    fun = "mean",
    na.policy = "omit",
    filename = "outputs/raster/gbif_culicidae_window.tif",
    overwrite = TRUE
  )

  surv_rast <- count_rast
  surv_rast[which(!is.na(rvs))] <- 1


  window_surv_rast <- focal(
    surv_rast,
    w = 101,
    fun = "mean",
    na.policy = "omit",
    filename = "outputs/raster/gbif_culicidae_window_surv.tif",
    overwrite = TRUE
  )


  ## animalia gbif
  # occ_download(
  #   pred('taxonKey', 1),
  #   pred_in('basisOfRecord',
  #           c("MACHINE_OBSERVATION", "HUMAN_OBSERVATION")),
  #   pred_in('country', africa_countries$iso2),
  #   pred('hasGeospatialIssue', "FALSE"),
  #   pred('occurrenceStatus', "PRESENT"),
  #   pred("hasCoordinate", TRUE),
  #   pred_lt("coordinateUncertaintyInMeters",500),
  #   pred_gte('year', 2010),
  #   format = "SIMPLE_CSV"
  # )

  # <<gbif download>>
  # occ_download_wait('0013122-241007104925546')
  # After it finishes, use
  # d <- occ_download_get('0013122-241007104925546') %>%
  #   occ_download_import()
  # to retrieve your download.

  # Download key: 0013122-241007104925546
  # Created: 2024-10-14T04:54:40.411+00:00
  # Citation Info:
  #   Please always cite the download DOI when using this data.
  # https://www.gbif.org/citation-guidelines
  # DOI: 10.15468/dl.7r5aka
  # Citation:
  #   GBIF Occurrence Download https://doi.org/10.15468/dl.7r5aka Accessed from R via rgbif (https://github.com/ropensci/rgbif) on 2024-10-14

  gbif_anim <- occ_download_get('0013122-241007104925546') |>
    occ_download_import(
      path = "data/gbif"
    )

}
