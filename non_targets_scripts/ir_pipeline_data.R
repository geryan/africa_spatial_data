# MAP's annual ITN and IRS coverage estimates

# annual stuff from AWS


# MAP's suite of annual climatic variables

# years:
# 2000:2024
#
# # MAP's population density, elevation layers, etc.
# # Based on the top performers here: https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3000633#sec021 and details and sources here: #42 , we also should get crop types/yields (e.g. from SPAM).
#
# lagged vars added to ml models
#
# ITN net-use 2000-2022
# IRS
# pop 2000-2020
# pop-future: 2021-2049 (to 2022
#
#                        )
#
#
# IR cube
# IR pipeline
# An stephensi
# Vector modelling

library(terra)
library(targets)
tar_load_globals()

#ref <- rast("data/raster/MAP_covariates/africa_masks/")


rast_multi_layer <- function(
    data_dir,
    output_filename,
    layer_prefix,
    file_id_prefix,
    file_id_suffix
){


  r <- list.files(
    path = data_dir,
    full.names = TRUE,
    pattern = "*.tif$"
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast

  r_names <- names(r) %>%
    sub(
      pattern = file_id_prefix,
      replacement = "",
      x = .
    ) %>%
    sub(
      pattern = file_id_suffix,
      replacement = "",
      x = .
    ) %>%
    sprintf(
      "%s_%s",
      layer_prefix,
      .
    )

  names(r) <- r_names

  writereadrast(
    r,
    output_filename
  )

}

# itn_use <- rast_multi_layer(
#   data_dir = "data/raster/MAP_covariates/ITN_use/",
#   output_filename = temptif(),
#   layer_prefix = "itn_use",
#   file_id_prefix = ".*ITN_",
#   file_id_suffix = "_use.*"
# )



irs <- rast_multi_layer(
  data_dir = "data/raster/MAP_covariates/IRS/",
  output_filename = temptif(),
  layer_prefix = "irs",
  file_id_prefix = ".*coverage_",
  file_id_suffix = ".tif"
)


irs_ir <- writereadrast(
  irs[[4:26]],
  filename = "outputs/raster/ir/ir_irs.tif"
)


ref <- irs_ir[[1]]

# itn_use_ir <- match_ref(
#   itn_use,
#   irs[[1]],
#   filename = "outputs/raster/ir/ir_itn.tif"
# )


itn_use <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/ITN_use/",
  output_filename = "outputs/raster/ir/ir_itn.tif",
  layer_prefix = "itn_use",
  file_id_prefix = ".*ITN_",
  file_id_suffix = "_use.*"
)


# population data
# read in 2000-2020 historic data

pop_hist <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/pop_long_term/historic/",
  output_filename = temptif(),
  layer_prefix = "pop",
  file_id_prefix = ".*fix\\.",
  file_id_suffix = "\\.Annual.*"
)

# get predicted data for 2021-22
pop_pred <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/pop_long_term/projected/",
  output_filename = temptif(),
  layer_prefix = "pop",
  file_id_prefix = ".*projected\\.",
  file_id_suffix = "\\.Annual.*"
)

# combine and save
pop_ir <- c(pop_hist, pop_pred[[1:2]]) |>
  writereadrast(
    filename = "outputs/raster/ir/ir_pop.tif"
  )


evi_ir <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/EVI/EVI_v061_5km_Annual_mean_mean/",
  output_filename = "outputs/raster/ir/ir_evi.tif",
  layer_prefix = "evi",
  file_id_prefix = ".*v061\\.",
  file_id_suffix = "\\.Annual.*"
)

lst_day_ir <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/LST_Day/LST_Day_v061_5km_annual_mean_mean/",
  output_filename = "outputs/raster/ir/ir_lst_day.tif",
  layer_prefix = "lst_day",
  file_id_prefix = ".*v061\\.",
  file_id_suffix = "\\.Annual.*"
)


lst_night_ir <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/LST_Night/LST_Night_v061_5km_annual_mean_mean/",
  output_filename = "outputs/raster/ir/ir_lst_night.tif",
  layer_prefix = "lst_night",
  file_id_prefix = ".*v061\\.",
  file_id_suffix = "\\.Annual.*"
)

tcb_ir <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/TCB/TCB_v061_5km_Annual_mean_mean/",
  output_filename = "outputs/raster/ir/ir_tcb.tif",
  layer_prefix = "tcb",
  file_id_prefix = ".*v061\\.",
  file_id_suffix = "\\.Annual.*"
)

tcw_ir <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/TCW/TCW_v061_5km_Annual_mean_mean/",
  output_filename = "outputs/raster/ir/ir_tcw.tif",
  layer_prefix = "tcw",
  file_id_prefix = ".*v061\\.",
  file_id_suffix = "\\.Annual.*"
)

irrigated_ir <- prepare_single_layer(
  africa_mask = ref,
  filename = "data/raster/MAP_covariates/irrigated_areas/Irrigated_Areas_Global_5k.tif",
  lyrnm = "irrigated",
  outputdir = "outputs/raster/ir/"
)

elevation_ir <- prepare_single_layer(
  africa_mask = ref,
  filename = "data/raster/MAP_covariates/Elevation/SRTM_elevation.Synoptic.Overall.Data.5km.mean.tif",
  lyrnm = "elevation",
  outputdir = "outputs/raster/ir/"
)



rainfall <- rast_multi_layer(
  data_dir = "data/raster/MAP_covariates/Rainfall/Annual/",
  output_filename = temptif(),
  layer_prefix = "rainfall",
  file_id_prefix = ".*v2-0\\.",
  file_id_suffix = "\\.Annual.*"
)


rainfall_ir <- writereadrast(
  rainfall[[11:33]] |> crop(ref) |> mask(ref),
  filename = "outputs/raster/ir/ir_rainfall.tif"
)



##
library(terra)
library(sdmtools)
pop_ir <- rast("outputs/raster/ir/ir_pop.tif")
irs_ir <- rast("outputs/raster/ir/ir_irs.tif")
itn_ir <- rast("outputs/raster/ir/ir_itn.tif")

ngaben <- make_africa_mask(
  type = "vector",
  countries = c("NGA", "BEN")
)

pop_ir_ngaben <- pop_ir |>
  crop(
    x = _,
    y = ngaben
  ) |>
  mask(
    x = _,
    mask = ngaben,
    filename = "outputs/raster/ir/ir_pop_ngaben.tif",
    overwrite = TRUE
  )


irs_ir_ngaben <- irs_ir |>
  crop(
    x = _,
    y = ngaben
  ) |>
  mask(
    x = _,
    mask = ngaben,
    filename = "outputs/raster/ir/ir_irs_ngaben.tif",
    overwrite = TRUE
  )

itn_ir_ngaben <- itn_ir |>
  crop(
    x = _,
    y = ngaben
  ) |>
  mask(
    x = _,
    mask = ngaben,
    filename = "outputs/raster/ir/ir_itn_ngaben.tif",
    overwrite = TRUE
  )
