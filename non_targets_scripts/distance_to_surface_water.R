library(targets)
tar_load_globals()
tar_load_everything()
plot(surface_water)

# proof of concept

sw_cr <- crop(
  surface_water,
  ext(10, 15, -5, 0)
)

plot(sw_cr)

swvals <- values(sw_cr)

swidx <- which(swvals > 0)
naidx <- which(is.na(swvals))

swm <- sw_cr
swm[] <- NA
swm[naidx] <- 2
swm[swidx] <- 1

plot(swm)

swd <- distance(
  x = swm,
  exclude = 2
) |>
  mask(
    sw_cr
  )

plot(swd)


## Spartan code


.libPaths("~/home/user/R/gr_lib/")
library(terra)

surface_water <- rast("/data/gpfs/projects/punim1422/surface_water.tif")

plot(surface_water)

swvals <- values(surface_water)

swidx <- which(swvals > 0)
naidx <- which(is.na(swvals))

swm <- surface_water
swm[] <- NA
swm[naidx] <- 2
swm[swidx] <- 1

plot(swm)


extswm <- ext(swm)
xmin <- extswm$xmin
xmax <- extswm$xmax
ymin <- extswm$ymin
ymax <- extswm$ymax



exts <- list(
  ext(xmin, xmin + (xmax-xmin)/2 + 3, ymin + (ymax-ymin)/2 - 3, ymax),
  ext(xmin + (xmax-xmin)/2 - 3, xmax, ymin + (ymax-ymin)/2 - 3, ymax),
  ext(xmin, xmin + (xmax-xmin)/2 + 3, ymin, ymin + (ymax-ymin)/2 + 3),
  ext(xmin + (xmax-xmin)/2 - 3, xmax, ymin, ymin + (ymax-ymin)/2 + 3)
)


swm_cr <- lapply(
  exts,
  FUN = function(x, swm){
    crop(swm, x)
  },
  swm
)


swd_cr <- lapply(
  swm_cr,
  FUN = function(x){
    distance(
      x = x,
      exclude = 2
    )
  }
)
