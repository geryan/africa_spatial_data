plot_and_save <- function(
    r, # spatraster
    filename = NULL, # name of output image, e.g. plot.png
    title = NULL, # map title
    fill_label = NULL, # alter the fill label
    rm_guides = FALSE, # get rid of the guides
    output_dir = "outputs/figures/",
    option = "G",
    begin = 1,
    end = 0,
    fill_lims = NULL,
    lookup = NULL
  ){

  if(is.null(filename)){
    if(is.null(title)){
      stop("filename and title missing")
    } else{
      warning("filename will be set from title")
      filename <- sprintf(
        "%s.png",
        tolower(title) |>
          gsub(
            pattern = " ",
            replacement = "_",
            x = _
          )
      )
    }
  }

  if(is.null(lookup)){
    categorical <- FALSE
  } else {
    categorical <- TRUE
    levels(r) <- lookup
  }


  p <- ggplot() +
    geom_spatraster(
      data = r
    ) +
    theme_void()

  if(categorical){
    p <- p +
      scale_fill_viridis_d(
      option = option,
      begin = begin,
      end = end,
      na.value = "white"
    )
  } else{
    p <- p +
      scale_fill_viridis_c(
        option = option,
        begin = begin,
        end = end,
        na.value = "white"
      )
  }

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
      "%s/%s",
      output_dir,
      filename
    ),
    plot = p,
    width = 2000,
    height = 1600,
    units = "px"
  )

}
