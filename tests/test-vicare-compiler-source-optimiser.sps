;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare
;;;Contents: tests for the source code optimiser
;;;Date: Mon Jul 14, 2014
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2014 Marco Maggi <marco.maggi-ipsu@poste.it>
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


#!vicare
(import (vicare)
  (prefix (vicare system $compiler) compiler.)
  (vicare unsafe operations)
  (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare optimiser\n")

(compiler.optimize-level 2)
(compiler.$source-optimizer-passes-count 2)
;;(compiler.$cp0-effort-limit 50)
;;(compiler.$cp0-size-limit   8)


;;;; syntax helpers



(parametrise ((check-test-name	'variable-references))

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;A variable reference evaluated for side effects only is removed.
	 x
	 (write x)))
    => '(let ((x_0 (read)))
	  (write x_0)))

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;A variable reference evaluated for side effects only is removed.
	 x x x x
	 (write x)))
    => '(let ((x_0 (read)))
	  (write x_0)))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;An assigment to a variable that is never referenced is useless.
	 (set! x 1)
	 123))
    => '(begin
	  (read)
	  (quote 123)))

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;An assigment to a variable that is never referenced is useless.
	 (set! x 1)
	 (set! x 1)
	 (set! x 1)
	 (set! x 1)
	 123))
    => '(begin
	  (read)
	  (quote 123)))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;A variable reference evaluated for side effects only is removed.
	 x
	 ;;An assigment to a variable that is never referenced is useless.
	 (set! x 1)
	 123))
    => '(begin
	  (read)
	  (quote 123)))

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;A variable reference evaluated for side effects only is removed.
	 x x x x
	 ;;An assigment to a variable that is never referenced is useless.
	 (set! x 1)
	 123))
    => '(begin
	  (read)
	  (quote 123)))

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;An assigment to a variable that is never referenced is useless.
	 (set! x 1)
	 ;;A variable reference evaluated for side effects only is removed.
	 x
	 123))
    => '(begin
	  (read)
	  (quote 123)))

  (check
      (optimisation-of
       (let ((x (read)))
	 ;;An assigment to a variable that is never referenced is useless.
	 (set! x 1)
	 ;;A variable reference evaluated for side effects only is removed.
	 x x x x
	 123))
    => '(begin
	  (read)
	  (quote 123)))

  #t)


(parametrise ((check-test-name	'fixnums))

  (check
      (optimisation-of (greatest-fixnum))
    => `(quote ,(greatest-fixnum)))

  (check
      (optimisation-of (least-fixnum))
    => `(quote ,(least-fixnum)))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of (fx+ 1 2))
    => '(quote 3))

  (check
      (optimisation-of (fx+ 1 (greatest-fixnum)))
    => `(fx+ '1 ',(greatest-fixnum)))

  (check
      (optimisation-of (fx+ -1 (least-fixnum)))
    => `(fx+ '-1 ',(least-fixnum)))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of ($fx+ 1 2))
    => '(quote 3))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of (fx- 1 2))
    => '(quote -1))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of ($fx- 1 2))
    => '(quote -1))

;;; --------------------------------------------------------------------

  (check
      (optimisation-of (fx* 11 22))
    => `(quote ,(fx* 11 22)))


  #t)


;;;; done

(check-report)

;;; end of file
;;Local Variables:
;;eval: (put 'catch 'scheme-indent-function 1)
;;End: