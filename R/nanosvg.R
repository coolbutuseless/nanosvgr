

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Convert a linedash specification from nanosvg into a lty specification 
#' for R graphics
#' 
#' @param linedash A vector of doubles defining on/off specification of the line
#'
#' @return string. Either "solid" or a a string of up to 8 characters
#'         giving the alternating lengths of dash and space.  See
#'         documentation for \code{par()} and \code{grid::gpar()}
#'         
#' @noRd
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
linedash_to_lty <- function(linedash) {
  if (length(linedash) == 0) {
    "solid"
  } else {
    
    if (length(linedash) > 8) {
      length(linedash) <- 8
    } else if (length(linedash) %% 2 != 0) {
      # trim off the last 'odd' dash spec
      # as this must be even for R par/gpar use
      linedash <- linedash[-length(linedash)]
    }
    
    
    
    # convert from sequence of integers to hex string
    #  e.g. c(5,10,5) -> "5a5"
    linedash |>
      ceiling() |>
      as.integer() |>
      pmin(15) |>
      as.hexmode() |>
      paste(collapse = "")
  }
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Read an SVG as geometry
#' 
#' @param filename SVG filename
#' @param n number of points to use when converting each bezier to a polyline.
#'        Default: 20.  Use "NA" to indicate that no conversion should be done.
#' @param units units to use. Default 'px'.  One of 'px', 'pt', 'pc' 'mm', 'cm', or 'in'
#' @param dpi dots per inch. Default: 96
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' head(nsvg[, 1:8])
#' grid::grid.newpage()
#' plot(nsvg)
#' # Manually change the fill color for each shape
#' nsvg$fill <- topo.colors(nrow(nsvg)) 
#' grid::grid.newpage()
#' plot(nsvg)
#' 
#' @return An \code{nsvg} object which is a data.frame of SVG data. 
#'         An SVG is made up of one-or-more \emph{shapes}.
#'         Each \emph{shape} contains one-or-more \emph{paths}.  Each \emph{path}
#'         is made of one-or-more \emph{cubic beziers}.  Each shape has a 
#'         set of graphical parameters
#' \describe{
#'   \item{\code{shape_idx}}{[int] Shape index.  Each SVG is defined as a number of shapes, 
#'         with each shape having a number of \emph{paths}.}
#'   \item{\code{fill}}{[chr] fill color}
#'   \item{\code{stroke}}{[chr] stroke color}
#'   \item{\code{alpha}}{[dbl] opacity in range [0, 1]}
#'   \item{\code{lwd}}{[dbl] line width}
#'   \item{\code{linejoin}}{[chr] Line join style.  'bevel', 'mitre' or 'round'}
#'   \item{\code{lineend}}{[chr] Line end style. 'round', 'butt', 'square'}
#'   \item{\code{linemitre}}{[dbl] Line mitre limit}
#'   \item{\code{linedash}}{[list] Raw list of line dash lengths for each shape}
#'   \item{\code{fill_rule}}{[chr] 'evenodd' or 'winding'}
#'   \item{\code{fill_type}}{[chr] 'flat', 'linear', 'radial', 'none', 'undef'}
#'   \item{\code{gradient}}{[list] Radial or linear gradient information for this shape}
#'   \item{\code{stroke_type}}{[chr] 'flat', 'linear', 'radial', 'none', 'undef'}
#'   \item{\code{beziers}}{[list] A list of data.frames - one data.frame for each
#'         shape containing the coordinates of the bezier control points 
#'         (Note: there are 4 control points for each cubic bezier).
#'         \describe{
#'            \item{\code{path_idx}}{[int] Index of path within shape}
#'            \item{\code{bez_idx}}{[int] Index of bezier with path}
#'            \item{\code{closed}}{[lgl] Is the path closed?}
#'            \item{\code{x}}{[dbl] x coordinate of bezier control points}
#'            \item{\code{y}}{[dbl] y coordinate of bezier control points}
#'         }
#'       }
#'   \item{\code{lty}}{[chr] Line type. Either 'solid' or a string of up to 8 
#'         characters (from c(1:9, "A":"F")) may be given, giving the length of 
#'         line segments which are alternatively drawn and skipped.  See
#'         \code{?graphics::par} for deails on Line Type Specification}
#'   \item{\code{points}}{[list] A list of data.frames - one data.frame for each
#'         shape containing the polylines derived from the beziers
#'         \describe{
#'            \item{\code{path_idx}}{[int] Index of path within shape}
#'            \item{\code{bez_idx}}{[int] Index of bezier with path}
#'            \item{\code{closed}}{[lgl] Is the path closed?}
#'            \item{\code{x}}{[dbl] x coordinate of polylines}
#'            \item{\code{y}}{[dbl] y coordinate of polylines}
#'         }
#'       }
#' }
#' @import colorfast
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_read <- function(filename, n = 20, units = 'px', dpi = 96) {
  filename <- normalizePath(filename, mustWork = TRUE)
  nsvg <- .Call(nsvg_read_, filename, units, dpi)
  
  nsvg$lty <- vapply(nsvg$linedash, linedash_to_lty, character(1))
  
  class(nsvg) <- c("nsvg", class(nsvg))
  
  if (!is.na(n)) {
    nsvg <- nsvg_add_points(nsvg, n = n)
  }
  
  
  nsvg
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Convert an SVG path to points
#' 
#' @param beziers data.frame for the beziers in making up a path.
#'        Each group of 4 points defines a bezier.
#' @param n number of segments for each bezier within this shape
#' 
#' @return data.frame of 'x' and 'y' coordinates of points along bezier
#' @noRd
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
beziers_to_points <- function(beziers, n) {
  
  polylines <- beziers |> 
    split(interaction(beziers$bez_idx, beziers$path_idx, drop = TRUE)) |> 
    lapply(function(b) {
      pts <- bezier3_to_points_n(b$x, b$y, n = n)
      
      cbind(
        path_idx = b$path_idx[1],
        bez_idx  = b$bez_idx[1],
        closed   = b$closed[1],
        pts
      )
    })
  
  do.call(rbind, polylines)
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Refresh points data to an nsvg object
#'
#' This is usually done as part of calling \code{nsvg_read()}, but can be
#' called separately if the points data needs to be calculated at a finer or
#' coarser level.
#'
#' @param nsvg 'nsvg' object created using \code{nsvg_read()} 
#' @param n number of points to use when converting each bezier to a polyline.
#'        Default: 20. 
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' # Use a very low resolution conversion. Only 3 points for each bezier.
#' nsvg <- nsvg_add_points(nsvg, n = 3)
#' 
#' @return 'nsvg' object with modified 'points' column.  This is a 
#'         list-column with each element being a data.frame of computed points
#'         along this path
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_add_points <- function(nsvg, n = 20) {
  
  nsvg$points <- nsvg$beziers |>
      lapply(function(beziers) {
        beziers_to_points(beziers, n)
      })
  
  nsvg
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Unnest SVG polylines into a single long data.frame
#' 
#' @inheritParams nsvg_add_points
#' @param inverty logical. Invert the y-axis? Default: TRUE
#' @param gpars logical. Include graphical parameters in result? Default: FALSE  
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' points <- nsvg_unnest_points(nsvg)
#' head(points)
#' 
#' @return data.frame with a row for each coordinate for each polyline calculated
#'         from the original beziers.
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_unnest_points <- function(nsvg, inverty = TRUE, gpars = FALSE) {
  
  if (!'points' %in% names(nsvg)) {
    nsvg <- nsvg_add_points(nsvg)
  }
  
  lens <- vapply(nsvg$points, nrow, integer(1))
  
  points <- do.call(rbind, nsvg$points)
  row.names(points) <- NULL

  indices      <- rep(seq_along(lens), lens)
  points <- cbind(shape_idx = nsvg$shape_idx[indices], points)
  
  if (isTRUE(inverty)) {
    points$y <- max(points$y) - points$y
  }
  
  if (isTRUE(gpars)) {
    gp <- nsvg
    gp$beziers <- NULL
    gp$points  <- NULL
    points <- merge(points, gp)
  }
  
  points
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Unnest SVG bezier coordinates into a single long data.frame
#' 
#' @inheritParams nsvg_unnest_points
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' bezs <- nsvg_unnest_beziers(nsvg)
#' head(bezs)
#' 
#' @return data.frame with a row for each bezier control point.
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_unnest_beziers <- function(nsvg, inverty = TRUE, gpars = FALSE) {
  
  stopifnot(exprs = {
    'beziers' %in% names(nsvg)
  })
  
  lens <- vapply(nsvg$beziers, nrow, integer(1))
  
  beziers <- do.call(rbind, nsvg$beziers)
  row.names(beziers) <- NULL
  
  indices <- rep(seq_along(lens), lens)
  beziers <- cbind(shape_idx = nsvg$shape_idx[indices], beziers)
  
  if (isTRUE(inverty)) {
    beziers$y <- max(beziers$y) - beziers$y
  }
  
  if (isTRUE(gpars)) {
    gp <- nsvg
    gp$beziers <- NULL
    gp$points  <- NULL
    beziers <- merge(beziers, gp)
  }
  
  beziers
}



