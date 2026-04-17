
#define R_NO_REMAP

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <math.h>

#include <R.h>
#include <Rinternals.h>
#include <Rdefines.h>

#include <colorfast.h>
#include "utils.h"

#define NANOSVG_IMPLEMENTATION	// Expands implementation
#include "nanosvg.h"

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// Read SVG as beziers
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SEXP nsvg_read_(SEXP filename_, SEXP units_, SEXP dpi_) {
  
  int nprotect = 0;
  
  const char *filename = CHAR(STRING_ELT(filename_, 0));
  filename = (char *)R_ExpandFileName(filename);
  if (access(filename, R_OK) != 0) {
    Rf_error("nsvg_read_(): Cannot read from file '%s'", filename);
  }
  
  float dpi = (float)Rf_asReal(dpi_);
  const char *units = CHAR(STRING_ELT(units_, 0));
  
  
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // Parse the SVG into beziers
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  struct NSVGimage* image;
  struct NSVGshape *shape;
  struct NSVGpath  *path;
  image = nsvgParseFromFile(filename, units, dpi);
  if (image == NULL) {
    Rf_error("nsvg_read_(): Could not parse SVG data from '%s'", filename);
  }

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // Count the number of beziers
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // int npaths   = 0;
  int nshapes  = 0;
  
  for (shape = image->shapes; shape != NULL; shape = shape->next) {
    // for (path = shape->paths; path != NULL; path = path->next) {
    //   npaths++;
    // }
    nshapes++;
  }
  
  // nbeziers = (int)((float)nbeziers / 3.0);
  
  
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // Allocate a data.frame for the bezier coordinates
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  SEXP shape_        = PROTECT(Rf_allocVector(INTSXP , nshapes)); nprotect++;
  SEXP fill_         = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP stroke_       = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP opacity_      = PROTECT(Rf_allocVector(REALSXP, nshapes)); nprotect++;
  SEXP stroke_width_ = PROTECT(Rf_allocVector(REALSXP, nshapes)); nprotect++;
  SEXP line_join_    = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP line_end_     = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP mitre_limit_  = PROTECT(Rf_allocVector(REALSXP, nshapes)); nprotect++;
  SEXP line_dash_    = PROTECT(Rf_allocVector(VECSXP , nshapes)); nprotect++;
  SEXP fill_rule_    = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP fill_type_    = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP gradient_     = PROTECT(Rf_allocVector(VECSXP , nshapes)); nprotect++;
  SEXP stroke_type_  = PROTECT(Rf_allocVector(STRSXP , nshapes)); nprotect++;
  SEXP beziers_      = PROTECT(Rf_allocVector(VECSXP , nshapes)); nprotect++;
  
  SEXP res_ = PROTECT(create_named_list(
    14, 
    "shape_idx"   , shape_, 
    "fill"        , fill_, 
    "stroke"      , stroke_,
    "alpha"       , opacity_,
    "lwd"         , stroke_width_,
    "linejoin"    , line_join_,
    "lineend"     , line_end_,
    "linemitre"   , mitre_limit_,
    "linedash"    , line_dash_,
    "fill_rule"   , fill_rule_,
    "fill_type"   , fill_type_,
    "gradient"    , gradient_,
    "stroke_type" , fill_type_,
    "beziers"     , beziers_
  )); nprotect++;
  set_df_attributes(res_);
  
  int *pshape          = INTEGER(shape_);
  
  double *opacity      = REAL(opacity_);
  double *stroke_width = REAL(stroke_width_);
  double *mitre_limit  = REAL(mitre_limit_);

  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // Dump the coords
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  int shape_idx = 0;
  for (shape = image->shapes; shape != NULL; shape = shape->next) {
    
    char buf[20];
    *pshape++  = shape_idx + 1; // Convert to R index
    
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Shape-level properties
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    // Fill Color
    // NSVG_PAINT_UNDEF = -1,
    //   NSVG_PAINT_NONE = 0,
    //   NSVG_PAINT_COLOR = 1,
    //   NSVG_PAINT_LINEAR_GRADIENT = 2,
    //   NSVG_PAINT_RADIAL_GRADIENT = 3
    switch(shape->fill.type) {
    case NSVG_PAINT_COLOR:
      SET_STRING_ELT(fill_type_, shape_idx, Rf_mkChar("flat"));
      int_to_col(shape->fill.color, buf);
      SET_STRING_ELT(fill_, shape_idx, Rf_mkChar(buf));
      break;
    case NSVG_PAINT_LINEAR_GRADIENT:
      SET_STRING_ELT(fill_type_, shape_idx, Rf_mkChar("linear"));
      SET_STRING_ELT(fill_     , shape_idx, Rf_mkChar("hotpink"));
      break;
    case NSVG_PAINT_RADIAL_GRADIENT:
      SET_STRING_ELT(fill_type_, shape_idx, Rf_mkChar("radial"));
      SET_STRING_ELT(fill_     , shape_idx, Rf_mkChar("hotpink"));
      break;
    case NSVG_PAINT_NONE:
      SET_STRING_ELT(fill_type_, shape_idx, Rf_mkChar("none"));
      SET_STRING_ELT(fill_     , shape_idx, Rf_mkChar("#00000000"));
      break;
    default:
      SET_STRING_ELT(fill_type_, shape_idx, Rf_mkChar("undef"));
      SET_STRING_ELT(fill_     , shape_idx, Rf_mkChar("#00000000"));
    }
    
    // Gradients
    if (shape->fill.type == NSVG_PAINT_LINEAR_GRADIENT ||
        shape->fill.type == NSVG_PAINT_RADIAL_GRADIENT) {
      
      // Extract the radial gradient
      NSVGgradient *grad = shape->fill.gradient;
      
      SEXP offset_ = PROTECT(Rf_allocVector(REALSXP, grad->nstops));
      SEXP color_  = PROTECT(Rf_allocVector(STRSXP , grad->nstops));
      SEXP grad_ = PROTECT(create_named_list(
        2,
        "offset", offset_,
        "color" , color_
      ));
      set_df_attributes(grad_);
      
      NSVGgradientStop *stop = grad->stops;
      for (int i = 0; i < grad->nstops; i++) {
        REAL(offset_)[i] = (double)stop->offset;
        int_to_col(stop->color, buf);
        SET_STRING_ELT(color_, i, Rf_mkChar(buf));
        
        if (i == 0) {
          // Set the basic fill color to the first gradient color
          // for those systems which won't be able to plot a gradient
          // but want a sane color anyway.
          SET_STRING_ELT(fill_, shape_idx, Rf_mkChar(buf));
        }
        
        stop++;
      }
      
      SET_VECTOR_ELT(gradient_, shape_idx, grad_);
      UNPROTECT(3);
      
    }
    
    
    
    
    // stroke color
    switch(shape->stroke.type) {
    case NSVG_PAINT_COLOR:
      SET_STRING_ELT(stroke_type_, shape_idx, Rf_mkChar("flat"));
      int_to_col(shape->stroke.color, buf);
      SET_STRING_ELT(stroke_, shape_idx, Rf_mkChar(buf));
      break;
    case NSVG_PAINT_LINEAR_GRADIENT:
      SET_STRING_ELT(stroke_type_, shape_idx, Rf_mkChar("linear"));
      SET_STRING_ELT(stroke_     , shape_idx, Rf_mkChar("hotpink"));
      break;
    case NSVG_PAINT_RADIAL_GRADIENT:
      SET_STRING_ELT(stroke_type_, shape_idx, Rf_mkChar("radial"));
      SET_STRING_ELT(stroke_     , shape_idx, Rf_mkChar("hotpink"));
      break;
    case NSVG_PAINT_NONE:
      SET_STRING_ELT(stroke_type_, shape_idx, Rf_mkChar("none"));
      SET_STRING_ELT(stroke_     , shape_idx, Rf_mkChar("#00000000"));
      break;
    default:
      SET_STRING_ELT(stroke_type_, shape_idx, Rf_mkChar("undef"));
      SET_STRING_ELT(stroke_     , shape_idx, Rf_mkChar("#00000000"));
    }
     
    
    // other gpars
    *opacity++      = (double)shape->opacity;
    *stroke_width++ = (double)shape->strokeWidth;
    *mitre_limit++  = (double)shape->miterLimit;
    
    // line join
    switch(shape->strokeLineJoin) {
    case NSVG_JOIN_BEVEL: {
      SEXP join_ = PROTECT(Rf_mkChar("bevel"));
      SET_STRING_ELT(line_join_, shape_idx, join_);
      UNPROTECT(1);
    }
      break;
    case NSVG_JOIN_MITER: {
      SEXP join_ = PROTECT(Rf_mkChar("mitre"));
      SET_STRING_ELT(line_join_, shape_idx, join_);
      UNPROTECT(1);
    }
      break;
    case NSVG_JOIN_ROUND: {
      SEXP join_ = PROTECT(Rf_mkChar("round"));
      SET_STRING_ELT(line_join_, shape_idx, join_);
      UNPROTECT(1);
    }
      break;
    default:
      SET_STRING_ELT(line_join_, shape_idx, NA_STRING);
    }
    
    // line end
    switch(shape->strokeLineCap) {
    case NSVG_CAP_BUTT: {
      SEXP end_ = PROTECT(Rf_mkChar("butt"));
      SET_STRING_ELT(line_end_, shape_idx, end_);
      UNPROTECT(1);
    }
      break;
    case NSVG_CAP_ROUND: {
      SEXP end_ = PROTECT(Rf_mkChar("round"));
      SET_STRING_ELT(line_end_, shape_idx, end_);
      UNPROTECT(1);
    }
      break;
    case NSVG_CAP_SQUARE: {
      SEXP end_ = PROTECT(Rf_mkChar("square"));
      SET_STRING_ELT(line_end_, shape_idx, end_);
      UNPROTECT(1);
    }
      break;
    default:
      SET_STRING_ELT(line_end_, shape_idx, NA_STRING);
    }
    
    // fill rule
    switch(shape->fillRule) {
    case NSVG_FILLRULE_EVENODD: {
      SEXP rule_ = PROTECT(Rf_mkChar("evenodd"));
      SET_STRING_ELT(fill_rule_, shape_idx, rule_);
      UNPROTECT(1);
    }
      break;
    case NSVG_FILLRULE_NONZERO: {
      SEXP rule_ = PROTECT(Rf_mkChar("winding"));
      SET_STRING_ELT(fill_rule_, shape_idx, rule_);
      UNPROTECT(1);
    }
      break;
    default:
      SET_STRING_ELT(fill_rule_, shape_idx, NA_STRING);
    }
    
    // line dash
    int ndashes = shape->strokeDashCount;
    SEXP dash_ = PROTECT(Rf_allocVector(REALSXP, (R_xlen_t)ndashes));
    for (int i = 0; i < ndashes; i++) {
      REAL(dash_)[i] = shape->strokeDashArray[i];
    }
    SET_VECTOR_ELT(line_dash_, shape_idx, dash_);
    UNPROTECT(1);
    
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Pre-calculate total number of bezier points in this shape
    // This can happen over multiple paths
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    int npoints_in_shape = 0;
    for (path = shape->paths; path != NULL; path = path->next) {
      
      int nbeziers_in_path = (int)((path->npts - 1) / 3);
      int npoints_in_path  = 4 * nbeziers_in_path;
      
      npoints_in_shape += npoints_in_path;
    }
    
    SEXP path_idx_ = PROTECT(Rf_allocVector(INTSXP , npoints_in_shape)); 
    SEXP bez_idx_  = PROTECT(Rf_allocVector(INTSXP , npoints_in_shape)); 
    SEXP closed_   = PROTECT(Rf_allocVector(LGLSXP , npoints_in_shape)); 
    SEXP x_        = PROTECT(Rf_allocVector(REALSXP, npoints_in_shape)); 
    SEXP y_        = PROTECT(Rf_allocVector(REALSXP, npoints_in_shape)); 
    
    SEXP points_ = PROTECT(create_named_list(
      5,
      "path_idx", path_idx_,
      "bez_idx" , bez_idx_,
      "closed"  , closed_,
      "x"       , x_,
      "y"       , y_
    )); 
    set_df_attributes(points_);
    
    int    *ppath_idx = INTEGER(path_idx_);
    int    *pbez_idx  = INTEGER(bez_idx_);
    int    *pclosed   = LOGICAL(closed_);
    double *x         = REAL(x_);
    double *y         = REAL(y_);
    
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // coordinates for each path
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    int path_idx = 0;
    
    for (path = shape->paths; path != NULL; path = path->next) {
      
      // int nbeziers_in_path = (int)((path->npts - 1) / 3);
      // int npoints_in_path  = 4 * nbeziers_in_path;
      
      int bez_idx = 0;
      for (int i = 0; i < path->npts-1; i += 3) {
        float* p = &path->pts[i*2];
        
        *ppath_idx++ = path_idx + 1;
        *ppath_idx++ = path_idx + 1;
        *ppath_idx++ = path_idx + 1;
        *ppath_idx++ = path_idx + 1;
        
        *pbez_idx++ = bez_idx + 1;
        *pbez_idx++ = bez_idx + 1;
        *pbez_idx++ = bez_idx + 1;
        *pbez_idx++ = bez_idx + 1;
        
        *pclosed++ = path->closed;
        *pclosed++ = path->closed;
        *pclosed++ = path->closed;
        *pclosed++ = path->closed;
        
        *x++ = p[0];
        *x++ = p[2];
        *x++ = p[4];
        *x++ = p[6];

        *y++ = p[1];
        *y++ = p[3];
        *y++ = p[5];
        *y++ = p[7];
        
        bez_idx++;
      }
      
      path_idx++;
    }
    
    SET_VECTOR_ELT(beziers_, shape_idx, points_);
    UNPROTECT(6);
    shape_idx++;
  }
  
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // Tidy and return
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  nsvgDelete(image);
  UNPROTECT(nprotect);
  return res_;
}

