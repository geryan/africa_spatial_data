valid_cells_check <- function(
    africa_mask,
    r
){

  z <- 1:nlyr(r)

  for(i in 1:length(z)){
    z[i] <- length(which(!is.na(values(r[[i]]))))
  }

  q <- length(which(!is.na(values(africa_mask))))

  q - z

}
