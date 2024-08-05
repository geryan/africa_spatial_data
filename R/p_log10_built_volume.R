p_log10_built_volume <- function(built_volume, africa_mask){

  r <- log10(built_volume)

  ggplot() +
    geom_spatraster(
      data = africa_mask
    ) +
    scale_fill_viridis_c(
      option = "G",
      begin = 1,
      end = 0,
      na.value = NA
    ) +
    geom_spatraster(
     data = r
    ) +
    theme_void() +
    scale_fill_viridis_c(
      option = "A",
      begin = 1,
      end = 0,
      na.value = NA
    )



}
