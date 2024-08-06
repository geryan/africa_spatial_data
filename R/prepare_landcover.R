prepare_landcover <- function(
    africa_mask,
    landcoverdir,
    landcoverfilename,
    lookup
){

  landcover <- list.files(
    path = landcoverdir,
    full.names = TRUE
  ) %>%
    sapply(
      FUN = rast
    ) %>%
    rast |>
    crop(africa_mask) |>
    mask(africa_mask)

  landcover_names <- names(landcover) |>
    sub(
      pattern = ".*Landcover\\.",
      replacement = "",
      x = _
    ) |>
    sub(
      pattern = "\\.Annual.*",
      replacement = "",
      x = _
    ) %>%
    paste0("landcover_", .)


  names(landcover) <- landcover_names

  nlr <- nlyr(landcover)

  for(i in 1:nlr){
    levels(landcover[[i]]) <- lookup
  }


  landcover <- writereadrast(
    landcover,
    filename = landcoverfilename
  )

  for(i in 1:nlr){
    levels(landcover[[i]]) <- lookup
  }

  landcover
}
