
// #define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

extern SEXP nsvg_read_(SEXP filename_, SEXP units_, SEXP dpi_);

static const R_CallMethodDef CEntries[] = {

  {"nsvg_read_", (DL_FUNC) &nsvg_read_, 3},
  {NULL , NULL, 0}
};


void R_init_nanosvgr(DllInfo *info) {
  R_registerRoutines(
    info,      // DllInfo
    NULL,      // .C
    CEntries,  // .Call
    NULL,      // Fortran
    NULL       // External
  );
  R_useDynamicSymbols(info, FALSE);
}



