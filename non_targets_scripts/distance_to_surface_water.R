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


# simple split into 4 bits with 6 degree overlap
# exts <- list(
#   ext(xmin, xmin + (xmax-xmin)/2 + 3, ymin + (ymax-ymin)/2 - 3, ymax),
#   ext(xmin + (xmax-xmin)/2 - 3, xmax, ymin + (ymax-ymin)/2 - 3, ymax),
#   ext(xmin, xmin + (xmax-xmin)/2 + 3, ymin, ymin + (ymax-ymin)/2 + 3),
#   ext(xmin + (xmax-xmin)/2 - 3, xmax, ymin, ymin + (ymax-ymin)/2 + 3)
# )


# split into 25 tiles with 3 degree overlap

# make sequences of mid points of tiles
xmids <- seq(
  from = xmin,
  to = xmax,
  length.out = 6
)

ymids <- seq(
  from = ymin,
  to = ymax,
  length.out = 6
)

# make trailing (west/south) and leading (east/north) edges by
# adding or subtracting 1.5 degrees to mids for edges not on edge
# of parent raster, i.e. first and last tiles
xleading  <- c(xmids[2:5] + 1.5, xmids[6])
xtrailing <- c(xmids[1], xmids[2:5] - 1.5)

yleading  <- c(ymids[2:5] + 1.5, ymids[6])
ytrailing <- c(ymids[1], ymids[2:5] - 1.5)

# make sequence of all edges
crop_dims <- expand_grid(
  tibble(xtrailing, xleading),
  tibble(ytrailing, yleading)
)

# convert edges to extent
exts <- pmap(
  .l = list(
    xt = crop_dims$xtrailing,
    xl = crop_dims$xleading,
    yt = crop_dims$ytrailing,
    yl = crop_dims$yleading
  ),
  .f = function(xt, xl, yt, yl){
    ext(xt, xl, yt, yl)
  }
)

# ma
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
