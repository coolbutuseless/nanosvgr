

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Invert the closed-ness of each shape
#' 
#' Some SVGs will have path closedness incorrectly set.  This is a helper function
#' to invert the closedness of all paths.  Try this if the plot output is empty.
#' 
#' @inheritParams nsvg_add_points
#' 
#' @examples
#' fn <- system.file("shuttle.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) |> nsvg_scale(0.3)
#' grid::grid.newpage(); plot(nsvg)
#' nsvg <- nsvg_invert_closedness(nsvg)
#' grid::grid.newpage(); plot(nsvg)
#' 
#' @return Modifed 'nsvg' object with the 'closed' status of all paths inverted
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_invert_closedness <- function(nsvg) {
  
  nsvg$beziers <- lapply(nsvg$beziers, function(p) {
    p$closed <- !p$closed
    p
  })
  
  if ('points' %in% names(nsvg)) {
    nsvg$points <- lapply(nsvg$points, function(p) {
      p$closed <- !p$closed
      p
    })
  }
  
  nsvg
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Scale nsvg object
#' 
#' @inheritParams nsvg_add_points
#' @param scalex,scaley scale factors. Default: 1
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' grid::grid.newpage(); plot(nsvg)
#' 
#' nsvg <- nsvg_scale(nsvg, 0.3)
#' grid::grid.newpage(); plot(nsvg)
#' 
#' @return Modified 'nsvg' object with all coordinates scaled by the given
#'         factors
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_scale <- function(nsvg, scalex = 1, scaley = scalex) {
  
  nsvg$beziers <- lapply(nsvg$beziers, function(df) {
    df$x <- df$x * scalex
    df$y <- df$y * scaley
    df
  })
  
  
  if ('points' %in% names(nsvg)) {
    nsvg$points <- lapply(nsvg$points, function(df) {
      df$x <- df$x * scalex
      df$y <- df$y * scaley
      df
    })
  }
  
  
  nsvg
}





#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Explode an nsvg object by shifting individual shapes
#' 
#' A simple demonstration of how we now have access to all the geometry
#' 
#' @inheritParams nsvg_add_points
#' @param scale scale factor for explosion. Default: 2
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) |> nsvg_scale(0.3)
#' grid::grid.newpage(); plot(nsvg)
#' nsvg <- nsvg_explode(nsvg, scale = 2)
#' grid::grid.newpage(); plot(nsvg)
#' 
#' @return Modified 'nsvg' object with all coordinates scaled by the given
#'         factors
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_explode <- function(nsvg, scale = 2) {
  
  nsvg$points <- lapply(nsvg$points, function(df) {
    
    xmean <- mean(df$x)
    ymean <- mean(df$y)
    
    df$x <- df$x + (scale - 1) * xmean
    df$y <- df$y + (scale - 1) * ymean
    
    df
  })
  
  
  nsvg
}






#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Conver nsvg object to grid graphics objects
#' 
#' 
#' 
#' @param nsvg nsvg object
#' @param n if beziers not yet flatted to points, will use this value
#' @inheritParams nsvg_unnest_points
#' 
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' grob <- nsvg_to_grob(nsvg)
#' grob
#' grid::grid.draw(grob)
#' 
#' @return A \code{grid} graphics grob
#' @import grid
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nsvg_to_grob <- function(nsvg, n = 20, inverty = TRUE) {
  
  if (!'points' %in% names(nsvg)) {
    nsvg <- nsvg_add_points(nsvg, n = n)
  }
  
  ymax <- vapply(nsvg$points, \(points) max(points$y), double(1))
  ymax <- max(ymax)
  
  grobs <- lapply(unique(nsvg$shape_idx), function(this_shape_idx) {
    
    i <- which(nsvg$shape_idx == this_shape_idx)
    
    points <- nsvg$points[[i]]
    
    if (isTRUE(inverty)) {
      y <- ymax - points$y
    } else {
      y <- points&y
    }
    
    
    gp <- grid::gpar(
      col       = nsvg$stroke   [[i]], 
      fill      = nsvg$fill     [[i]],
      alpha     = nsvg$alpha    [[i]],
      lty       = nsvg$lty      [[i]],
      lwd       = nsvg$lwd      [[i]],
      lineend   = nsvg$lineend  [[i]],
      linejoin  = nsvg$linejoin [[i]],
      linemitre = nsvg$linemitre[[i]]
    )
    
    
    if (points$closed[[1]]) {
      # Plot a polygon for closed paths
      grid::pathGrob(
        points$x, y, 
        id     = points$path_idx,   
        rule   = nsvg$fill_rule[[i]],
        default.units = 'points', 
        gp = gp
      )  
    } else {
      # Plot a polyline for open paths
      grid::polylineGrob(
        points$x, y, 
        id = points$path_idx, 
        default.units = 'points',
        gp = gp
      )  
    }
  })
  
  
  do.call(grid::grobTree, grobs)
}



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Plot SVG object
#' 
#' @param x nsvg object
#' @param ... ignored
#'
#' @examples
#' fn <- system.file("sailboat.svg", package = 'nanosvgr', mustWork = TRUE)
#' nsvg <- nsvg_read(fn) 
#' plot(nsvg)
#' 
#' @return return \code{nsvg} object invisibly
#' @import grid
#' @export
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
plot.nsvg <- function(x, ...) {
  
  grob <- nsvg_to_grob(x)
  grid::grid.draw(grob)
  
  invisible(x)
}


