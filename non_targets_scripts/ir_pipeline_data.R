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


rast_multi_layer <- function(
    data_dir,
    output_filename,
    layer_prefix,
    file_id_prefix,
    file_id_suffix
){


  r <- list.files(
    path = data_dir,
    full.names = TRUE
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


pop_hist <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/pop_long_term/historic/",
  output_filename = temptif(),
  layer_prefix = "pop",
  file_id_prefix = ".*fix\\.",
  file_id_suffix = "\\.Annual.*"
)

pop_pred <- prepare_multi_layer(
  africa_mask = ref,
  data_dir = "data/raster/MAP_covariates/pop_long_term/projected/",
  output_filename = temptif(),
  layer_prefix = "pop",
  file_id_prefix = ".*projected\\.",
  file_id_suffix = "\\.Annual.*"
)

pop_ir <- c(pop_hist, pop_pred[[1:2]]) |>
  writereadrast(
    filename = "outputs/raster/ir/ir_pop.tif"
  )
2
