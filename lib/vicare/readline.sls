;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare Scheme
;;;Contents: bindings for GNU Readline
;;;Date: Tue Feb  7, 2012
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2012 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under the terms of the  GNU General Public License as published by
;;;the Free Software Foundation, either version 3 of the License, or (at
;;;your option) any later version.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!r6rs
(library (vicare readline)
  (export
    readline)
  (import (vicare)
    (vicare syntactic-extensions))


;;;; arguments validation

(define-argument-validation (prompt who obj)
  (or (bytevector? obj) (string? obj))
  (assertion-violation who "expected bytevector or string as prompt argument" obj))


;;;; access to C API

(define-inline (capi.readline prompt)
  (foreign-call "ik_readline_readline" prompt))


;;;; high-level API

(define (readline prompt)
  (define who 'readline)
  (with-arguments-validation (who)
      ((prompt	prompt))
    (with-bytevectors ((prompt.bv prompt))
      (let ((rv (capi.readline prompt.bv)))
	(ascii->string rv)))))


;;;; done

)

;;; end of file
;; Local Variables:
;; eval: (put 'with-bytevectors 'scheme-indent-function 1)
;; End:
