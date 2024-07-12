prepare_single_layer <- function(
    africa_mask,
    filename,
    lyrnm,
    outputdir = "outputs/raster/"
){
  rast(x = filename)  |>
    crop(africa_mask) |>
    mask(africa_mask) |>
    writereadrast(
      filename = sprintf(
        "%s/%s.tif",
        outputdir,
        lyrnm
      ),
      layernames = lyrnm
    )
}
