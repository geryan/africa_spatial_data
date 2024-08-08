prepare_single_layer_qed <- function(
    africa_mask,
    filename,
    lyrnm,
    outputdir = "outputs/raster/",
    overwrite = TRUE
){
  rast(x = filename)  |>
    project(africa_mask) |>
    crop(africa_mask) |>
    mask(africa_mask) |>
    writereadrast(
      filename = sprintf(
        "%s/%s.tif",
        outputdir,
        lyrnm
      ),
      layernames = lyrnm,
      overwrite = overwrite
    )
}
