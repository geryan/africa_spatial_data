prepare_surface_water <- function(africa_mask){

  # process standing water tiles
  z <- import_rasts(
    path = "data/raster/surface_water/",
    ext = ".tif",
    as_list = TRUE
  )

  # rounded extent of Africa (new_mask)
  afext <- c(xmin = -20, xmax = 60, ymin = -40, ymax = 40)

  zz <- lapply(
    X = z,
    FUN = function(x){
      ext(x)[1:4] |>
        as.data.frame() |>
        t() |>
        as_tibble()
    }
  ) |>
    do.call(
      what = "bind_rows",
      args = _
    )

  zafidx <- zz |>
    mutate(
      xin = xmin >= afext[1],
      xax = xmax <= afext[2],
      yin = ymin >= afext[3],
      yax = ymax <= afext[4]
    ) |>
    rowwise() |>
    mutate(
      africa = all(xin, xax, yin, yax)
    ) |>
    pull(africa)

  zaf <- z[zafidx]

  zaf

  tt1 <- temptif()
  tt2 <- temptif()
  tt3 <- temptif()
  tt4 <- temptif()

  r1 <- zaf[1:16] |>
    sprc() |>
    merge(
      filename = tt1,
      overwrite = TRUE
    )

  r2 <- zaf[17:32] |>
    sprc() |>
    merge(
      filename = tt2,
      overwrite = TRUE
    )

  r3 <- zaf[33:48] |>
    sprc() |>
    merge(
      filename = tt3,
      overwrite = TRUE
    )

  r4 <- zaf[49:64] |>
    sprc() |>
    merge(
      filename = tt4,
      overwrite = TRUE
    )


  r1 <- rast(tt1)
  r2 <- rast(tt2)
  r3 <- rast(t3)
  r4 <- rast(tt4)


  rs1 <- resample(r1, africa_mask, filename = temptif())
  rs2 <- resample(r2, africa_mask, filename = temptif())
  rs3 <- resample(r3, africa_mask, filename = temptif())
  rs4 <- resample(r4, africa_mask, filename = temptif())


  r <- sprc(rs1, rs2, rs3, rs4) |>
    merge(
      filename = "outputs/raster/sw.tif",
      overwrite = TRUE
    )

  r

}
