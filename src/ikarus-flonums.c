/*
 * Ikarus Scheme -- A compiler for R6RS Scheme.
 * Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
 * Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
 *
 * This program is free software:  you can redistribute it and/or modify
 * it under  the terms of  the GNU General  Public License version  3 as
 * published by the Free Software Foundation.
 *
 * This program is  distributed in the hope that it  will be useful, but
 * WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
 * MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
 * General Public License for more details.
 *
 * You should  have received  a copy of  the GNU General  Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


/** --------------------------------------------------------------------
 ** Headers.
 ** ----------------------------------------------------------------- */

#include "internals.h"
#include <math.h>

static IK_UNUSED void
feature_failure_ (const char * funcname)
{
  ik_abort("called POSIX specific function, %s\n", funcname);
}

#define feature_failure(FN)     { feature_failure_(FN); return IK_VOID_OBJECT; }


/** --------------------------------------------------------------------
 ** Allocating flonums and cflonums.
 ** ----------------------------------------------------------------- */

ikptr_t
iku_flonum_alloc (ikpcb_t * pcb, double fl)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(X);
  IK_FLONUM_DATA(X) = fl;
  return X;
}
ikptr_t
iku_cflonum_alloc_and_init (ikpcb_t * pcb, double re, double im)
{
  IKU_DEFINE_AND_ALLOC_CFLONUM(X);
  IK_ASS(IK_CFLONUM_REAL(X), iku_flonum_alloc(pcb, re));
  IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CFLONUM_REAL_PTR(X));
  IK_ASS(IK_CFLONUM_IMAG(X), iku_flonum_alloc(pcb, im));
  IK_SIGNAL_DIRT_IN_PAGE_OF_POINTER(pcb, IK_CFLONUM_IMAG_PTR(X));
  return X;
}

/* ------------------------------------------------------------------ */

int
ik_is_flonum (ikptr_t X)
{
  return ((vector_tag == IK_TAGOF(X)) &&
	  (flonum_tag == IK_FLONUM_TAG(X)));
}
int
ik_is_cflonum (ikptr_t X)
{
  return ((vector_tag  == IK_TAGOF(X)) &&
	  (cflonum_tag == IK_CFLONUM_TAG(X)));
}


/** --------------------------------------------------------------------
 ** Flonum functions.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_fl_round (ikptr_t x, ikptr_t y)
{
  /* To avoid a warning with GCC one must either
     - invoke with -std=c99, or
     - declare "extern double round(double);", or
     - use the pre-C99 floor() and ceil(),

     double xx = IK_FLONUM_DATA(x);
     IK_FLONUM_DATA(y) = (xx>=0) ? floor(xx+0.5) : ceil(xx-0.5);

     The last of these seems most portable. (Barak A. Pearlmutter) */
#if 1
  /* IK_FLONUM_DATA(y) = rint(IK_FLONUM_DATA(x)); */
  IK_FLONUM_DATA(y) = round(IK_FLONUM_DATA(x));
#else
  double xx = IK_FLONUM_DATA(x);
  IK_FLONUM_DATA(y) = (xx>=0) ? floor(xx+0.5) : ceil(xx-0.5);
