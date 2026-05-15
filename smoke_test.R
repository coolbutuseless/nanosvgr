library(nanosvgr)

fn <- system.file("sailboat.svg", package = "nanosvgr", mustWork = TRUE)

# file path (existing path)
nsvg_file <- nsvg_read(fn)
cat("file path: nrow =", nrow(nsvg_file), "\n")

# text connection
con <- file(fn, open = "r")
nsvg_con <- nsvg_read(con)
close(con)
cat("connection: nrow =", nrow(nsvg_con), "\n")

# results should be identical
stopifnot(identical(nsvg_file, nsvg_con))
cat("identical: TRUE\n")
