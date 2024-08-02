make_africa_mask_plot <- function(africa_mask){

  africa_mask_plot <- ggplot() +
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

  ggsave(
    filename = "outputs/figures/africa_mask.png",
    plot = africa_mask_plot,
    width = 2000,
    height = 1600,
    units = "px"
  )

  africa_mask_plot
}
