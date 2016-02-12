;;
;;Part of: Vicare Scheme
;;Contents: table of expand-time properties for condition objects core primitives
;;Date: Tue Dec 24, 2015
;;
;;Abstract
;;
;;
;;
;;Copyright (C) 2015, 2016 Marco Maggi <marco.maggi-ipsu@poste.it>
;;
;;This program is free  software: you can redistribute it and/or  modify it under the
;;terms  of  the  GNU General  Public  License  as  published  by the  Free  Software
;;Foundation, either version 3 of the License, or (at your option) any later version.
;;
;;This program  is distributed in the  hope that it  will be useful, but  WITHOUT ANY
;;WARRANTY; without  even the implied  warranty of  MERCHANTABILITY or FITNESS  FOR A
;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;
;;You should have received  a copy of the GNU General Public  License along with this
;;program.  If not, see <http://www.gnu.org/licenses/>.
;;

#!vicare
(library (typed-core-primitives condition-objects)
  (export typed-core-primitives.condition-objects)
  (import (vicare)
    (typed-core-primitives syntaxes))

(define (typed-core-primitives.condition-objects)


;;;; condition objects, safe procedures, generic condition object procedures

(section

(declare-type-predicate condition? <condition>)

(declare-core-primitive condition
    (safe)
  (signatures
   (<condition>		=> (<compound-condition>)))
  (attributes
   (_			effect-free result-true)))

(declare-core-primitive simple-conditions
    (safe)
  (signatures
   ((<condition>)		=> (<list>)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive condition-predicate
    (safe)
  (signatures
   ((<record-type-descriptor>)		=> (<procedure>)))
  (attributes
   ((_)			effect-free)))

(declare-core-primitive condition-accessor
    (safe)
  (signatures
   ((<record-type-descriptor> <procedure>)		=> (<procedure>))
   ((<record-type-descriptor> <procedure> <symbol>)	=> (<procedure>)))
  (attributes
   ((_ _)		effect-free result-true)
   ((_ _ _)		effect-free result-true)))

(declare-core-primitive print-condition
    (safe)
  (signatures
   ((<condition>)				=> (<void>))
   ((<condition> <textual-output-port>)		=> (<void>)))
  (attributes
   ((_)			result-true)
   ((_ _)		result-true)))

/section)


;;;; condition objects, safe procedures, specific condition object procedures

(section

;;; constructors

(let-syntax
    ((declare (syntax-rules ()
		((_ ?who ?type)
		 (declare-core-primitive ?who
		     (safe)
		   (signatures
		    (()			=> (?type)))
		   (attributes
		    (()			effect-free result-true))))
		)))
  (declare make-assertion-violation &assertion)
  (declare make-error &error)
  (declare make-expression-return-value-violation &expression-return-value-violation)
  (declare make-i/o-eagain &i/o-eagain)
  (declare make-i/o-error &i/o)
  (declare make-i/o-read-error &i/o-read)
  (declare make-i/o-write-error &i/o-write)
  (declare make-implementation-restriction-violation &implementation-restriction)
  (declare make-interrupted-condition &interrupted)
  (declare make-lexical-violation &lexical)
  (declare make-no-infinities-violation &no-infinities)
  (declare make-no-nans-violation &no-nans)
  (declare make-non-continuable-violation &non-continuable)
  (declare make-procedure-argument-violation &procedure-argument-violation)
  (declare make-serious-condition &serious)
  (declare make-undefined-violation &undefined)
  (declare make-violation &violation)
  (declare make-warning &warning)
  #| end of LET-SYNTAX |# )

(declare-core-primitive make-who-condition
    (safe)
  (signatures
   ((<false>)				=> (&who))
   ((<string>)				=> (&who))
   ((<symbol>)				=> (&who)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-message-condition
    (safe)
  (signatures
   ((<string>)		=> (&message)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-irritants-condition
    (safe)
  (signatures
   (_			=> (&irritants)))
  (attributes
   (_			effect-free result-true)))

(declare-core-primitive make-syntax-violation
    (safe)
  (signatures
   ((_ _)		=> (&syntax)))
  (attributes
   ((_ _)		effect-free result-true)))

(declare-core-primitive make-errno-condition
    (safe)
  (signatures
   ((<fixnum>)		=> (&errno)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-h_errno-condition
    (safe)
  (signatures
   ((<fixnum>)		=> (&h_errno)))
  (attributes
   ((_)			effect-free result-true)))


(declare-core-primitive make-i/o-port-error
    (safe)
  (signatures
   ((<port>)		=> (&i/o-port)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-invalid-position-error
    (safe)
  (signatures
   ((<top>)		=> (&i/o-invalid-position)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-filename-error
    (safe)
  (signatures
   ((<string>)		=> (&i/o-filename)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-file-protection-error
    (safe)
  (signatures
   ((<string>)		=> (&i/o-file-protection)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-decoding-error
    (safe)
  (signatures
   ((<port>)		=> (&i/o-decoding)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-encoding-error
    (safe)
  (signatures
   ((<port> <char>)	=> (&i/o-encoding)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-file-already-exists-error
    (safe)
  (signatures
   ((<string>)		=> (&i/o-file-already-exists)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-file-does-not-exist-error
    (safe)
  (signatures
   ((<string>)		=> (&i/o-file-does-not-exist)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-i/o-file-is-read-only-error
    (safe)
  (signatures
   ((<string>)		=> (&i/o-file-is-read-only)))
  (attributes
   ((_)			effect-free result-true)))

(declare-core-primitive make-source-position-condition
    (safe)
  (signatures
   ((<string> <exact-integer> <exact-integer> <exact-integer> <exact-integer>)
    => (&source-position)))
  (attributes
   ((_ _ _ _ _)			effect-free result-true)))

;;; --------------------------------------------------------------------
;;; predicates

(declare-condition-type-predicate assertion-violation? &assertion)
(declare-condition-type-predicate errno-condition? &errno)
(declare-condition-type-predicate error? &error)
(declare-condition-type-predicate expression-return-value-violation? &expression-return-value-violation)
(declare-condition-type-predicate h_errno-condition? &h_errno)
(declare-condition-type-predicate i/o-decoding-error? &i/o-decoding)
(declare-condition-type-predicate i/o-eagain-error? &i/o-eagain)
(declare-condition-type-predicate i/o-encoding-error? &i/o-encoding)
(declare-condition-type-predicate i/o-error? &i/o)
(declare-condition-type-predicate i/o-file-already-exists-error? &i/o-file-already-exists)
(declare-condition-type-predicate i/o-file-does-not-exist-error? &i/o-file-does-not-exist)
(declare-condition-type-predicate i/o-file-is-read-only-error? &i/o-file-is-read-only)
(declare-condition-type-predicate i/o-file-protection-error? &i/o-file-protection)
(declare-condition-type-predicate i/o-filename-error? &i/o-filename)
(declare-condition-type-predicate i/o-invalid-position-error? &i/o-invalid-position)
(declare-condition-type-predicate i/o-port-error? &i/o-port)
(declare-condition-type-predicate i/o-read-error? &i/o-read)
(declare-condition-type-predicate i/o-write-error? &i/o-write)
(declare-condition-type-predicate implementation-restriction-violation? &implementation-restriction)
(declare-condition-type-predicate interrupted-condition? &interrupted)
(declare-condition-type-predicate irritants-condition? &irritants)
(declare-condition-type-predicate lexical-violation? &lexical)
(declare-condition-type-predicate message-condition? &message)
(declare-condition-type-predicate no-infinities-violation? &no-infinities)
(declare-condition-type-predicate no-nans-violation? &no-nans)
(declare-condition-type-predicate non-continuable-violation? &non-continuable)
(declare-condition-type-predicate procedure-argument-violation? &procedure-argument-violation)
(declare-condition-type-predicate serious-condition? &serious)
(declare-condition-type-predicate source-position-condition? &source-position)
(declare-condition-type-predicate syntax-violation? &syntax)
(declare-condition-type-predicate undefined-violation? &undefined)
(declare-condition-type-predicate violation? &violation)
(declare-condition-type-predicate warning? &warning)
(declare-condition-type-predicate who-condition? &who)

;;; --------------------------------------------------------------------
;;; accessors

(letrec-syntax
    ((declare (syntax-rules ()
		((_ ?who ?type)
		 (declare ?who ?type <top>))
		((_ ?who ?type ?return-value-tag)
		 (declare-core-primitive ?who
		     (safe)
		   (signatures
		    ((?type)	=> (?return-value-tag)))
		   (attributes
		    ((_)		effect-free))))
		)))
  (declare condition-errno		&errno				<fixnum>)
  (declare condition-h_errno		&h_errno			<fixnum>)
  (declare condition-irritants		&irritants			<list>)
  (declare condition-message		&message			<string>)
  (declare i/o-encoding-error-char	&i/o-encoding)
  (declare i/o-error-filename		&i/o-filename)
  (declare i/o-error-port		&i/o-port			<port>)
  (declare i/o-error-position		&i/o-invalid-position)
  (declare syntax-violation-form	&syntax)
  (declare syntax-violation-subform	&syntax)

  (declare source-position-port-id	&source-position		<string>)
  (declare source-position-byte		&source-position		<exact-integer>)
  (declare source-position-character	&source-position		<exact-integer>)
  (declare source-position-line		&source-position		<exact-integer>)
  (declare source-position-column	&source-position		<exact-integer>)
  #| end of LET-SYNTAX |# )

(declare-core-primitive &who
    (safe)
  (signatures
   #;((&who)		=> ([or <false> <string> <symbol>]))
   ((&who)		=> (<top>)))
  (attributes
   ((_)			effect-free)))

/section)


;;;; condition objects, safe procedures, condition object raisers

(section

;;These are not effect-free because raising an exception is a "side effect".

(declare-core-primitive error
    (safe)
  (signatures
   ((<false>  <string> . <top>)			=> <no-return>)
   ((<symbol> <string> . <top>)			=> <no-return>)
   ((<string> <string> . <top>)			=> <no-return>)))

(declare-core-primitive assertion-violation
    (safe)
  (signatures
   ((<false>  <string> . <top>)			=> <no-return>)
   ((<symbol> <string> . <top>)			=> <no-return>)
   ((<string> <string> . <top>)			=> <no-return>)))

(declare-core-primitive syntax-violation
    (safe)
  (signatures
   ((<false>  <string> <top>)			=> <no-return>)
   ((<symbol> <string> <top>)			=> <no-return>)
   ((<string> <string> <top>)			=> <no-return>)
   ((<false>  <string> <top> <top>)		=> <no-return>)
   ((<symbol> <string> <top> <top>)		=> <no-return>)
   ((<string> <string> <top> <top>)		=> <no-return>)))

(declare-core-primitive warning
    (safe)
  (signatures
   ;;We do not know the number of returned values.
   ((<false>  <string> . <top>)			=> <no-return>)
   ((<symbol> <string> . <top>)			=> <no-return>)
   ((<string> <string> . <top>)			=> <no-return>)))

;;This is deprecated.
(declare-core-primitive die
    (safe)
  (signatures
   ((<false>  <string> . <top>)			=> <no-return>)
   ((<symbol> <string> . <top>)			=> <no-return>)
   ((<string> <string> . <top>)			=> <no-return>)))

(declare-core-primitive procedure-argument-violation
    (safe)
  (signatures
   ((<false>  <string> . <top>)			=> <no-return>)
   ((<symbol> <string> . <top>)			=> <no-return>)
   ((<string> <string> . <top>)			=> <no-return>)))

(declare-core-primitive expression-return-value-violation
    (safe)
  (signatures
   ((<false>  <string> . <top>)			=> <no-return>)
   ((<symbol> <string> . <top>)			=> <no-return>)
   ((<string> <string> . <top>)			=> <no-return>)))

/section)


;;;; done

#| end of define |# )

#| end of library |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8-unix
;; eval: (put 'declare-core-primitive		'scheme-indent-function 2)
;; End: