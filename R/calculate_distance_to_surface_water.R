calculate_distance_to_surface_water <- function(
    surface_water,
    africa_mask
  ){

  swvals <- values(surface_water)

  swidx <- which(swvals > 0)
  naidx <- which(is.na(swvals))

  swd <- surface_water
  swd[] <- 1
  swd[naidx] <- 2
  swd[swidx] <- NA


  z <- distance(
    x = swd,
    exclude = 2
  )


}
