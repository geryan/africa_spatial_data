#' Country mask on the same grid as the Africa-wide mask
#'
#' `sdmtools::make_africa_mask(type = "raster", ...)` builds a fresh raster from
#' the country polygon's own bounding box at a truncated 0.008333333 resolution,
#' so each country mask lands on its own arbitrary grid -- origins offset from
#' the analysis grid by up to ~3e-3 degrees. `terra::mask()` only tolerates an
#' extent mismatch of `tolerance * res` (0.1 * 0.0083 = 8.3e-4), so masking any
#' output raster by such a mask errors with "extents do not match".
#'
#' Cropping and masking `africa_mask` itself with the country vector keeps the
#' result a strict subset of the analysis grid instead.
make_country_mask <- function(
    africa_mask, # SpatRaster -- the Africa-wide mask, i.e. the analysis grid
    country, # ISO3 code, e.g. "COD"
    filename
  ){

  country_vect <- sdmtools::make_africa_mask(
    type = "vector",
    countries = country
  )

  africa_mask |>
    crop(country_vect) |>
    mask(country_vect) |>
    writereadrast(
      filename = filename,
      layernames = "mask"
    )

}
