mask_from_all <- function(r){

  j <- nlyr(r)

  if(j == 1){stop("Must have >1 layer")}

  k <- which(is.na(values(r[[1]])))

  for(i in 2:j){

    a <- which(is.na(values(r[[i]])))

    b <- c(k, a)

    d <- duplicated(b)

    k <- b[!d]

  }

  z <- r[[1]]

  z[] <- 1
  z[k] <- NA

  z

}
