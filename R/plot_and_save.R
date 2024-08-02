plot_and_save <- function(
    r, # spatraster
    filename, # name of output image, e.g. plot.png
    title = NULL, # map title
    fill_label = NULL, # alter the fill label
    rm_guides = FALSE, # get rid of the guides
    output_dir = "outputs/figures/",
    option = "G",
    begin = 1,
    end = 0,
    fill_lims = NULL
  ){


  p <- ggplot() +
    geom_spatraster(
      data = r
    ) +
    scale_fill_viridis_c(
      option = option,
      begin = begin,
      end = end,
      na.value = "white"
    ) +
    theme_void()

  if(rm_guides){
    p <- p +
      guides(fill = "none")
  }

  if(!is.null(fill_lims)){
    p <- p +
      lims(fill = fill_lims)
  }

  if(!is.null(title)){
    p <- p +
      labs(title = title)
  }

  if(!is.null(fill_label)){
    p <- p +
      labs(fill = fill_label)
  }

  ggsave(
    filename = sprintf(
      "%/%",
      output_dir,
      filename
    ),
    plot = p,
    width = 2000,
    height = 1600,
    units = "px"
  )

}
