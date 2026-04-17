

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' Calculate coordinates of bezier curves
#' 
#' @param x,y 4 coords for cubic beziers
#' @param t parmameterized position in range [0, 1]
#' @param n number of points to generate
#'
#' @noRd
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
bezier3_to_points_t <- function(x, y, t) {
  
  stopifnot(all(t >= 0 & t <= 1))
  
  x1a <- x[1] + (x[2] - x[1]) * t
  x1b <- x[2] + (x[3] - x[2]) * t
  x1c <- x[3] + (x[4] - x[3]) * t
  
  y1a <- y[1] + (y[2] - y[1]) * t
  y1b <- y[2] + (y[3] - y[2]) * t
  y1c <- y[3] + (y[4] - y[3]) * t
  
  x2a <- x1a + (x1b - x1a) * t
  x2b <- x1b + (x1c - x1b) * t
  
  y2a <- y1a + (y1b - y1a) * t
  y2b <- y1b + (y1c - y1b) * t
  
  x3 <- x2a + (x2b - x2a) * t
  y3 <- y2a + (y2b - y2a) * t
  
  structure(
    list(x = x3, y = y3),
    class = "data.frame",
    row.names = seq_along(x3)
  )
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' @rdname bezier3_to_points_t
#' @noRd
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
bezier3_to_points_n <- function(x, y, n) {
  stopifnot(exprs = {
    n >= 2
    length(x) == 4
    length(y) == 4
  })
  t <- seq(0, 1, length.out = n)
  bezier3_to_points_t(x, y, t)
}




if (FALSE) {
  x <- c(0, 0, 1, 1)
  y <- c(0, 1, 1, 0)
  
  pc <- bezier3_to_points_n(x, y, 20)
  pq <- bezier2_to_npoints(c(0, 0.5, 1), c(0, 1, 0), 20)
  
  library(grid)
  grid.newpage()
  grid.points(pc$x, pc$y, default.units = 'npc')
  grid.points(pq$x, pq$y, default.units = 'npc', gp = gpar(col = 'red'), pch = "+")  
  
}