#endif
  return y;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_exp (ikptr_t x, ikptr_t y)
{
  IK_FLONUM_DATA(y) = exp(IK_FLONUM_DATA(x));
  return y;
}
ikptr_t
ikrt_fl_expm1 (ikptr_t x, ikptr_t y)
{
  IK_FLONUM_DATA(y) = expm1(IK_FLONUM_DATA(x));
  return y;
}
ikptr_t
ikrt_flfl_expt (ikptr_t a, ikptr_t b, ikptr_t z)
{
  IK_FLONUM_DATA(z) = exp(IK_FLONUM_DATA(b) * log(IK_FLONUM_DATA(a)));
  return z;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_plus (ikptr_t x, ikptr_t y, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = IK_FLONUM_DATA(x) + IK_FLONUM_DATA(y);
  return r;
}
ikptr_t
ikrt_fl_minus (ikptr_t x, ikptr_t y, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = IK_FLONUM_DATA(x) - IK_FLONUM_DATA(y);
  return r;
}
ikptr_t
ikrt_fl_times (ikptr_t x, ikptr_t y, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = IK_FLONUM_DATA(x) * IK_FLONUM_DATA(y);
  return r;
}
ikptr_t
ikrt_fl_div (ikptr_t x, ikptr_t y, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = IK_FLONUM_DATA(x) / IK_FLONUM_DATA(y);
  return r;
}
ikptr_t
ikrt_fl_invert (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = 1.0 / IK_FLONUM_DATA(x);
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_sin (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = sin(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_cos (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = cos(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_tan (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = tan(IK_FLONUM_DATA(x));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_asin (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = asin(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_acos (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = acos(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_atan (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = atan(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_atan2 (ikptr_t s_imp, ikptr_t s_rep, ikpcb_t* pcb)
/* Compute  the principal  value  of the  trigonometric  arc tangent  of
   flonum S_IMP  over flonum S_REP using  the signs of the  arguments to
   determine the quadrant of the result:

      \alpha = \atan (S_IMP/s_REP)

   in other words compute the angle \alpha such that:

                     \sin(\alpha)   S_IMP
      \tan(\alpha) = ------------ = -----
                     \cos(\alpha)   S_REP

   in yet other words compute the angle of the complex number having the
   flonum S_REP as real part and the flonum S_IMP as imaginary part:

      (angle (make-rectangular S_REP S_IMP))

   return a flonum. */
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = atan2(IK_FLONUM_DATA(s_imp), IK_FLONUM_DATA(s_rep));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_sqrt (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = sqrt(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_cbrt (ikptr_t x, ikpcb_t* pcb)
{
#ifdef HAVE_CBRT
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = cbrt(IK_FLONUM_DATA(x));
  return r;
#else
  feature_failure(__func__);
#endif
}
ikptr_t
ikrt_fl_log (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = log(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_log1p (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = log1p(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_hypot (ikptr_t x, ikptr_t y, ikpcb_t* pcb)
{
#ifdef HAVE_HYPOT
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = hypot(IK_FLONUM_DATA(x), IK_FLONUM_DATA(y));
  return r;
#else
  feature_failure(__func__);
#endif
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_sinh (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = sinh(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_cosh (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = cosh(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_tanh (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = tanh(IK_FLONUM_DATA(x));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fl_asinh (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = asinh(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_acosh (ikptr_t x, ikpcb_t* pcb) {
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = acosh(IK_FLONUM_DATA(x));
  return r;
}
ikptr_t
ikrt_fl_atanh (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = atanh(IK_FLONUM_DATA(x));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_bytevector_to_flonum (ikptr_t x, ikpcb_t* pcb)
{
  char *        data = IK_BYTEVECTOR_DATA_CHARP(x);
  double        v    = strtod(data, NULL);
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = v;
  return r;
}


/** --------------------------------------------------------------------
 ** Flonum functions: comparison.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_fl_equal (ikptr_t x, ikptr_t y)
{
  return (IK_FLONUM_DATA(x) == IK_FLONUM_DATA(y))? IK_TRUE_OBJECT : IK_FALSE_OBJECT;
}
ikptr_t
ikrt_fl_less_or_equal (ikptr_t x, ikptr_t y)
{
  return (IK_FLONUM_DATA(x) <= IK_FLONUM_DATA(y))? IK_TRUE_OBJECT : IK_FALSE_OBJECT;
}
ikptr_t
ikrt_fl_less (ikptr_t x, ikptr_t y) {
  return (IK_FLONUM_DATA(x) < IK_FLONUM_DATA(y))? IK_TRUE_OBJECT : IK_FALSE_OBJECT;
}


/** --------------------------------------------------------------------
 ** Fixnum functions.
 ** ----------------------------------------------------------------- */

ikptr_t
ikrt_fx_sqrt (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = sqrt(IK_UNFIX(x));
  return r;
}
ikptr_t
ikrt_fx_log (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = log(IK_UNFIX(x));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fx_sin (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = sin(IK_UNFIX(x));
  return r;
}
ikptr_t
ikrt_fx_cos (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = cos(IK_UNFIX(x));
  return r;
}
ikptr_t
ikrt_fx_tan (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = tan(IK_UNFIX(x));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fx_asin (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = asin(IK_UNFIX(x));
  return r;
}
ikptr_t
ikrt_fx_acos (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = acos(IK_UNFIX(x));
  return r;
}
ikptr_t
ikrt_fx_atan (ikptr_t x, ikpcb_t* pcb)
{
  IKU_DEFINE_AND_ALLOC_FLONUM(r);
  IK_FLONUM_DATA(r) = atan(IK_UNFIX(x));
  return r;
}

/* ------------------------------------------------------------------ */

ikptr_t
ikrt_fixnum_to_flonum (ikptr_t x, ikptr_t r)
{
  IK_FLONUM_DATA(r) = IK_UNFIX(x);
  return r;
}

/* end of file */
