;;;Ikarus Scheme -- A compiler for R6RS Scheme.
;;;Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under  the terms of  the GNU General  Public License version  3 as
;;;published by the Free Software Foundation.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY or  FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received a  copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.


(module (assign-frame-sizes FRAME-CONFLICT-HELPERS)
  ;;
  ;;This module  accepts as  input a  struct instance of  type CODES,  whose internal
  ;;recordized code must be composed by struct instances of the following types:
  ;;
  ;;   asm-instr	conditional	constant
  ;;   asmcall		seq		shortcut
  ;;   locals		non-tail-call	non-tail-call-frame
  ;;
  ;;in  addition CLOSURE-MAKER  and  CODE-LOC  structs can  appear  in side  CONSTANT
  ;;structs.
  ;;
  ;;The only ASMCALL operators still accepted as input in this compiler pass are:
  ;;
  ;;   return			indirect-jump		direct-jump
  ;;   nop			interrupt		incr/zero?
  ;;   fl:double->single	fl:single->double
  ;;
  ;;
  ;;Recapitulation
  ;;--------------
  ;;
  ;;Let's clarify  where we  are when  this compiler  pass is  applied.  There  are 3
  ;;entities that we can compile: libraries, programs, standalone EVAL expressions.
  ;;
  ;;* After the previous compiler passes  the fact that a standalone expression might
  ;;  reference bindings  defined by previous standalone expressions  does not matter
  ;;  anymore; those references and  assignments have been converted into appropriate
  ;;  function calls.
  ;;
  ;;* After the  previous compiler passes: all  the code has been  reorganised into a
  ;;  set of CLAMBDA structs and an initialisation expression.
  ;;
  ;;* Every  clause in the  CLAMBDA structs  can be processed  independently, without
  ;;  informations from other clauses.
  ;;
  ;;* There is no significant difference between the body of a CLAMBDA clause and the
  ;;  body of the init expression; the body  of the init expression is like a CLAMBDA
  ;;  clause's body with no stack operands and no closure variables.
  ;;
  ;;So here we can just consider the  bodies; if we understand how a CLAMBDA clause's
  ;;body is processed we get everything.   Every body is an expression resulting from
  ;;the composition of subexpressions; the subexpressions form a tree-like hierarchy.
  ;;
  ;;In a  previous compiler pass: for  each body a  list of local variables  has been
  ;;gathered, representing  the temporary locations  needed to hold data  and partial
  ;;results from computations;  such lists are stored in LOCALS  structs.  Some local
  ;;variables exists only in branches of the tree, for example:
  ;;
  ;;   (conditional ?test
  ;;       (bind ((a ?rhs-a))
  ;;         ?conseq)
  ;;     (bind ((b ?rhs-b))
  ;;       ?altern))
  ;;
  ;;the local  A exists only  in the ?CONSEQ,  while the local  B exists only  in the
  ;;?ALTERN.  The set  of locals that exist  in a subexpression branch  is called the
  ;;"live set".
  ;;
  ;;Knowing which  locals are live  in a subexpression  and which are  shared between
  ;;subexpressions is needed to map locals to available CPU registers.
  ;;
  (define-syntax __module_who__
    (identifier-syntax 'assign-frame-sizes))

  (define (assign-frame-sizes x)
    (E-codes x))


(module INTEGER-SET
  ;;This module  implements sets of  bits; each set is  a nested hierarchy  of lists,
  ;;pairs and fixnums  interpreted as a tree; fixnums are  interpreted as bitvectors.
  ;;The empty set is the fixnum zero.
  ;;
  ;;To search for  a bit: we compute a  "bit index", then start from the  root of the
  ;;tree and: if  the index is even we go  left (the car), if the index  is odd we go
  ;;right (the cdr).
  ;;
  ;;This module has the same API of the module LISTY-SET.
  ;;
  (make-empty-set
   singleton
   set-member?		empty-set?
   set-add		set-rem
   set-difference	set-union
   set->list		list->set)

;;; --------------------------------------------------------------------

  (define-inline-constant BITS
    28)

  (define-syntax-rule (make-empty-set)
    0)

  (define-syntax-rule ($index-of N)
    ;;Given a set element N to be added  to, or searched into, a set: return a fixnum
    ;;representing the "index" of the fixnum in which N should be stored.
    ;;
    (fxquotient N BITS))

  (define ($mask-of n)
    ;;Given a set element N to be added  to, or searched into, a set: return a fixnum
    ;;representing the bitmask of N for the fixnum in which N should be stored.
    ;;
    (fxsll 1 (fxremainder n BITS)))

  (define (singleton N)
    ;;Return a set containing only N.
    ;;
    (set-add N (make-empty-set)))

;;; --------------------------------------------------------------------

  (define (empty-set? S)
    (eqv? S 0))

  (define* (set-member? {N fixnum?} SET)
    (let loop ((SET SET)
	       (idx ($index-of N))
	       (msk ($mask-of  N))) ;this never changes in the loop
      (cond ((pair? SET)
	     (if (fxeven? idx)
		 (loop (car SET) (fxsra idx 1) msk)
	       (loop (cdr SET) (fxsra idx 1) msk)))
	    ((fxzero? idx)
	     (fx=? msk (fxlogand SET msk)))
	    (else #f))))

  (define* (set-add {N fixnum?} SET)
    (let recur ((SET SET)
		(idx ($index-of N))
		(msk ($mask-of  N))) ;this never changes in the loop
      (cond ((pair? SET)
	     (if (fxeven? idx)
		 (let* ((a0 (car SET))
			(a1 (recur a0 (fxsra idx 1) msk)))
		   (if (eq? a0 a1)
		       SET
		     (cons a1 (cdr SET))))
	       (let* ((d0 (cdr SET))
		      (d1 (recur d0 (fxsra idx 1) msk)))
		 (if (eq? d0 d1)
		     SET
		   (cons (car SET) d1)))))
	    ((fxzero? idx)
	     (fxlogor SET msk))
	    (else
	     (if (fxeven? idx)
		 (cons (recur SET (fxsra idx 1) msk) 0)
	       (cons SET (recur 0 (fxsra idx 1) msk)))))))

  (define (cons^ A D)
    (if (and (eq? D 0)
	     (fixnum? A))
        A
      (cons A D)))

  (define* (set-rem {N fixnum?} SET)
    (let recur ((SET SET)
		(idx ($index-of N))
		(msk ($mask-of  N)))	;this never changes in the loop
      (cond ((pair? SET)
	     (if (fxeven? idx)
		 (let* ((a0 (car SET))
			(a1 (recur a0 (fxsra idx 1) msk)))
		   (if (eq? a0 a1)
		       SET
		     (cons^ a1 (cdr SET))))
	       (let* ((d0 (cdr SET))
		      (d1 (recur d0 (fxsra idx 1) msk)))
		 (if (eq? d0 d1)
		     SET
		   (cons^ (car SET) d1)))))
	    ((fxzero? idx)
	     (fxlogand SET (fxlognot msk)))
	    (else
	     SET))))

  (module (set-union)

    (define (set-union S1 S2)
      (if (pair? S1)
	  (if (pair? S2)
	      (if (eq? S1 S2)
		  S1
		(cons (set-union (car S1) (car S2))
		      (set-union (cdr S1) (cdr S2))))
	    (let ((a0 (car S1)))
	      (let ((a1 (set-union^ a0 S2)))
		(if (eq? a0 a1) S1 (cons a1 (cdr S1))))))
	(if (pair? S2)
	    (let ((a0 (car S2)))
	      (let ((a1 (set-union^ a0 S1)))
		(if (eq? a0 a1) S2 (cons a1 (cdr S2)))))
	  (fxlogor S1 S2))))

    (define (set-union^ S1 M2)
      (if (pair? S1)
	  (let* ((a0 (car S1))
		 (a1 (set-union^ a0 M2)))
	    (if (eq? a0 a1)
		S1
	      (cons a1 (cdr S1))))
	(fxlogor S1 M2)))

    #| end of module: set-union |# )

  (module (set-difference)

    (define (set-difference s1 s2)
      (cond ((pair? s1)
	     (if (pair? s2)
		 (if (eq? s1 s2)
		     0
		   (cons^ (set-difference (car s1) (car s2))
			  (set-difference (cdr s1) (cdr s2))))
	       (let* ((a0 (car s1))
		      (a1 (set-difference^ a0 s2)))
		 (if (eq? a0 a1)
		     s1
		   (cons^ a1 (cdr s1))))))
	    ((pair? s2)
	     (set-difference^^ s1 (car s2)))
	    (else
	     (fxlogand s1 (fxlognot s2)))))

    (define (set-difference^ S1 M2)
      (if (pair? S1)
	  (let* ((a0 (car S1))
		 (a1 (set-difference^ a0 M2)))
	    (if (eq? a0 a1)
		S1
	      (cons^ a1 (cdr S1))))
	(fxlogand S1 (fxlognot M2))))

    (define (set-difference^^ M1 S2)
      (if (pair? S2)
	  (set-difference^^ M1 (car S2))
	(fxlogand M1 (fxlognot S2))))

    #| end of module: set-difference |# )

  (module (list->set)

    (define* (list->set {ls list-of-fixnums?})
      (let recur ((ls ls)
		  (S  0))
	(if (pair? ls)
	    (recur (cdr ls) (set-add (car ls) S))
	  S)))

    (define (list-of-fixnums? obj)
      (and (list? obj)
	   (for-all fixnum? obj)))

    #| end of module: list->set |# )

  (define (set->list S)
    (let outer ((i  0)
		(j  1)
		(S  S)
		(ac '()))
      (if (pair? S)
	  (outer i (fxsll j 1) (car S)
		 (outer (fxlogor i j) (fxsll j 1) (cdr S) ac))
	(let inner ((i  (fx* i BITS))
		    (m  S)
		    (ac ac))
	  (if (fxeven? m)
	      (if (fxzero? m)
		  ac
		(inner (fxadd1 i) (fxsra m 1) ac))
	    (inner (fxadd1 i) (fxsra m 1) (cons i ac)))))))

  #| end of module: INTEGER-SET |# )


(module FRAME-CONFLICT-HELPERS
  (empty-var-set rem-var add-var union-vars mem-var? for-each-var init-var*!
   empty-nfv-set rem-nfv add-nfv union-nfvs mem-nfv? for-each-nfv init-nfv!
   empty-frm-set rem-frm add-frm union-frms mem-frm?
   empty-reg-set rem-reg add-reg union-regs mem-reg?)
  (import INTEGER-SET)

;;; --------------------------------------------------------------------
;;; VAR structs

  (module (init-var*!)

    (case-define init-var*!
      ((ls)
       (init-var*! ls 0))
      ((ls idx)
       (when (pair? ls)
	 (init-var!  (car ls) idx)
	 (init-var*! (cdr ls) (fxadd1 idx)))))

    (define (init-var! x i)
      ($set-var-index! x i)
      ($set-var-var-move! x (empty-var-set))
      ($set-var-reg-move! x (empty-reg-set))
      ($set-var-frm-move! x (empty-frm-set))
      ($set-var-var-conf! x (empty-var-set))
      ($set-var-reg-conf! x (empty-reg-set))
      ($set-var-frm-conf! x (empty-frm-set)))

    #| end of module |# )

  (define-syntax-rule (empty-var-set)
    ;;Build and return a new, empty VS set.
    ;;
    (make-empty-set))

  (define (add-var x vs)
    ;;Add the VAR struct X to the set VS.  Return the new set.
    ;;
    (set-add (var-index x) vs))

  (define (rem-var x vs)
    ;;Remove the VAR struct X from the set VS.  Return the new set.
    ;;
    (set-rem (var-index x) vs))

  (define (mem-var? x vs)
    ;;Return true if the VAR struct X is a member of te set VS.
    ;;
    (set-member? (var-index x) vs))

  (define-syntax-rule (union-vars ?vs1 ?vs2)
    ;;Build  and return  a new  VS set  holding  all the  members of  ?VS1 and  ?VS2;
    ;;duplicate members are included only once.
    ;;
    (set-union ?vs1 ?vs2))

  (define (for-each-var vs varvec func)
    (for-each (lambda (i)
		(func (vector-ref varvec i)))
      (set->list vs)))

;;; --------------------------------------------------------------------
;;; current frame stack operands

  (define-syntax-rule (empty-frm-set)
    ;;Build and return a new, empty FS set.
    ;;
    (make-empty-set))

  (define (add-frm x fs)
    ;;Add the FVAR struct X to the set FS.  Return the new set.
    ;;
    (set-add (fvar-idx x) fs))

  (define (rem-frm x fs)
    ;;Remove the FVAR struct X from the set FS.  Return the new set.
    ;;
    (set-rem (fvar-idx x) fs))

  (define (mem-frm? x fs)
    ;;Return true if the FVAR struct X is a member of the set FS.
    ;;
    (set-member? (fvar-idx x) fs))

  (define-syntax-rule (union-frms ?fs1 ?fs2)
    ;;Build  and return  a new  FS set  holding  all the  members of  ?FS1 and  ?FS2;
    ;;duplicate members are included only once.
    ;;
    (set-union ?fs1 ?fs2))

;;; --------------------------------------------------------------------
;;; CPU registers

  (define-syntax-rule (empty-reg-set)
    ;;Build and return a new, empty RS set.
    ;;
    (make-empty-set))

  (define (add-reg x rs)
    ;;Add the CPU register symbol name X to the set RS.  Return the new set.
    ;;
    (module (%cpu-register-name->index)
      (import INTEL-ASSEMBLY-CODE-GENERATION))
    (set-add (%cpu-register-name->index x) rs))

  (define (rem-reg x rs)
    ;;Remove the CPU register symbol name X from the set RS.  Return the new set.
    ;;
    (module (%cpu-register-name->index)
      (import INTEL-ASSEMBLY-CODE-GENERATION))
    (set-rem (%cpu-register-name->index x) rs))

  (define (mem-reg? x rs)
    ;;Return true if the CPU register symbol name X is a member of the set RS.
    ;;
    (module (%cpu-register-name->index)
      (import INTEL-ASSEMBLY-CODE-GENERATION))
    (set-member? (%cpu-register-name->index x) rs))

  (define-syntax-rule (union-regs ?rs1 ?rs2)
    ;;Build  and return  a new  RS set  holding  all the  members of  ?RS1 and  ?RS2;
    ;;duplicate members are included only once.
    ;;
    (set-union ?rs1 ?rs2))

;;; --------------------------------------------------------------------
;;; next frame stack operands

  (define (init-nfv! x)
    ($set-nfv-frm-conf! x (empty-frm-set))
    ($set-nfv-nfv-conf! x (empty-nfv-set))
    ($set-nfv-var-conf! x (empty-var-set)))

  (define-syntax-rule (empty-nfv-set)
    ;;Build and return a new, empty NS set.
    ;;
    '())

  (define (add-nfv x ns)
    ;;Add the NFV struct X to the set NS.  Return the new set.
    ;;
    (if (memq x ns)
	ns
      (cons x ns)))

  (define-syntax-rule (rem-nfv ?x ?ns)
    ;;Remove the NFV struct ?X from the set ?NS.  Return the new set.
    ;;
    (remq1 ?x ?ns))

  (define-syntax-rule (mem-nfv? ?x ?ns)
    ;;Return true if the NFV struct ?X is a member of the set ?NS.
    ;;
    (memq ?x ?ns))

  (define (union-nfvs ns1 ns2)
    ;;Build and return a new NS set holding all the members of NS1 and NS2; duplicate
    ;;members are included only once.
    ;;
    (let recur ((ns1 ns1)
		(ns2 ns2))
      (cond ((null? ns1)
	     ns2)
	    ((memq (car ns1) ns2)
	     (recur (cdr ns1) ns2))
	    (else
	     (cons (car ns1)
		   (recur (cdr ns1) ns2))))))

  (define-syntax-rule (for-each-nfv ?ns ?func)
    (for-each ?func ?ns))

  #| end of module: FRAME-CONFLICT-HELPERS |# )


(module (E-codes)

  (define (E-codes x)
    (struct-case x
      ((codes clam* body)
       (make-codes (map E-clambda clam*) (E-locals body)))))

  (define (E-clambda x)
    (struct-case x
      ((clambda label clause* cp freevar* name)
       (make-clambda label (map E-clambda-clause clause*) cp freevar* name))))

  (define (E-clambda-clause x)
    (struct-case x
      ((clambda-case info body)
       (make-clambda-case info (E-locals body)))))

  (define (E-locals x)
    ;;X must  be a struct instance  of type LOCALS.  Update  the field VARS of  X and
    ;;return a new struct instance of type LOCALS which is meant to replace X.
    ;;
    (module (init-var*!)
      (import FRAME-CONFLICT-HELPERS))
    (struct-case x
      ((locals vars body)
       (init-var*! vars)
       (let* ((vars.vec    (list->vector vars))
	      (call-live*  (%uncover-frame-conflicts body vars.vec))
	      (body        (%rewrite body vars.vec)))
	 (make-locals (cons vars.vec (%discard-vars-being-stack-operands vars)) body)))
      (else
       (compiler-internal-error __module_who__
	 "expected LOCALS struct as body form"
	 x))))

  (define (%discard-vars-being-stack-operands vars)
    ;;Tail-recursive function.  Given a list of  struct instances of type VAR, return
    ;;a new list containing only those having #f in the LOC field.
    ;;
    ;;The VAR  with a non-false LOC  fields have a  FVAR struct in it,  and represent
    ;;stack operands in closure object bodies.
    ;;
    (if (pair? vars)
	(if ($var-loc (car vars))
	    (%discard-vars-being-stack-operands (cdr vars))
	  (cons (car vars) (%discard-vars-being-stack-operands (cdr vars))))
      '()))

  #| end of module: E-codes |# )


(define (%uncover-frame-conflicts locals.body vars.vec)
  ;;The argument BODY is the body of a LOCALS struct; the LOCALS struct is either the
  ;;body of a CLAMBDA clause or the init expression of a CODES struct.  We know that,
  ;;after being processed by the previous compiler pass, it has as last form of every
  ;;branch a struct like:
  ;;
  ;;   (seq
  ;;     (asm-instr move (AA-REGISTER ?result))
  ;;     (asmcall return (AA-REGISTER AP-REGISTER FP-REGISTER PC-REGISTER)))
  ;;
  ;;Throughout this function the arguments VS, RS,  FS, NS are sets as defined by the
  ;;module FRAME-CONFLICT-HELPERS (they are not all instances of the same type):
  ;;
  ;;VS -	A collection of VAR structs ...
  ;;
  ;;RS -	A collection of register name symbols ...
  ;;
  ;;FS -	A collection of FVAR structs (current stack frame operands) ...
  ;;
  ;;NS -	A collection of NFV structs (next stack frame operands) ...
  ;;
  ;;The true work is done in the functions "R" and "E-asm-instr".
  ;;
  ;;Whenever a  SHORTCUT is processed: first  the interrupt handler is  processed and
  ;;the resulting  VS, RS,  FS, NS  are stored  (as vector  object) in  the parameter
  ;;EXCEPTION-LIVE-SET; then the body is processed, in the dynamic environment having
  ;;the parameter set.
  ;;
  (import INTEGER-SET)
  (import FRAME-CONFLICT-HELPERS)
  (module (register?
	   eax ecx edx
	   AA-REGISTER CP-REGISTER AP-REGISTER FP-REGISTER PC-REGISTER)
    (import INTEL-ASSEMBLY-CODE-GENERATION))

  (define spill-set
    ;;Whenever, at some point in the LOCALS.BODY, we perform a non-tail call: all the
    ;;temporary locations (VS) active right before  the a non-tail call must be saved
    ;;on the stack and restored before calling and restored right after the return.
    ;;
    ;;Such locations are collected in this set.
    (make-empty-set))

  (define exception-live-set
    (make-parameter #f))

  (define (main body)
    (T body)
    spill-set)

;;; --------------------------------------------------------------------

  (define (R x vs rs fs ns)
    ;;Recursive function, tail and non-tail.
    ;;
    (if (register? x)
	;;X is a symbol representing the name of a CPU register.
	(begin
	  #;(assert (memq x (list AA-REGISTER CP-REGISTER AP-REGISTER FP-REGISTER PC-REGISTER ecx edx)))
	  (values vs (add-reg x rs) fs ns))
      (struct-case x
	((fvar)
	 (values vs rs (add-frm x fs) ns))
	((var)
	 (values (add-var x vs) rs fs ns))
	((nfv)
	 (values vs rs fs (add-nfv x ns)))
	((disp objref offset)
	 (receive (vs rs fs ns)
	     (R objref vs rs fs ns)
	   (R offset vs rs fs ns)))
	((constant)
	 (values vs rs fs ns))
	((code-loc)
	 (values vs rs fs ns))
	(else
	 (compiler-internal-error __module_who__
	   "invalid recordised code processed by R"
	   (unparse-recordised-code/sexp x))))))

  (define (R* ls vs rs fs ns)
    ;;Recursive function,  tail and non-tail.   Apply R to every  item in LS  and the
    ;;other arguments.  Return the final VS, RS, FS, NS arguments.
    ;;
    (if (pair? ls)
	(receive (vs rs fs ns)
	    (R (car ls) vs rs fs ns)
	  (R* (cdr ls) vs rs fs ns))
      (values vs rs fs ns)))

;;; --------------------------------------------------------------------

  (define (T x)
    ;;Process the  recordised code X  as a form in  tail position.  In  tail position
    ;;there can be only structs of  type: SEQ, CONDITIONAL, SHORTCUT and ASMCALL with
    ;;operator among: RETURN, INDIRECT-JUMP, DIRECT-JUMP.
    ;;
    (struct-case x
      ((seq e0 e1)
       (receive (vs rs fs ns)
	   (T e1)
         (E e0 vs rs fs ns)))

      ((conditional test conseq altern)
       (let-values
	   (((vs.conseq rs.conseq fs.conseq ns.conseq) (T conseq))
	    ((vs.altern rs.altern fs.altern ns.altern) (T altern)))
         (P test
            vs.conseq rs.conseq fs.conseq ns.conseq
            vs.altern rs.altern fs.altern ns.altern
            (union-vars vs.conseq vs.altern)
            (union-regs rs.conseq rs.altern)
            (union-frms fs.conseq fs.altern)
            (union-nfvs ns.conseq ns.altern))))

      ((asmcall rator rand*)
       (case rator
         ((return indirect-jump direct-jump)
	  ;;This is the last form of the original input body.
          (R* rand*
	      (empty-var-set)
              (empty-reg-set)
              (empty-frm-set)
              (empty-nfv-set)))
         (else
	  (compiler-internal-error __module_who__
	    "invalid ASMCALL operator in tail position"
	    (unparse-recordized-code/sexp x)))))

      ((shortcut body handler)
       (receive (vs.handler rs.handler fs.handler ns.handler)
	   (T handler)
	 (parameterize
	     ((exception-live-set (vector vs.handler rs.handler fs.handler ns.handler)))
	   (T body))))

      (else
       (compiler-internal-error __module_who__
	 "invalid tail"
	 (unparse-recordized-code/sexp x)))))

;;; --------------------------------------------------------------------

  (define (P x
	     vs.conseq rs.conseq fs.conseq ns.conseq
	     vs.altern rs.altern fs.altern ns.altern
	     vs.union  rs.union  fs.union  ns.union)
    ;;Process  the recordised  code  X as  a  form in  predicate  position.  In  tail
    ;;position  there  can be  only  structs  of  type: SEQ,  CONDITIONAL,  SHORTCUT,
    ;;CONSTANT and ASM-INSTR with operator among: RETURN, INDIRECT-JUMP, DIRECT-JUMP.
    ;;
    (struct-case x
      ((seq e0 e1)
       (receive (vs rs fs ns)
	   (P e1
	      vs.conseq rs.conseq fs.conseq ns.conseq
	      vs.altern rs.altern fs.altern ns.altern
	      vs.union  rs.union  fs.union  ns.union)
         (E e0 vs rs fs ns)))

      ((conditional e0 e1 e2)
       (let-values
	   (((vs1 rs1 fs1 ns1)
	     (P e1
		vs.conseq rs.conseq fs.conseq ns.conseq
		vs.altern rs.altern fs.altern ns.altern
		vs.union  rs.union  fs.union  ns.union))
	    ((vs2 rs2 fs2 ns2)
	     (P e2
		vs.conseq rs.conseq fs.conseq ns.conseq
		vs.altern rs.altern fs.altern ns.altern
		vs.union  rs.union  fs.union  ns.union)))
         (P e0
            vs1 rs1 fs1 ns1
            vs2 rs2 fs2 ns2
            (union-vars vs1 vs2)
            (union-regs rs1 rs2)
            (union-frms fs1 fs2)
            (union-nfvs ns1 ns2))))

      ((constant x.const)
       (if x.const
           (values vs.conseq rs.conseq fs.conseq ns.conseq)
	 (values vs.altern rs.altern fs.altern ns.altern)))

      ((asm-instr op dst src)
       (R* (list dst src) vs.union  rs.union  fs.union  ns.union))

      ((shortcut body handler)
       (receive (vs.handler rs.handler fs.handler ns.handler)
	   (P handler
	      vs.conseq rs.conseq fs.conseq ns.conseq
	      vs.altern rs.altern fs.altern ns.altern
	      vs.union  rs.union  fs.union  ns.union)
	 (parameterize ((exception-live-set (vector vs.handler rs.handler fs.handler ns.handler)))
	   (P body
	      vs.conseq rs.conseq fs.conseq ns.conseq
	      vs.altern rs.altern fs.altern ns.altern
	      vs.union  rs.union  fs.union  ns.union))))

      (else
       (compiler-internal-error __module_who__ "invalid pred" (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

  (define (E x vs rs fs ns)
    (struct-case x

      ((seq e0 e1)
       (receive (vs rs fs ns)
	   (E e1 vs rs fs ns)
         (E e0 vs rs fs ns)))

      ((conditional e0 e1 e2)
       (let-values
	   (((vs1 rs1 fs1 ns1)  (E e1 vs rs fs ns))
	    ((vs2 rs2 fs2 ns2)  (E e2 vs rs fs ns)))
         (P e0
            vs1 rs1 fs1 ns1
            vs2 rs2 fs2 ns2
            (union-vars vs1 vs2)
            (union-regs rs1 rs2)
            (union-frms fs1 fs2)
            (union-nfvs ns1 ns2))))

      ((asm-instr op dst src)
       (E-asm-instr x op dst src vs rs fs ns))

      ((non-tail-call target value args mask size)
       ;;All the temporary  locations VS active right befor the  a non-tail call must
       ;;be saved on  the stack and restored before calling  and restored right after
       ;;the return.
       (set! spill-set (union-vars vs spill-set))
       (for-each-var
	   vs vars.vec
	 (lambda (x)
	   ($set-var-loc! x #t)))
       (R* args vs (empty-reg-set) fs ns))

      ((non-tail-call-frame nfv* live body)
       (for-each init-nfv! nfv*)
       (set-non-tail-call-frame-live! x (vector vs fs ns))
       (E body vs rs fs ns))

      ((asmcall op)
       (case op
         ((nop fl:double->single fl:single->double)
	  (values vs rs fs ns))
         ((interrupt incr/zero?)
          (let ((v (exception-live-set)))
            (if (vector? v)
		(values (vector-ref v 0)
			(vector-ref v 1)
			(vector-ref v 2)
			(vector-ref v 3))
              (compiler-internal-error __module_who__ "unbound exception2"))))
         (else
	  (compiler-internal-error __module_who__
	    "invalid ASMCALL operator in for effect form" op))))

      ((shortcut body handler)
       (receive (vs.handler rs.handler fs.handler ns.handler)
	   (E handler vs rs fs ns)
	 (parameterize
	     ((exception-live-set (vector vs.handler rs.handler fs.handler ns.handler)))
	   (E body vs rs fs ns))))

      (else
       (compiler-internal-error __module_who__ "invalid effect" (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

  (module (E-asm-instr)

    (define (E-asm-instr x op dst src vs rs fs ns)
      (case op
	((move load8 load32)
	 (E-asm-instr/move x op dst src vs rs fs ns))

	((int-/overflow int+/overflow int*/overflow)
	 (E-asm-instr/int-overflow x op dst src vs rs fs ns))

	((nop)
	 (values vs rs fs ns))

	((logand logor logxor sll sra srl int+ int- int* bswap! sll/overflow)
	 (E-asm-instr/bitwise x op dst src vs rs fs ns))

	((idiv)
	 (mark-reg/vars-conf! eax vs)
	 (mark-reg/vars-conf! edx vs)
	 (R src vs (add-reg eax (add-reg edx rs)) fs ns))

	((cltd)
	 (mark-reg/vars-conf! edx vs)
	 (R src vs (rem-reg edx rs) fs ns))

	((mset mset32 bset
	       fl:load fl:store fl:add! fl:sub! fl:mul! fl:div! fl:from-int
	       fl:shuffle fl:load-single fl:store-single)
	 (R* (list src dst) vs rs fs ns))

	(else
	 (compiler-internal-error __module_who__
	   "invalid ASM-INSTR operator in recordised code for effect"
	   (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

    (define (E-asm-instr/move x op dst src vs rs fs ns)
      ;;We expect the ASM-INSTR struct to have one of the formats:
      ;;
      ;;   (asm-instr move   (?dst ?src))
      ;;   (asm-instr load8  (?dst ?src))
      ;;   (asm-instr load32 (?dst ?src))
      ;;
      (cond ((register? dst)
	     (cond ((not (mem-reg? dst rs))
		    (set-asm-instr-op! x 'nop)
		    (values vs rs fs ns))
		   ;;In the following clauses we know that:
		   ;;
		   ;;   (mem-reg? dst rs) => #t
		   ;;
		   ((or (const? src)
			(disp?  src)
			(register?   src))
		    (let ((rs (rem-reg dst rs)))
		      (mark-reg/vars-conf! dst vs)
		      (R src vs rs fs ns)))
		   ((var? src)
		    (let ((rs (rem-reg dst rs))
			  (vs (rem-var src vs)))
		      (mark-var/reg-move! src dst)
		      (mark-reg/vars-conf! dst vs)
		      (values (add-var src vs) rs fs ns)))
		   ((fvar? src)
		    (let ((rs (rem-reg dst rs)))
		      (mark-reg/vars-conf! dst vs)
		      (values vs rs (add-frm src fs) ns)))
		   (else
		    (compiler-internal-error __module_who__ "invalid rs" (unparse-recordized-code x)))))

	    ((fvar? dst)
	     (cond ((not (mem-frm? dst fs))
		    (set-asm-instr-op! x 'nop)
		    (values vs rs fs ns))
		   ((or (const? src)
			(disp?  src)
			(register?   src))
		    (let ((fs (rem-frm dst fs)))
		      (mark-frm/vars-conf! dst vs)
		      (mark-frm/nfvs-conf! dst ns)
		      (R src vs rs fs ns)))
		   ((var? src)
		    (let ((fs (rem-frm dst fs))
			  (vs (rem-var src vs)))
		      (mark-var/frm-move! src dst)
		      (mark-frm/vars-conf! dst vs)
		      (mark-frm/nfvs-conf! dst ns)
		      (values (add-var src vs) rs fs ns)))
		   (else
		    (compiler-internal-error __module_who__ "invalid fs" src))))

	    ((var? dst)
	     (cond ((not (mem-var? dst vs))
		    (set-asm-instr-op! x 'nop)
		    (values vs rs fs ns))
		   ((or (disp? src) (constant? src))
		    (let ((vs (rem-var dst vs)))
		      (mark-var/vars-conf! dst vs)
		      (mark-var/frms-conf! dst fs)
		      (mark-var/regs-conf! dst rs)
		      (mark-var/nfvs-conf! dst ns)
		      (R src vs rs fs ns)))
		   ((register? src)
		    (let ((vs (rem-var dst vs))
			  (rs (rem-reg src rs)))
		      (mark-var/reg-move! dst src)
		      (mark-var/vars-conf! dst vs)
		      (mark-var/frms-conf! dst fs)
		      (mark-var/regs-conf! dst rs)
		      (mark-var/nfvs-conf! dst ns)
		      (values vs (add-reg src rs) fs ns)))
		   ((var? src)
		    (let ((vs (rem-var dst (rem-var src vs))))
		      (mark-var/var-move! dst src)
		      (mark-var/vars-conf! dst vs)
		      (mark-var/frms-conf! dst fs)
		      (mark-var/regs-conf! dst rs)
		      (mark-var/nfvs-conf! dst ns)
		      (values (add-var src vs) rs fs ns)))
		   ((fvar? src)
		    (let ((vs (rem-var dst vs))
			  (fs (rem-frm src fs)))
		      (mark-var/frm-move! dst src)
		      (mark-var/vars-conf! dst vs)
		      (mark-var/frms-conf! dst fs)
		      (mark-var/regs-conf! dst rs)
		      (mark-var/nfvs-conf! dst ns)
		      (values vs rs (add-frm src fs) ns)))
		   (else
		    (compiler-internal-error __module_who__ "invalid vs" src))))

	    ((nfv? dst)
	     (cond ((not (mem-nfv? dst ns))
		    (compiler-internal-error __module_who__ "dead nfv"))

		   ((or (disp?     src)
			(constant? src)
			(register?      src))
		    (let ((ns (rem-nfv dst ns)))
		      (mark-nfv/vars-conf! dst vs)
		      (mark-nfv/frms-conf! dst fs)
		      (R src vs rs fs ns)))

		   ((var? src)
		    (let ((ns (rem-nfv dst ns))
			  (vs (rem-var src vs)))
		      (mark-nfv/vars-conf! dst vs)
		      (mark-nfv/frms-conf! dst fs)
		      (values (add-var src vs) rs fs ns)))

		   ((fvar? src)
		    (let ((ns (rem-nfv dst ns))
			  (fs (rem-frm src fs)))
		      (mark-nfv/vars-conf! dst vs)
		      (mark-nfv/frms-conf! dst fs)
		      (values vs rs (add-frm src fs) ns)))

		   (else
		    (compiler-internal-error __module_who__
		      "invalid ns" src))))

	    (else
	     (compiler-internal-error __module_who__
	       "invalid d" dst))))

    (define (E-asm-instr/int-overflow x op dst src vs rs fs ns)
      ;;We expect the ASM-INSTR struct to have one of the formats:
      ;;
      ;;   (asm-instr int-/overflow (?dst ?src))
      ;;   (asm-instr int+/overflow (?dst ?src))
      ;;   (asm-instr int*/overflow (?dst ?src))
      ;;
      (let ((v (exception-live-set)))
	(unless (vector? v)
	  (compiler-internal-error __module_who__
	    "unbound exception" x v))
	(let ((vs (union-vars vs (vector-ref v 0)))
	      (rs (union-regs rs (vector-ref v 1)))
	      (fs (union-frms fs (vector-ref v 2)))
	      (ns (union-nfvs ns (vector-ref v 3))))
	  (cond ((var? dst)
		 (cond ((not (mem-var? dst vs))
			(set-asm-instr-op! x 'nop)
			(values vs rs fs ns))
		       (else
			(let ((vs (rem-var dst vs)))
			  (mark-var/vars-conf! dst vs)
			  (mark-var/frms-conf! dst fs)
			  (mark-var/nfvs-conf! dst ns)
			  (mark-var/regs-conf! dst rs)
			  (R src (add-var dst vs) rs fs ns)))))

		((register? dst)
		 (if (not (mem-reg? dst rs))
		     (values vs rs fs ns)
		   (let ((rs (rem-reg dst rs)))
		     (mark-reg/vars-conf! dst vs)
		     (R src vs (add-reg dst rs) fs ns))))

		((nfv? dst)
		 (if (not (mem-nfv? dst ns))
		     (compiler-internal-error __module_who__ "dead nfv")
		   (let ((ns (rem-nfv dst ns)))
		     (mark-nfv/vars-conf! dst vs)
		     (mark-nfv/frms-conf! dst fs)
		     (R src vs rs fs (add-nfv dst ns)))))

		(else
		 (compiler-internal-error __module_who__
		   "invalid op dst"
		   (unparse-recordized-code x)))))))

    (define (E-asm-instr/bitwise x op dst src vs rs fs ns)
      ;;We expect the ASM-INSTR struct to have one of the formats:
      ;;
      ;;   (asm-instr logand (?dst ?src))
      ;;   (asm-instr logor  (?dst ?src))
      ;;   (asm-instr logxor (?dst ?src))
      ;;   (asm-instr sll    (?dst ?src))
      ;;   (asm-instr sra    (?dst ?src))
      ;;   (asm-instr srl    (?dst ?src))
      ;;   (asm-instr int+   (?dst ?src))
      ;;   (asm-instr int-   (?dst ?src))
      ;;   (asm-instr int*   (?dst ?src))
      ;;   (asm-instr bswap! (?dst ?src))
      ;;   (asm-instr sll/overflow (?dst ?src))
      ;;
      (cond ((var? dst)
	     (cond ((not (mem-var? dst vs))
		    (set-asm-instr-op! x 'nop)
		    (values vs rs fs ns))
		   (else
		    (let ((vs (rem-var dst vs)))
		      (mark-var/vars-conf! dst vs)
		      (mark-var/frms-conf! dst fs)
		      (mark-var/nfvs-conf! dst ns)
		      (mark-var/regs-conf! dst rs)
		      (R src (add-var dst vs) rs fs ns)))))

	    ((register? dst)
	     (cond ((not (mem-reg? dst rs))
		    (set-asm-instr-op! x 'nop)
		    (values vs rs fs ns))
		   (else
		    (let ((rs (rem-reg dst rs)))
		      (mark-reg/vars-conf! dst vs)
		      (R src vs (add-reg dst rs) fs ns)))))

	    ((nfv? dst)
	     (if (not (mem-nfv? dst ns))
		 (compiler-internal-error __module_who__ "dead nfv")
	       (let ((ns (rem-nfv dst ns)))
		 (mark-nfv/vars-conf! dst vs)
		 (mark-nfv/frms-conf! dst fs)
		 (R src vs rs fs (add-nfv dst ns)))))

	    (else
	     (compiler-internal-error __module_who__
	       "invalid op dst" (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

    (define (mark-reg/vars-conf! r vs)
      (for-each-var
	  vs vars.vec
	(lambda (v)
	  ($set-var-reg-conf! v (add-reg r ($var-reg-conf v))))))

    (define (mark-frm/vars-conf! f vs)
      (for-each-var
	  vs vars.vec
	(lambda (v)
	  ($set-var-frm-conf! v (add-frm f ($var-frm-conf v))))))

    (define (mark-frm/nfvs-conf! f ns)
      (for-each-nfv
	  ns
	(lambda (n)
	  ($set-nfv-frm-conf! n (add-frm f ($nfv-frm-conf n))))))

    (define (mark-var/vars-conf! v vs)
      (for-each-var
	  vs vars.vec
	(lambda (w)
	  ($set-var-var-conf! w (add-var v ($var-var-conf w)))))
      ($set-var-var-conf! v (union-vars vs ($var-var-conf v))))

    (define (mark-var/frms-conf! v fs)
      ($set-var-frm-conf! v (union-frms fs ($var-frm-conf v))))

    (define (mark-var/regs-conf! v rs)
      ($set-var-reg-conf! v (union-regs rs ($var-reg-conf v))))

    (define (mark-var/nfvs-conf! v ns)
      (for-each-nfv
	  ns
	(lambda (n)
	  ($set-nfv-var-conf! n (add-var v ($nfv-var-conf n))))))

    (define (mark-nfv/vars-conf! n vs)
      ($set-nfv-var-conf! n (union-vars vs ($nfv-var-conf n))))

    (define (mark-nfv/frms-conf! n fs)
      ($set-nfv-frm-conf! n (union-frms fs ($nfv-frm-conf n))))

    (define (mark-nfv/nfvs-conf! n ns)
      ($set-nfv-nfv-conf! n (union-nfvs ns ($nfv-nfv-conf n)))
      (for-each-nfv
	  ns
	(lambda (m)
	  ($set-nfv-nfv-conf! m (add-nfv n ($nfv-nfv-conf m))))))

    (define (mark-var/var-move! x y)
      ($set-var-var-move! x (add-var y ($var-var-move x)))
      ($set-var-var-move! y (add-var x ($var-var-move y))))

    (define (mark-var/frm-move! x y)
      ($set-var-frm-move! x (add-frm y ($var-frm-move x))))

    (define (mark-var/reg-move! x y)
      ($set-var-reg-move! x (add-reg y ($var-reg-move x))))

    (define (const? x)
      (or (constant? x)
	  (code-loc? x)))

    #| end of module: E-asm-instr |# )

;;; --------------------------------------------------------------------

  (main locals.body))


(define (%rewrite x vars.vec)
  ;;X must be a struct instance representing a recordized body.
  ;;
  ;;A lot of functions  are nested here because they need to  close upon the argument
  ;;VARS.VEC.
  ;;
  (module (set-member? set-difference set->list)
    (import INTEGER-SET))
  (module (for-each-var rem-nfv add-frm)
    (import FRAME-CONFLICT-HELPERS))
  (module (register?)
    (import INTEL-ASSEMBLY-CODE-GENERATION))

  (define (R x)
    (if (register? x)
	x
      (struct-case x
	((constant)
	 x)
	((fvar)
	 x)
	((nfv)
	 (or ($nfv-loc x)
	     (compiler-internal-error __module_who__
	       "invali NFV struct without assigned LOC")))
	((var)
	 (Var x))
	((disp objref offset)
	 (make-disp (R objref) (R offset)))
	(else
	 (compiler-internal-error __module_who__
	   "invalid R" (unparse-recordized-code x))))))

;;; --------------------------------------------------------------------

  (define (T x)
    ;;Process the struct instance X representing recordized  code as if it is in tail
    ;;position.
    ;;
    (struct-case x
      ((seq e0 e1)
       (let ((e0^ (E e0)))
	 (make-seq e0^ (T e1))))

      ((conditional e0 e1 e2)
       (make-conditional (P e0) (T e1) (T e2)))

      ((asmcall op args)
       x)

      ((shortcut body handler)
       (make-shortcut (T body) (T handler)))

      (else
       (compiler-internal-error __module_who__
	 "invalid tail expression" (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

  (define (P x)
    (struct-case x
      ((seq e0 e1)
       (let ((e0^ (E e0)))
	 (make-seq e0^ (P e1))))

      ((conditional e0 e1 e2)
       (make-conditional (P e0) (P e1) (P e2)))

      ((asm-instr op dst src)
       (make-asm-instr op (R dst) (R src)))

      ((constant)
       x)

      ((shortcut body handler)
       (make-shortcut (P body) (P handler)))

      (else
       (compiler-internal-error __module_who__
	 "invalid pred" (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

  (module (E)

    (define (E x)
      (struct-case x
	((seq e0 e1)
	 (let ((e0^ (E e0)))
	   (make-seq e0^ (E e1))))

	((conditional e0 e1 e2)
	 (make-conditional (P e0) (E e1) (E e2)))

	((asm-instr op dst src)
	 (E-asm-instr x op dst src))

	((non-tail-call-frame vars live body)
	 (E-non-tail-call-frame vars live body))

	((asmcall op args)
	 (case op
	   ((nop interrupt incr/zero? fl:double->single fl:single->double)
	    x)
	   (else
	    (compiler-internal-error __module_who__
	      "invalid ASMCALL operator in recordised code for side effects"
	      (unparse-recordised-code/sexp x)))))

	((shortcut body handler)
	 (make-shortcut (E body) (E handler)))

	(else
	 (compiler-internal-error __module_who__
	   "invalid recordised code for effects"
	   (unparse-recordized-code x)))))

    (define (E-asm-instr x op dst src)
      (case op
	((move load8 load32)
	 ;;If  the   destination  equals  the  source:   convert  this
	 ;;instruction into a NOP.
	 (let ((dst (R dst))
	       (src (R src)))
	   (if (eq? dst src)
	       (nop)
	     (make-asm-instr op dst src))))

	(( ;;some assembly instructions
	  logand		logor		logxor
	  int+			int-		int*
	  mset			mset32
	  bset			bswap!
	  sll			sll/overflow
	  sra			srl
	  cltd			idiv
	  int-/overflow		int+/overflow	int*/overflow
	  fl:load		fl:store
	  fl:add!		fl:sub!		fl:mul!		fl:div!
	  fl:from-int		fl:shuffle	fl:load-single	fl:store-single)
	 (make-asm-instr op (R dst) (R src)))

	((nop)
	 (nop))

	(else
	 (compiler-internal-error __module_who__
	   "invalid ASM-INSTR operator in recordised code for side effects"
	   (unparse-recordised-code/sexp x)))))

    (define (E-non-tail-call-frame vars live body)
      (let ((live-frms1 (map (lambda (i)
			       (Var (vector-ref vars.vec i)))
			  (set->list (vector-ref live 0))))
	    (live-frms2 (set->list (vector-ref live 1)))
	    (live-nfvs  (vector-ref live 2)))

	(define (max-frm ls i)
	  (if (pair? ls)
	      (max-frm (cdr ls) (max i ($fvar-idx (car ls))))
	    i))

	(define (max-ls ls i)
	  (if (pair? ls)
	      (max-ls  (cdr ls) (max i (car ls)))
	    i))

	(define (max-nfv ls i)
	  (if (pair? ls)
	      (let ((loc ($nfv-loc (car ls))))
		(unless (fvar? loc)
		  (compiler-internal-error __module_who__ "FVAR not assigned in MAX-NFV" loc))
		(max-nfv (cdr ls) (max i ($fvar-idx loc))))
	    i))

	(module (actual-frame-size)

	  (define (actual-frame-size vars i)
	    (if (%frame-size-ok? i vars)
		i
	      (actual-frame-size vars (fxadd1 i))))

	  (define (%frame-size-ok? i vars)
	    (or (null? vars)
		(let ((x (car vars)))
		  (and (not (set-member?    i ($nfv-frm-conf x)))
		       (not (%var-conflict? i ($nfv-var-conf x)))
		       (%frame-size-ok? (fxadd1 i) (cdr vars))))))

	  (define (%var-conflict? i vs)
	    (ormap (lambda (xi)
		     (let ((loc ($var-loc (vector-ref vars.vec xi))))
		       (and (fvar? loc)
			    (fx=? i ($fvar-idx loc)))))
		   (set->list vs)))

	  #| end of module: actual-frame-size |# )

	(define (%assign-frame-vars! vars i)
	  (when (pair? vars)
	    (let ((v  (car vars))
		  (fv (mkfvar i)))
	      ($set-nfv-loc! v fv)
	      (for-each (lambda (x)
			  (let ((loc ($nfv-loc x)))
			    (if loc
				(when (fx=? ($fvar-idx loc) i)
				  (compiler-internal-error __module_who__ "invalid assignment"))
			      (begin
				($set-nfv-nfv-conf! x (rem-nfv v  ($nfv-nfv-conf x)))
				($set-nfv-frm-conf! x (add-frm fv ($nfv-frm-conf x)))))))
		($nfv-nfv-conf v))
	      (for-each-var
		  ($nfv-var-conf v)
		  vars.vec
		(lambda (x)
		  (let ((loc ($var-loc x)))
		    (if (fvar? loc)
			(when (fx=? (fvar-idx loc) i)
			  (compiler-internal-error __module_who__ "invalid assignment"))
		      ($set-var-frm-conf! x (add-frm fv ($var-frm-conf x))))))))
	    (%assign-frame-vars! (cdr vars) (fxadd1 i))))

	(module (make-mask)

	  (define (make-mask n)
	    (receive-and-return (mask)
		(make-vector (fxsra (fx+ n 7) 3) 0)
	      (for-each (lambda (fvar)
			  (%set-bit! mask ($fvar-idx fvar)))
		live-frms1)
	      (for-each (lambda (idx)
			  (%set-bit! mask idx))
		live-frms2)
	      (for-each (lambda (nfv)
			  (let ((loc ($nfv-loc nfv)))
			    (when loc
			      (%set-bit! mask ($fvar-idx loc)))))
		live-nfvs)))

	  (define (%set-bit! mask idx)
	    (let ((q (fxsra    idx 3))
		  (r (fxlogand idx 7)))
	      (vector-set! mask q (fxlogor (vector-ref mask q) (fxsll 1 r)))))

	  #| end of module: make-mask |# )

	(let ((i (actual-frame-size
		  vars
		  (fx+ 2 (max-frm live-frms1
				  (max-nfv live-nfvs
					   (max-ls live-frms2 0)))))))
	  (%assign-frame-vars! vars i)
	  (NFE (fxsub1 i) (make-mask (fxsub1 i)) body))))

;;; --------------------------------------------------------------------

    (define (NFE idx mask x)
      (struct-case x
	((seq e0 e1)
	 (let ((e0^ (E e0)))
	   (make-seq e0^ (NFE idx mask e1))))
	((non-tail-call target value args mask^ size)
	 (make-non-tail-call target value
			     (map (lambda (x)
				    (cond ((symbol? x)
					   x)
					  ((nfv? x)
					   ($nfv-loc x))
					  (else
					   (compiler-internal-error __module_who__ "invalid arg"))))
			       args)
			     mask idx))
	(else
	 (compiler-internal-error __module_who__ "invalid NF effect" x))))

    #| end of module: E |# )

;;; --------------------------------------------------------------------

  (module (Var)

    (define (Var x)
      (cond (($var-loc x)
	     => (lambda (loc)
		  (if (fvar? loc)
		      loc
		    (%assign x vars.vec))))
	    (else x)))

    (module (%assign)
      (import FRAME-CONFLICT-HELPERS)

      (define (%assign x vars.vec)
	(or (%assign-move x vars.vec)
	    (%assign-any  x vars.vec)))

      (define (%assign-any x vars.vec)
	(let ((frms ($var-frm-conf x))
	      (vars ($var-var-conf x)))
	  (let loop ((i 1))
	    (if (set-member? i frms)
		(loop (fxadd1 i))
	      (receive-and-return (fv)
		  (mkfvar i)
		($set-var-loc! x fv)
		(for-each-var
		    vars
		    vars.vec
		  (lambda (var)
		    ($set-var-frm-conf! var (add-frm fv ($var-frm-conf var))))))))))

      (define (%assign-move x vars.vec)
	(let ((mr (set->list (set-difference ($var-frm-move x) ($var-frm-conf x)))))
	  (and (pair? mr)
	       (receive-and-return (fv)
		   (mkfvar (car mr))
		 ($set-var-loc! x fv)
		 (for-each-var
		     ($var-var-conf x)
		     vars.vec
		   (lambda (var)
		     ($set-var-frm-conf! var (add-frm fv ($var-frm-conf var)))))
		 (for-each-var
		     ($var-var-move x)
		     vars.vec
		   (lambda (var)
		     ($set-var-frm-move! var (add-frm fv ($var-frm-move var)))))))))

      #| end of module: %assign |# )

    #| end of module: Var |# )

;;; --------------------------------------------------------------------

  (T x))


;;;; done

#| end of module: assign-frame-sizes |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; eval: (put 'make-asmcall		'scheme-indent-function 1)
;; eval: (put 'assemble-sources		'scheme-indent-function 1)
;; eval: (put 'make-conditional		'scheme-indent-function 2)
;; eval: (put 'struct-case		'scheme-indent-function 1)
;; eval: (put 'for-each-var		'scheme-indent-function 2)
;; eval: (put 'for-each-nfv		'scheme-indent-function 1)
;; End:
