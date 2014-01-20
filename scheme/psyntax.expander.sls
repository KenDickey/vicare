;;;Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;Permission is hereby granted, free of charge, to any person obtaining
;;;a  copy of  this  software and  associated  documentation files  (the
;;;"Software"), to  deal in the Software  without restriction, including
;;;without limitation  the rights to use, copy,  modify, merge, publish,
;;;distribute, sublicense,  and/or sell copies  of the Software,  and to
;;;permit persons to whom the Software is furnished to do so, subject to
;;;the following conditions:
;;;
;;;The  above  copyright notice  and  this  permission  notice shall  be
;;;included in all copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND,
;;;EXPRESS OR  IMPLIED, INCLUDING BUT  NOT LIMITED TO THE  WARRANTIES OF
;;;MERCHANTABILITY,    FITNESS   FOR    A    PARTICULAR   PURPOSE    AND
;;;NONINFRINGEMENT.  IN NO EVENT  SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;;;BE LIABLE  FOR ANY CLAIM, DAMAGES  OR OTHER LIABILITY,  WHETHER IN AN
;;;ACTION OF  CONTRACT, TORT  OR OTHERWISE, ARISING  FROM, OUT OF  OR IN
;;;CONNECTION  WITH THE SOFTWARE  OR THE  USE OR  OTHER DEALINGS  IN THE
;;;SOFTWARE.


;;;; copyright notice for the original code of the XOR macro
;;;
;;;Copyright (c) 2008 Derick Eddington
;;;
;;;Permission is hereby granted, free of charge, to any person obtaining
;;;a  copy of  this  software and  associated  documentation files  (the
;;;"Software"), to  deal in the Software  without restriction, including
;;;without limitation the  rights to use, copy,  modify, merge, publish,
;;;distribute, sublicense,  and/or sell copies  of the Software,  and to
;;;permit persons to whom the Software is furnished to do so, subject to
;;;the following conditions:
;;;
;;;The  above  copyright notice  and  this  permission  notice shall  be
;;;included in all copies or substantial portions of the Software.
;;;
;;;Except  as  contained  in  this  notice, the  name(s)  of  the  above
;;;copyright holders  shall not be  used in advertising or  otherwise to
;;;promote  the sale,  use or  other dealings  in this  Software without
;;;prior written authorization.
;;;
;;;THE  SOFTWARE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND,
;;;EXPRESS OR  IMPLIED, INCLUDING BUT  NOT LIMITED TO THE  WARRANTIES OF
;;;MERCHANTABILITY,    FITNESS   FOR    A    PARTICULAR   PURPOSE    AND
;;;NONINFRINGEMENT.  IN NO EVENT  SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;;;BE LIABLE  FOR ANY CLAIM, DAMAGES  OR OTHER LIABILITY,  WHETHER IN AN
;;;ACTION OF  CONTRACT, TORT  OR OTHERWISE, ARISING  FROM, OUT OF  OR IN
;;;CONNECTION  WITH THE SOFTWARE  OR THE  USE OR  OTHER DEALINGS  IN THE
;;;SOFTWARE.


;;;;copyright notice for the original code of RECEIVE
;;;
;;;Copyright (C) John David Stone (1999). All Rights Reserved.
;;;
;;;Permission is hereby granted, free of charge, to any person obtaining
;;;a  copy of  this  software and  associated  documentation files  (the
;;;"Software"), to  deal in the Software  without restriction, including
;;;without limitation  the rights to use, copy,  modify, merge, publish,
;;;distribute, sublicense,  and/or sell copies  of the Software,  and to
;;;permit persons to whom the Software is furnished to do so, subject to
;;;the following conditions:
;;;
;;;The  above  copyright notice  and  this  permission  notice shall  be
;;;included in all copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND,
;;;EXPRESS OR  IMPLIED, INCLUDING BUT  NOT LIMITED TO THE  WARRANTIES OF
;;;MERCHANTABILITY,    FITNESS   FOR    A    PARTICULAR   PURPOSE    AND
;;;NONINFRINGEMENT. IN  NO EVENT SHALL THE AUTHORS  OR COPYRIGHT HOLDERS
;;;BE LIABLE  FOR ANY CLAIM, DAMAGES  OR OTHER LIABILITY,  WHETHER IN AN
;;;ACTION OF  CONTRACT, TORT  OR OTHERWISE, ARISING  FROM, OUT OF  OR IN
;;;CONNECTION  WITH THE SOFTWARE  OR THE  USE OR  OTHER DEALINGS  IN THE
;;;SOFTWARE.


;;;; introduction: lexical variables, labels, location gensyms
;;
;;Let's consider the example library:
;;
;;   (library (demo)
;;     (export this)
;;     (import (vicare))
;;     (define this 8)
;;     (define that 9)
;;     (let ((a 1))
;;       (let ((a 2))
;;         (list a this that))))
;;
;;and concentrate on the body:
;;
;;   (define this 8)
;;   (define that 9)
;;   (let ((a 1))
;;     (let ((a 2))
;;       (list a this that)))
;;
;;This  code defines  4  syntactic  bindings: THIS  and  THAT as  global
;;lexical variables,  of which THIS is  also exported; outer A  as local
;;lexical variable; inner A as local lexical variable.
;;
;;After the expansion process every syntactic binding is renamed so that
;;its name is unique in the whole library body.  For example:
;;
;;  (define lex.this 8)
;;  (define lex.that 9)
;;  (let ((lex.a.1 1))
;;    (let ((lex.a.2 2))
;;      (list lex.a.2 lex.this lex.that)))
;;
;;notice that  LIST is still there  because it is part  of the top-level
;;environment (it  is a binding  exported by  the boot image);  the code
;;undergoes the following lexical variable name substitutions:
;;
;;  original name | lexical variable name
;;  --------------+----------------------
;;          this  | lex.this
;;          that  | lex.that
;;        outer a | lex.a.1
;;        inner a | lex.a.2
;;
;;where the "lex.*" symbols are gensyms.
;;
;;Renaming  bindings  is one  of  the  core  purposes of  the  expansion
;;process; it is  performed while visiting the source code  as a tree in
;;breadth-first order.
;;
;;The expansion  process is complex  and can it  be described only  by a
;;complex  data structure:  the  lexical environment,  a composite  data
;;structure  resulting from  the conceptual  union among  component data
;;structures.
;;
;;Lexical contours and ribs
;;-------------------------
;;
;;To distinguish among  different bindings with the same  name, like the
;;two local  bindings both named A  in the example, we  must distinguish
;;among  different  "lexical contours"  that  is:  different regions  of
;;visibility for a set of bindings.  Every LET-like syntax defines a new
;;lexical  contour;  lexical  contours  can be  nested  by  nesting  LET
;;syntaxes; the library global namespace is a lexical contour itself.
;;
;;    -------------------------------------------------
;;   | (define this 8)              ;top-level contour |
;;   | (define that 9)                                 |
;;   | (let ((a 1))                                    |
;;   |  -----------------------------------------      |
;;   | |                            ;contour 1   |     |
;;   | | (let ((a 2))                            |     |
;;   | |  -------------------------------------  |     |
;;   | | |                          ;contour 2 | |     |
;;   | | | (list a this that)                  | |     |
;;   | |  -------------------------------------  |     |
;;   | |   )                                     |     |
;;   |  -----------------------------------------      |
;;   |   )                                             |
;;    -------------------------------------------------
;;
;;An EQ?-unique object is assigned to each lexical contour; such objects
;;are called "marks".  In practice  each syntactic binding is associated
;;to the mark representing its  visibility region.  So the original code
;;is accompanied by the associations:
;;
;;  original name | lexical contour mark
;;  --------------+---------------------
;;          this  | top-mark
;;          that  | top-mark
;;        outer a |   1-mark
;;        inner a |   2-mark
;;
;;which  are registered  in a  component of  the lexical  environment: a
;;record of  type <RIB>.  Every lexical  contour is described by  a rib;
;;the rib for the top-level contour holds the associations:
;;
;;  original name | lexical contour mark
;;  --------------+---------------------
;;          this  | top-mark
;;          that  | top-mark
;;
;;the rib of the outer LET holds the associations:
;;
;;  original name | lexical contour mark
;;  --------------+---------------------
;;        outer a |   1-mark
;;
;;the rib of the inner LET holds the associations:
;;
;;  original name | lexical contour mark
;;  --------------+---------------------
;;        inner a |   2-mark
;;
;;While the  code is being visited  by the expander: syntax  objects are
;;created to  represent all the  binding names; such syntax  objects are
;;called "identifiers".  Each identifier is a data structure holding the
;;mark of its definition contour among its fields.
;;
;;
;;Label gensyms and ribs
;;----------------------
;;
;;An EQ?-unique object  is assigned to each syntactic  binding: a gensym
;;indicated as  "label"; such  associations are also  stored in  the rib
;;representing a lexical contour:
;;
;;  original name | lexical contour mark | label
;;  --------------+----------------------+---------
;;          this  | top-mark             | lab.this
;;          that  | top-mark             | lab.that
;;        outer a |   1-mark             | lab.a.1
;;        inner a |   2-mark             | lab.a.2
;;
;;where the symbols "lab.*" are gensyms.
;;
;;Lexical variable gensyms and LEXENV
;;-----------------------------------
;;
;;The fact that  the "lex.*" symbols in the expanded  code are syntactic
;;bindings representing lexical variables is  registered in a portion of
;;the lexical environment indicated LEXENV.RUN or LEXENV.EXPAND.  So the
;;expanded code is accompanied by the association:
;;
;;    label  | lexical variables
;;  ---------+------------------
;;  lab.this | lex.this
;;  lab.that | lex.that
;;  lab.a.1  | lex.a.1
;;  lab.a.2  | lex.a.2
;;
;;Notice  that, after  the expansion:  the original  names of  the local
;;bindings (those  defined by LET)  do not matter anymore;  the original
;;names of the non-exported global  bindings do not matter anymore; only
;;the original name of the exported global bindings is still important.
;;
;;Storage location gensyms and EXPORT-ENV
;;---------------------------------------
;;
;;About the value of lexical variables:
;;
;;*  The value  of local  bindings (those  created by  LET) goes  on the
;;  Scheme stack, and it exists only while the code is being evaluated.
;;
;;*  The value  of global  bindings (those  created by  DEFINE) must  be
;;  stored in  some persistent location,  because it must exist  for the
;;  whole time the library is loaded in a running Vicare process.
;;
;;But where is a global variable's value stored?  The answer is: gensyms
;;are created  for the sole purpose  of acting as storage  locations for
;;global lexical variables, such gensyms  are indicated as "loc".  Under
;;Vicare, symbols are  data structures having a "value"  slot: such slot
;;has SYMBOL-VALUE as  accessor and SET-SYMBOL-VALUE! as  mutator and it
;;is used as storage location.
;;
;;So the expanded code is accompanied by the following association:
;;
;;    label  | location gensym
;;  ---------+----------------
;;  lab.this | loc.this
;;  lab.that | loc.that
;;  lab.a.1  | loc.a.1
;;  lab.a.2  | loc.a.2
;;
;;where the "loc.*"  are gensyms.  To represent  the association between
;;the global  lexical variable  labels (both the  exported ones  and the
;;non-exported ones)  and their  storage location gensyms,  the expander
;;builds a data structure indicated as EXPORT-ENV.
;;
;;
;;Exported bindings and EXPORT-SUBST
;;----------------------------------
;;
;;Not all  the global lexical variables  are exported by a  library.  To
;;list  those that  are,  a data  structure is  built  and indicated  as
;;EXPORT-SUBST;  such data  structure  associates the  external name  of
;;exported bindings to their label  gensym.  For the example library the
;;EXPORT-SUBST represents the association:
;;
;;    label  | external name
;;  ---------+--------------
;;  lab.this | this
;;
;;If the EXPORT specification renames a bindings as in:
;;
;;   (export (rename this external-this))
;;
;;then the EXPORT-SUBST represents the association:
;;
;;    label  | external name
;;  ---------+--------------
;;  lab.this | external-this
;;


;;;; introduction: lexical environments, the LEXENV component
;;
;;A  LEXENV  is an  alist  managed  somewhat  like  a stack;  while  the
;;expansion  proceeds, visiting  the  code in  breadth-first order:  the
;;LEXENV is updated by pushing new  entries on the stack.  Each entry is
;;a pair, list or improper list and represents a syntactic binding.
;;
;;A LEXENV entry has the following format:
;;
;;   (?label . ?syntactic-binding)
;;
;;where ?LABEL  is a label  gensym uniquely indicating the  binding, and
;;?SYNTACTIC-BINDING has the format:
;;
;;   (?binding-type . ?binding-value)
;;
;;where  ?BINDING-TYPE is  a  symbol and  the  format of  ?BINDING-VALUE
;;depends on the binding type.
;;
;;
;;LEXENV entry types
;;==================
;;
;;Library lexical variables
;;-------------------------
;;
;;A syntactic binding representing a lexical variable, as created by LET
;;and similar syntaxes, LAMBDA, CASE-LAMBDA or DEFINE, has the format:
;;
;;   (lexical . (?lexvar . ?mutated))
;;
;;where  "lexical"  is  the  symbol   "lexical";  ?LEXVAR  is  a  gensym
;;representing the name of the  lexical variable binding in the expanded
;;code; ?MUTATED is  a boolean, true if somewhere in  the code the value
;;of this binding is mutated.
;;
;;We want to keep  track of mutated variables because we  do not want to
;;export from a library a mutable variable.
;;
;;
;;Imported lexical variables
;;--------------------------
;;
;;A  syntactic binding  representing  a lexical  variable imported  from
;;another library has the format:
;;
;;   (global . (?library . ?loc))
;;
;;where:  ?LIBRARY represents  the  library from  which  the binding  is
;;exported, ?LOC  is the gensym  containing the variable's value  in its
;;"value" field.
;;
;;When the  variable is defined  by an  imported library: ?LIBRARY  is a
;;record of type  LIBRARY.  When the variable was defined  by a previous
;;REPL expression: ?LIBRARY is the symbol "*interaction*".
;;
;;Labels   associated  to   these  imported   bindings  have   the  list
;;representing the binding itself stored in their "value" fields.
;;
;;
;;Non-core macro
;;--------------
;;
;;A binding representing a non-core macro integrated in the expander has
;;the format:
;;
;;   (macro . ?name)
;;
;;where ?NAME is a symbol representing  the macro name; such entries are
;;defined in the file "makefile.sps".
;;
;;The  non-core  macro  transformer  functions are  implemented  by  the
;;expander     in     the      module     exporting     the     function
;;NON-CORE-MACRO-TRANSFORMER, which is used  to map non-core macro names
;;to transformer functions.
;;
;;
;;Library non-identifier macro
;;----------------------------
;;
;;A binding  representing a macro with  non-variable transformer defined
;;by the code being expanded has the format:
;;
;;   (local-macro . (?transformer . ?expanded-expr))
;;
;;where: ?TRANSFORMER is a  function implementing the macro transformer;
;;?EXPANDED-EXPR is  the expression in fully  expanded code representing
;;the right-hand side of the  syntax definition.
;;
;;?TRANSFORMER is the result of compiling and evaluating ?EXPANDED-EXPR.
;;
;;
;;Library identifier macro
;;------------------------
;;
;;A binding  representing a macro  with variable transformer  defined by
;;the code being expanded has the format:
;;
;;   (local-macro! . (?transformer . ?expanded-expr))
;;
;;where: ?TRANSFORMER is a  function implementing the macro transformer;
;;?EXPANDED-EXPR is  the expression in fully  expanded code representing
;;the right-hand side of the syntax definition.
;;
;;?TRANSFORMER is the result of compiling and evaluating ?EXPANDED-EXPR.
;;
;;
;;Imported non-identifier macro
;;-----------------------------
;;
;;A binding representing a macro with a non-variable transformer defined
;;by code in an imported library has the format:
;;
;;   (global-macro . (?library . ?loc))
;;
;;where: ?LIBRARY  is a  record of type  LIBRARY describing  the library
;;from which  the macro is exported;  ?LOC is the gensym  containing the
;;transformer function in its "value" field.
;;
;;Labels   associated  to   these  imported   bindings  have   the  list
;;representing the binding itself stored in their "value" fields.
;;
;;
;;Imported identifier macro
;;-------------------------
;;
;;A binding  representing a macro  with variable transformer  defined by
;;code in an imported library has the format:
;;
;;   (global-macro! . (?library . ?loc))
;;
;;where: ?LIBRARY  is a  record of type  LIBRARY describing  the library
;;from which  the macro is exported;  ?LOC is the gensym  containing the
;;transformer function in its "value" field.
;;
;;Labels   associated  to   these  imported   bindings  have   the  list
;;representing the binding itself stored in their "value" fields.
;;
;;
;;Library compile-time value
;;--------------------------
;;
;;A binding representing a compile-time  value defined by the code being
;;expanded has the format:
;;
;;   (local-ctv . (?object . ?expanded-expr))
;;
;;where:  ?OBJECT  is   the  actual  value  computed   at  expand  time;
;;?EXPANDED-EXPR is the result of fully expanding the right-hand side of
;;the syntax definition.
;;
;;?OBJECT is the result of compiling and evaluating ?EXPANDED-EXPR.
;;
;;
;;Imported compile-time value
;;---------------------------
;;
;;A  binding  representing  a  compile-time value  exported  by  another
;;library has the format:
;;
;;   (global-ctv . (?library . ?loc))
;;
;;where: ?LIBRARY  is a  record of type  LIBRARY describing  the library
;;from which the binding is exported;  ?LOC is the gensym containing the
;;actual object in its "value" field.
;;
;;Labels   associated  to   these  imported   bindings  have   the  list
;;representing the binding itself stored in their "value" fields.
;;
;;
;;Module interface
;;----------------
;;
;;A binding representing the interface of a MODULE syntax defined by the
;;code being expanded has the format:
;;
;;   ($module . ?iface)
;;
;;where ?IFACE is a record of type "module-interface".
;;
;;
;;Pattern variable
;;----------------
;;
;;A binding representing  a pattern variable, as  created by SYNTAX-CASE
;;and SYNTAX-RULES, has the format:
;;
;;   (syntax . (?name . ?level))
;;
;;where:  "syntax"  is   the  symbol  "syntax";  ?NAME   is  the  symbol
;;representing  the   name  of  the   pattern  variable;  ?LEVEL   is  a
;;non-negative exact integer representing the ellipsis nesting level.
;;
;;The  SYNTAX-CASE  patterns below  will  generate  the given  syntactic
;;bindings:
;;
;;   ?a				->  (syntax . (?a . 0))
;;   (?a)			->  (syntax . (?a . 0))
;;   (((?a)))			->  (syntax . (?a . 0))
;;   (?a ...)			->  (syntax . (?a . 1))
;;   ((?a) ...)			->  (syntax . (?a . 1))
;;   ((((?a))) ...)		->  (syntax . (?a . 1))
;;   ((?a ...) ...)		->  (syntax . (?a . 2))
;;   (((?a ...) ...) ...)	->  (syntax . (?a . 3))
;;
;;
;;Library Vicare struct descriptor
;;--------------------------------
;;
;;A binding  representing a Vicare's  struct type descriptor  defined by
;;the code being expanded has the format:
;;
;;   ($rtd . #<type-descriptor-struct>)
;;
;;where "$rtd" is the symbol "$rtd".
;;
;;
;;Library R6RS record type descriptor
;;-----------------------------------
;;
;;A  binding  representing an  R6RS's  record  type descriptor  and  the
;;default  record  constructor  descriptor  defined by  the  code  being
;;expanded has the format:
;;
;;   ($rtd . (?rtd-id ?rcd-id))
;;
;;where: "$rtd" is the symbol "$rtd"; ?RTD-ID is the identifier to which
;;the  record type  descriptor is  bound; ?RCD-ID  is the  identifier to
;;which the default record constructor descriptor is bound.
;;
;;Optionally 2 or 4 additional items are present:
;;
;;   ($rtd . (?rtd-id ?rcd-id
;;            ?safe-accessors-alist ?safe-mutators-alist))
;;
;;   ($rtd . (?rtd-id ?rcd-id
;;            ?safe-accessors-alist ?safe-mutators-alist
;;            ?unsafe-accessors-alist ?unsafe-mutators-alist))
;;
;;in which:
;;
;;-   ?SAFE-ACCESSORS-ALIST  is   an  alist   whose  keys   are  symbols
;;representing all the field names  and whose values are the identifiers
;;bound to the corresponding safe field accessors.
;;
;;- ?SAFE-FIELD-MUTATORS is an alist whose keys are symbols representing
;;the mutable field names and whose  values are identifiers bound to the
;;corresponding safe field mutators.
;;
;;-  ?UNSAFE-ACCESSORS-ALIST   is  an  alist  whose   keys  are  symbols
;;representing all the field names  and whose values are the identifiers
;;bound to the corresponding safe unfield accessors.
;;
;;-  ?UNSAFE-FIELD-MUTATORS   is  an   alist  whose  keys   are  symbols
;;representing the mutable field names  and whose values are identifiers
;;bound to the corresponding unsafe field mutators.
;;
;;
;;Core R6RS record type descriptor
;;--------------------------------
;;
;;A binding representing  R6RS's record type descriptor  exported by the
;;boot image has the format:
;;
;;     ($core-rtd . (?rtd-id ?rcd-id))
;;
;;for example: these entries are  defined by "makefile.sps" to represent
;;the predefined R6RS condition object types.
;;
;;
;;Fluid syntax
;;------------
;;
;;A binding representing a fluid syntax has the format:
;;
;;   ($fluid . ?label)
;;
;;where ?LABEL is the gensym associated to the fluid syntax.
;;
;;
;;Displaced lexical
;;-----------------
;;
;;These lists  have a format  similar to  a LEXENV entry  representing a
;;syntactic binding, but they are used to represent a failed search into
;;a LEXENV.
;;
;;The following special value represents an unbound label:
;;
;;     (displaced-lexical . #f)
;;
;;The  following  special  value  represents the  result  of  a  lexical
;;environment query with invalid label value (not a symbol):
;;
;;     (displaced-lexical . ())
;;


(library (psyntax expander)
  (export
    eval
    environment				environment?
    null-environment			scheme-report-environment
    interaction-environment		new-interaction-environment

    ;; inspection of non-interaction environment objects
    environment-symbols			environment-libraries
    environment-labels			environment-binding

    expand-form-to-core-language	expand-top-level
    expand-library
    compile-r6rs-top-level		boot-library-expand

    make-compile-time-value		compile-time-value?
    compile-time-value-object

    generate-temporaries		identifier?
    free-identifier=?			bound-identifier=?
    datum->syntax			syntax->datum

    syntax-violation			assertion-error

    ;;This must  be exported and that's  it.  I am unable  to remove it.
    ;;Sue me.  (Marco Maggi; Sun Nov 17, 2013)
    syntax-error

    make-variable-transformer		variable-transformer?
    variable-transformer-procedure

    syntax-dispatch			syntax-transpose
    ellipsis-map

    ;;The following are inspection functions for debugging purposes.
    (rename (<stx>?		syntax-object?)
	    (<stx>-expr		syntax-object-expression)
	    (<stx>-mark*	syntax-object-marks)
	    (<stx>-subst*	syntax-object-substs)
	    (<stx>-ae*		syntax-object-source-objects)))
  (import (except (rnrs)
		  eval
		  environment		environment?
		  null-environment	scheme-report-environment
		  identifier?
		  bound-identifier=?	free-identifier=?
		  generate-temporaries
		  datum->syntax		syntax->datum
		  syntax-violation	make-variable-transformer
		  syntax-error)
    (prefix (rnrs syntax-case) sys.)
    (rnrs mutable-pairs)
    (psyntax library-manager)
    (psyntax builders)
    (psyntax compat)
    (psyntax config)
    (psyntax internal))


;;; helpers

;;This syntax can be used as standalone identifier and it expands to #f.
;;It is used  as "annotated expression" argument in calls  to the BUILD-
;;functions when there is no annotated expression to be given.
;;
(define-syntax no-source
  (lambda (x) #f))

(define (debug-print . args)
  ;;Print arguments for debugging purposes.
  ;;
  (pretty-print args (current-error-port))
  (newline (current-error-port))
  (newline (current-error-port))
  (when (pair? args)
    (car args)))


;;;; library records collectors

(define (make-collector)
  (let ((ls '()))
    (case-lambda
     (()
      ls)
     ((x)
      (unless (eq? x '*interaction*)
	(assert (library? x))
	;;Prepend  X to  the  list LS  if it  is  not already  contained
	;;according to EQ?.
	(set! ls (if (memq x ls)
		     ls
		   (cons x ls))))))))

(define imp-collector
  ;;Imported  libraries  collector.   Holds a  collector  function  (see
  ;;MAKE-COLLECTOR)  filled with  the LIBRARY  records representing  the
  ;;libraries from an R6RS import specification: every time the expander
  ;;parses an IMPORT syntax, the selected libraries are represented by a
  ;;LIBRARY record and such record is added to this collection.
  ;;
  (make-parameter
      (lambda args
        (assertion-violation 'imp-collector "BUG: not initialized"))
    (lambda (x)
      (unless (procedure? x)
	(assertion-violation 'imp-collector "BUG: not a procedure" x))
      x)))

(define inv-collector
  ;;Invoked  libraries  collector.   Holds  a  collector  function  (see
  ;;MAKE-COLLECTOR)  filled with  the LIBRARY  records representing  the
  ;;libraries defining "global" entries  in the lexical environment that
  ;;are used in the code we are expanding.
  ;;
  ;;The library:
  ;;
  ;;   (library (subdemo)
  ;;     (export sub-var)
  ;;     (import (vicare))
  ;;     (define sub-var 456))
  ;;
  ;;is imported by the library:
  ;;
  ;;   (library (demo)
  ;;     (export var sub-var)
  ;;     (import (vicare) (subdemo))
  ;;     (define var 123))
  ;;
  ;;which is imported by the program:
  ;;
  ;;   (import (vicare) (demo))
  ;;   (define (doit)
  ;;     (list var sub-var))
  ;;   (doit)
  ;;
  ;;when the  body of the function  is expanded the identifiers  VAR and
  ;;SUB-VAR are captured by bindings in the lexical environment with the
  ;;format:
  ;;
  ;;   (global . (?library . ?gensym))
  ;;
  ;;where  ?LIBRARY  is the  record  of  type LIBRARY  representing  the
  ;;library that  defines the variable  and ?GENSYM is a  symbol holding
  ;;the variable's value in its  "value" slot.  Such LIBRARY records are
  ;;added to the INV-COLLECTOR.
  ;;
  ;;For the  identifier VAR:  ?LIBRARY represents the  library "(demo)";
  ;;for  the   identifier  SUB-VAR:  ?LIBRARY  represents   the  library
  ;;"(subdemo)".  Notice  that while "(demo)"  is present in  the IMPORT
  ;;specification, and  so it is  also registered in  the IMP-COLLECTOR,
  ;;"(subdemo)" is not and it is only present in the INV-COLLECTOR.
  ;;
  (make-parameter
      (lambda args
        (assertion-violation 'inv-collector "BUG: not initialized"))
    (lambda (x)
      (unless (procedure? x)
	(assertion-violation 'inv-collector "BUG: not a procedure" x))
      x)))

(define vis-collector
  ;;Visit  libraries   collector.   Holds  a  collector   function  (see
  ;;MAKE-COLLECTOR)  which  is  meant  to be  filled  with  the  LIBRARY
  ;;records.   This  collector  holds  the libraries  collected  by  the
  ;;INV-COLLECTOR  when  expanding  the  right-hand  side  of  a  syntax
  ;;definition.
  ;;
  ;;The library:
  ;;
  ;;  (library (demo)
  ;;    (export var)
  ;;    (import (vicare))
  ;;    (define var 123))
  ;;
  ;;is loaded by the program:
  ;;
  ;;  (import (vicare)
  ;;    (for (demo) expand))
  ;;  (define-syntax doit (lambda (stx) var))
  ;;  (doit)
  ;;
  ;;the right-hand side of the syntax definition is the expression:
  ;;
  ;;  (lambda (stx) var)
  ;;
  ;;when such expression is expanded: the  identifier VAR is found to be
  ;;captured by a binding in the lexical environment with the format:
  ;;
  ;;   (global . (?library . ?gensym))
  ;;
  ;;where  ?LIBRARY  is the  record  of  type LIBRARY  representing  the
  ;;library "(demo)" and ?GENSYM is a  symbol holding 123 in its "value"
  ;;slot.   The record  ?LIBRARY is  added first  to INV-COLLECTOR  and,
  ;;after finishing the expansion of the right-hand side, it is moved to
  ;;the INV-COLLECTOR.  See %EXPAND-MACRO-TRANSFORMER for details.
  ;;
  (make-parameter
      (lambda args
        (assertion-violation 'vis-collector "BUG: not initialized"))
    (lambda (x)
      (unless (procedure? x)
	(assertion-violation 'vis-collector "BUG: not a procedure" x))
      x)))

;;; --------------------------------------------------------------------

(define stale-when-collector
  ;;Collects  test  expressions  from STALE-WHEN  syntaxes  and  LIBRARY
  ;;records needed for such expressions.  This parameter holds a special
  ;;collector  function  (see  %MAKE-STALE-COLLECTOR)  which  handles  2
  ;;collections:  one for  expanded expressions  representing STALE-WHEN
  ;;test  expressions, one  for  LIBRARY records  defining the  imported
  ;;variables needed by the test expressions.
  ;;
  ;;The library:
  ;;
  ;;   (library (subsubdemo)
  ;;     (export sub-sub-var)
  ;;     (import (vicare))
  ;;     (define sub-sub-var 456))
  ;;
  ;;is imported by the library:
  ;;
  ;;   (library (subdemo)
  ;;     (export sub-var sub-sub-var)
  ;;     (import (vicare) (subsubdemo))
  ;;     (define sub-var 456))
  ;;
  ;;which is imported by the library:
  ;;
  ;;   (library (demo)
  ;;     (export var)
  ;;     (import (vicare) (subdemo))
  ;;     (define var
  ;;       (stale-when (< sub-var sub-sub-var)
  ;;         123)))
  ;;
  ;;which is imported by the program:
  ;;
  ;;   (import (vicare) (demo))
  ;;   (debug-print var)
  ;;
  ;;when the test  expression of the STALE-WHEN syntax  is expanded, the
  ;;identifiers SUB-VAR and SUB-SUB-VAR are  captured by bindings in the
  ;;lexical environment with the format:
  ;;
  ;;   (global . (?library . ?gensym))
  ;;
  ;;where  ?LIBRARY  is the  record  of  type LIBRARY  representing  the
  ;;library that  defines the variable  and ?GENSYM is a  symbol holding
  ;;the variable's value in its  "value" slot.  Such LIBRARY records are
  ;;added first to  INV-COLLECTOR and, after finishing  the expansion of
  ;;the  STALE-WHEN test,  they are  moved to  the STALE-WHEN-COLLECTOR.
  ;;See HANDLE-STALE-WHEN for details.
  ;;
  ;;For  the   identifier  SUB-VAR:  ?LIBRARY  represents   the  library
  ;;"(subdemo)"; for the identifier SUB-SUB-VAR: ?LIBRARY represents the
  ;;library "(subsubdemo)".  Notice that while "(subdemo)" is present in
  ;;the  IMPORT specification,  and  so  it is  also  registered in  the
  ;;IMP-COLLECTOR, "(subsubdemo)" is  not and it is only  present in the
  ;;STALE-WHEN-COLLECTOR.
  ;;
  ;;The  collector  function  referenced  by this  parameter  returns  2
  ;;values, which are usually named GUARD-CODE and GUARD-LIB*:
  ;;
  ;;GUARD-CODE  is  a single  core  language  expression representing  a
  ;;composition of  all the STALE-WHEN  test expressions present  in the
  ;;body  of  a library.   If  at  least  one  of the  test  expressions
  ;;evaluates to true: the whole composite expression evaluates to true.
  ;;
  ;;GUARD-LIB* is a  list of LIBRARY records  representing the libraries
  ;;needed to evaluate the composite test expression.
  ;;
  (make-parameter #f))


;;;; top-level environments
;;
;;The result of  parsing a set of  import specs in an  IMPORT clause (as
;;defined by R6RS and extended  by Vicare) and loading the corresponding
;;libraries is an  ENV data structure; ENV data  structures represent an
;;*immutable* top level environment.
;;
;;Whenever  a REPL  is created  (Vicare can  launch multiple  REPLs), an
;;interaction environment is created to  serve as top level environment.
;;The  interaction  environment  is  initialised with  the  core  Vicare
;;library  "(ikarus)";  an  interaction environment  is  *mutable*:  new
;;bindings can be added to it.  For this reason interaction environments
;;are  represented by  data  structures of  type INTERACTION-ENV,  whose
;;internal format allows adding new bindings.
;;
;;Let's  step back:  how does  the  REPL work?   Every time  we type  an
;;expression  and press  "Return":  the expression  is  expanded in  the
;;context of  the current  interaction environment, compiled  to machine
;;code, executed.   Every REPL expression  is like a full  R6RS program,
;;with the  exception that  the interaction environment  "remembers" the
;;bindings we define.
;;

;;An ENV record encapsulates a substitution and a set of libraries.
;;
(define-record env
  (names
		;A vector  of symbols  representing the public  names of
		;bindings from a set of import specifications as defined
		;by  R6RS.   These  names  are from  the  subst  of  the
		;libraries, already processed with the directives in the
		;import sets (prefix, deprefix, only, except, rename).
   labels
		;A vector of gensyms representing the labels of bindings
		;from a set of import specifications as defined by R6RS.
		;These labels are from the subst of the libraries.
   itc
		;A collector  function (see MAKE-COLLECTOR)  holding the
		;LIBRARY structs representing  the libraries selected by
		;the source IMPORT specifications.  These libraries have
		;been installed.
   )
  (lambda (S port sub-printer)
    (display "#<environment>" port)))

(define-record interaction-env
  (rib
		;The top <RIB>  structure for the evaluation  of code in
		;this environment.
   lexenv
		;The lexical  environment for  both run time  and expand
		;time.
   locs
		;???
   )
  (lambda (S port sub-printer)
    (display "#<interaction-environment>" port)))

(define (environment? obj)
  (or (env? obj)
      (interaction-env? obj)))

(define* (environment-symbols x)
  ;;Return a list of symbols representing the names of the bindings from
  ;;the given environment.
  ;;
  (cond ((env? x)
	 (vector->list ($env-names x)))
	((interaction-env? x)
	 (map values ($<rib>-sym* ($interaction-env-rib x))))
	(else
	 (assertion-violation __who__ "not an environment" x))))

(define* (environment-labels x)
  ;;Return a  list of  symbols representing the  labels of  the bindings
  ;;from the given environment.
  ;;
  (unless (env? x)
    (assertion-violation __who__
      "expected non-interaction environment object as argument" x))
  (vector->list ($env-labels x)))

(define* (environment-libraries x)
  ;;Return  the  list  of  LIBRARY records  representing  the  libraries
  ;;forming the environment.
  ;;
  (unless (env? x)
    (assertion-violation __who__
      "expected non-interaction environment object as argument" x))
  (($env-itc x)))

(define* (environment-binding sym env)
  ;;Search the symbol SYM in the non-interaction environment ENV; if SYM
  ;;is the public  name of a binding  in ENV return 2  values: the label
  ;;associated  to the  binding,  the list  of  values representing  the
  ;;binding.  If SYM is not present in ENV return false and false.
  ;;
  (unless (env? env)
    (assertion-violation __who__
      "expected non-interaction environment object as argument" env))
  (let ((P (vector-exists (lambda (name label)
			    (import (ikarus system $symbols))
			    (and (eq? sym name)
				 (cons label ($symbol-value label))))
	     ($env-names  env)
	     ($env-labels env))))
    (if P
	(values (car P) (cdr P))
      (values #f #f))))

;;; --------------------------------------------------------------------

(define (environment . import-spec*)
  ;;This  is  R6RS's  environment.   It  parses  the  import  specs  and
  ;;constructs  an env  record that  can be  used later  by eval  and/or
  ;;expand.
  ;;
  ;;IMPORT-SPEC*  must be  a list  of SYNTAX-MATCH  expression arguments
  ;;representing import  specifications as  defined by R6RS  plus Vicare
  ;;extensions.
  ;;
  (let ((itc (make-collector)))
    (parametrise ((imp-collector itc))
      (receive (subst.names subst.labels)
	  (begin
	    (import PARSE-IMPORT-SPEC)
	    (parse-import-spec* import-spec*))
	(make-env subst.names subst.labels itc)))))

(define (null-environment n)
  ;;Defined  by R6RS.   The null  environment is  constructed using  the
  ;;corresponding library.
  ;;
  (unless (eqv? n 5)
    (assertion-violation 'null-environment
      "only report version 5 is supported" n))
  (environment '(psyntax null-environment-5)))

(define (scheme-report-environment n)
  ;;Defined  by R6RS.   The R5RS  environment is  constructed using  the
  ;;corresponding library.
  ;;
  (unless (eqv? n 5)
    (assertion-violation 'scheme-report-environment
      "only report version 5 is supported" n))
  (environment '(psyntax scheme-report-environment-5)))

(define (new-interaction-environment)
  ;;Build and return a new interaction environment.
  ;;
  (let* ((lib (find-library-by-name (base-of-interaction-library)))
	 (rib (subst->rib (library-subst lib))))
    (make-interaction-env rib '() '())))

(define interaction-environment
  ;;When  called  with  no   arguments:  return  an  environment  object
  ;;representing  the environment  active at  the  REPL; to  be used  as
  ;;argument for EVAL.
  ;;
  ;;When  called with  the argument  ENV, which  must be  an environment
  ;;object: set ENV as interaction environment.
  ;;
  (let ((current-env #f))
    (case-lambda
     (()
      (or current-env
	  (begin
	    (set! current-env (new-interaction-environment))
	    current-env)))
     ((env)
      (unless (environment? env)
	(assertion-violation 'interaction-environment
	  "expected environment object as argument" env))
      (set! current-env env)))))

;;; --------------------------------------------------------------------
;;; Substs.
;;
;;A "subst"  is an  alist whose  keys are "names"  and whose  values are
;;"labels":
;;
;;* "Name" is an identifier representing  the public name of an imported
;;  binding, the one we use to reference it in the code of a library.
;;
;;* "Label"  is a gensym uniquely  associated to the binding's  entry in
;;  the lexical environment.

;;Given the entry in a subst alist: return the name.
;;
(define subst-entry-name car)

;;Given the entry in a subst alist: return the gensym acting as label.
;;
(define subst-entry-label cdr)


(define* (eval x env)
  ;;This  is R6RS's  eval.   Take an  expression  and an  environment:
  ;;expand the  expression, invoke  its invoke-required  libraries and
  ;;evaluate  its  expanded  core  form.  Return  the  result  of  the
  ;;expansion.
  ;;
  (unless (environment? env)
    (error __who__ "not an environment" env))
  (receive (x invoke-req*)
      (expand-form-to-core-language x env)
    (for-each invoke-library invoke-req*)
    (eval-core (expanded->core x))))

(module (expand-form-to-core-language)
  (define-constant __who__ 'expand-form-to-core-language)

  (define (expand-form-to-core-language expr env)
    ;;Interface to the internal expression expander (chi-expr).  Take an
    ;;expression and  an environment.  Return two  values: the resulting
    ;;core-expression, a list  of libraries that must  be invoked before
    ;;evaluating the core expr.
    ;;
    (cond ((env? env)
	   (let ((rib (make-top-rib (env-names env) (env-labels env))))
	     (let ((expr.stx (make-<stx> expr top-mark* (list rib) '()))
		   (rtc      (make-collector))
		   (vtc      (make-collector))
		   (itc      (env-itc env)))
	       (let ((expr.core (parametrise ((top-level-context #f)
					      (inv-collector rtc)
					      (vis-collector vtc)
					      (imp-collector itc))
				  (let ((lexenv.run	'())
					(lexenv.expand	'()))
				    (chi-expr expr.stx lexenv.run lexenv.expand)))))
		 (seal-rib! rib)
		 (values expr.core (rtc))))))

	  ((interaction-env? env)
	   (let ((rib         (interaction-env-rib env))
		 (lexenv.run  (interaction-env-lexenv env))
		 (rtc         (make-collector)))
	     (let ((expr.stx (make-<stx> expr top-mark* (list rib) '())))
	       (receive (expr.core lexenv.run^)
		   (parametrise ((top-level-context env)
				 (inv-collector rtc)
				 (vis-collector (make-collector))
				 (imp-collector (make-collector)))
		     (%chi-interaction-expr expr.stx rib lexenv.run))
		 (set-interaction-env-lexenv! env lexenv.run^)
		 (values expr.core (rtc))))))

	  (else
	   (assertion-violation __who__ "not an environment" env))))

  (define (%chi-interaction-expr expr.stx rib lexenv.run)
    (receive (e* lexenv.run^ lexenv.expand^ lex* rhs* mod** _kwd* _exp*)
	(chi-body* (list expr.stx) lexenv.run lexenv.run
		   '() '() '() '() '() rib #t #f)
      (let ((expr.core* (%expand-interaction-rhs*/init*
			 (reverse lex*) (reverse rhs*)
			 (append (apply append (reverse mod**)) e*)
			 lexenv.run^ lexenv.expand^)))
	(let ((expr.core (cond ((null? expr.core*)
				(build-void))
			       ((null? (cdr expr.core*))
				(car expr.core*))
			       (else
				(build-sequence no-source expr.core*)))))
	  (values expr.core lexenv.run^)))))

  (define (%expand-interaction-rhs*/init* lhs* rhs* init* lexenv.run lexenv.expand)
    ;;Return a list of expressions in the core language.
    ;;
    (let recur ((lhs* lhs*)
		(rhs* rhs*))
      (if (null? lhs*)
	  (map (lambda (init)
		 (chi-expr init lexenv.run lexenv.expand))
	    init*)
	(let ((lhs (car lhs*))
	      (rhs (car rhs*)))
	  (define-inline (%recurse-and-cons ?core-expr)
	    (cons ?core-expr
		  (recur (cdr lhs*) (cdr rhs*))))
	  (case (car rhs)
	    ((defun)
	     (let ((rhs (chi-defun (cdr rhs) lexenv.run lexenv.expand)))
	       (%recurse-and-cons (build-global-assignment no-source lhs rhs))))
	    ((expr)
	     (let ((rhs (chi-expr (cdr rhs) lexenv.run lexenv.expand)))
	       (%recurse-and-cons (build-global-assignment no-source lhs rhs))))
	    ((top-expr)
	     (let ((core-expr (chi-expr (cdr rhs) lexenv.run lexenv.expand)))
	       (%recurse-and-cons core-expr)))
	    (else
	     (error __who__ "invalid" rhs)))))))

  #| end of module: EXPAND-FORM-TO-CORE-LANGUAGE |# )


;;;; R6RS top level programs expander

(define (compile-r6rs-top-level expr*)
  ;;Given a  list of  SYNTAX-MATCH expression arguments  representing an
  ;;R6RS top  level program, expand  it and  return a thunk  which, when
  ;;evaluated,  compiles  the  program and  returns  an  INTERACTION-ENV
  ;;struct representing the environment after the program execution.
  ;;
  (receive (lib* invoke-code macro* export-subst export-env)
      (expand-top-level expr*)
    (lambda ()
      (for-each invoke-library lib*)
      (initial-visit! macro*)
      (eval-core (expanded->core invoke-code))
      (make-interaction-env (subst->rib export-subst)
			    (map (lambda (x)
				   (let* ((label    (car x))
					  (binding  (cdr x))
					  (type     (car binding))
					  (val      (cdr binding)))
				     (cons* label type '*interaction* val)))
			      export-env)
			    '()))))

(module (expand-top-level)

  (define (expand-top-level expr*)
    ;;Given a list of  SYNTAX-MATCH expression arguments representing an
    ;;R6RS top level program, expand it.
    ;;
    (receive (import-spec* body*)
	(%parse-top-level-program expr*)
      (receive (import-spec* invoke-lib* visit-lib* invoke-code macro* export-subst export-env)
	  (begin
	    (import CORE-BODY-EXPANDER)
	    (core-body-expander 'all import-spec* body* #t))
	(values invoke-lib* invoke-code macro* export-subst export-env))))

  (define (%parse-top-level-program expr*)
    ;;Given a list of  SYNTAX-MATCH expression arguments representing an
    ;;R6RS top level program, parse it and return 2 values:
    ;;
    ;;1. A list of import specifications.
    ;;
    ;;2. A list of body forms.
    ;;
    (syntax-match expr* ()
      (((?import ?import-spec* ...) body* ...)
       (eq? (syntax->datum ?import) 'import)
       (values ?import-spec* body*))

      (((?import . x) . y)
       (eq? (syntax->datum ?import) 'import)
       (syntax-violation 'expander
	 "invalid syntax of top-level program" (syntax-car expr*)))

      (_
       (assertion-violation 'expander
	 "top-level program is missing an (import ---) clause"))))

  #| end of module: EXPAND-TOP-LEVEL |# )


;;;; R6RS library expander

(define (boot-library-expand x)
  ;;When bootstrapping  the system,  visit-code is  not (and  cannot be)
  ;;used in the "next" system.  So, we drop it.
  ;;
  (receive (id
	    name ver
	    imp* vis* inv*
	    invoke-code visit-code export-subst export-env
	    guard-code guard-dep*)
      (expand-library x)
    (values name invoke-code export-subst export-env)))

(module (expand-library)
  ;;EXPAND-LIBRARY  is  the  default  library  expander;  it  expands  a
  ;;symbolic  expression representing  a LIBRARY  form to  core-form; it
  ;;registers it  with the library  manager, in other words  it installs
  ;;it.
  ;;
  ;;The argument LIBRARY-SEXP must be the symbolic expression:
  ;;
  ;;   (library . _)
  ;;
  ;;or an ANNOTATION struct representing such expression.
  ;;
  ;;The optional FILENAME must be #f or a string representing the source
  ;;file from which  the library was loaded; it is  used for information
  ;;purposes.
  ;;
  ;;The optional VERIFY-NAME  must be a procedure  accepting 2 arguments
  ;;and returning  unspecified values: the  first argument is a  list of
  ;;symbols from a  library name; the second argument is  null or a list
  ;;of exact integers representing  the library version.  VERIFY-NAME is
  ;;meant to  perform some validation  upon the library  name components
  ;;and raise  an exception if  something is wrong; otherwise  it should
  ;;just return.
  ;;
  ;;The returned values are:
  ;;
  ;;UID - a gensym uniquely identifying this library.
  ;;
  ;;LIBNAME.IDS - a list of  symbols representing the library name.  For
  ;;the library:
  ;;
  ;;   (library (c i a o)
  ;;     (export A)
  ;;     (import (rnrs))
  ;;     (define A 123))
  ;;
  ;;LIBNAME.IDS is the list (c i a o).
  ;;
  ;;LIBNAME.VER  - a  list of  exact integers  representing the  library
  ;;version.  For the library:
  ;;
  ;;   (library (ciao (1 2))
  ;;     (export A)
  ;;     (import (rnrs))
  ;;     (define A 123))
  ;;
  ;;LIBNAME.VER is the list (1 2).
  ;;
  ;;IMPORT-DESC* -  a list  representing the libraries  that need  to be
  ;;imported for the  invoke code.  Each item in the  list is a "library
  ;;descriptor" as built by the LIBRARY-DESCRIPTOR function.
  ;;
  ;;VISIT-DESC* - ???
  ;;
  ;;INVOKE-DESC* -  a list  representing the libraries  that need  to be
  ;;invoked  to make  available the  values of  the imported  variables.
  ;;Each item  in the  list is  a "library descriptor"  as built  by the
  ;;LIBRARY-DESCRIPTOR function.
  ;;
  ;;INVOKE-CODE  - A  symbolic expression  representing the  code to  be
  ;;evaluated  to create  the run-time  bindings and  evaluate the  init
  ;;expressions.  Examples:
  ;;
  ;;         library source          |     INVOKE-CODE
  ;;   ------------------------------+-----------------------------
  ;;   (library (ciao)               |  (library-letrec*
  ;;     (export fun mac var)        |     ((var1 var2 '1)
  ;;     (import (vicare))           |      (fun1 fun2 (annotated-case-lambda
  ;;     (define var 1)              |                   fun (() '2))))
  ;;     (define (fun) 2)            |   ((primitive void)))
  ;;     (define-syntax (mac stx)    |
  ;;       3)                        |
  ;;     (define-syntax val          |
  ;;       (make-compile-time-value  |
  ;;         (+ 4 5))))              |
  ;;
  ;;VISIT-CODE -  - A  symbolic expression representing  the code  to be
  ;;evaluated to create the expand-time code.  Examples:
  ;;
  ;;         library source          |     VISIT-CODE
  ;;   ------------------------------+-----------------------------
  ;;   (library (ciao)               |  (begin
  ;;     (export fun mac var)        |    (set! G3 (annotated-case-lambda
  ;;     (import (vicare))           |	      (#<syntax expr=lambda mark*=(top)>
  ;;     (define var 1)              |			(#<syntax expr=stx mark*=(top)>)
  ;;     (define (fun) 2)            |			#<syntax expr=3 mark*=(top)>)
  ;;     (define-syntax (mac stx)    |	      ((stx) '3)))
  ;;       3)                        |    (set! G5 (annotated-call
  ;;     (define-syntax val          |	      (make-compile-time-value (+ 4 5))
  ;;       (make-compile-time-value  |	      (primitive make-compile-time-value)
  ;;         (+ 4 5))))              |	      (annotated-call (+ 4 5)
  ;;                                 |			      (primitive +) '4 '5))))
  ;;
  ;;EXPORT-SUBST  -  A  subst   representing  the  bindings  to  export.
  ;;Examples:
  ;;
  ;;         library source          |     EXPORT-SUBST
  ;;   ------------------------------+-----------------------------
  ;;   (library (ciao)               |  ((var . G0)
  ;;     (export fun mac var)        |   (mac . G1)
  ;;     (import (vicare))           |   (fun . G2))
  ;;     (define var 1)              |
  ;;     (define (fun) 2)            |
  ;;     (define-syntax (mac stx)    |
  ;;       3)                        |
  ;;     (define-syntax val          |
  ;;       (make-compile-time-value  |
  ;;         (+ 4 5))))              |
  ;;
  ;;EXPORT-ENV  -  A list  representing  the  bindings exported  by  the
  ;;library.  Examples:
  ;;
  ;;         library source          |     EXPORT-ENV
  ;;   ------------------------------+-----------------------------
  ;;   (library (ciao)               |  ((G0 global       . var2)
  ;;     (export fun mac var)        |   (G1 global       . fun2)
  ;;     (import (vicare))           |   (G2 global-macro . G3)
  ;;     (define var 1)              |   (G4 global-ctv   . G5))
  ;;     (define (fun) 2)            |
  ;;     (define-syntax (mac stx)    |
  ;;       3)                        |
  ;;     (define-syntax val          |
  ;;       (make-compile-time-value  |
  ;;         (+ 4 5))))              |
  ;;
  ;;GUARD-CODE   -  A   predicate  expression   in  the   core  language
  ;;representing the stale-when tests from the body of the library.  For
  ;;the library:
  ;;
  ;;   (library (ciao (1 2))
  ;;     (export doit)
  ;;     (import (vicare))
  ;;     (stale-when (< 1 2) (define a 123))
  ;;     (stale-when (< 2 3) (define b 123))
  ;;     (define (doit) 123))
  ;;
  ;;GUARD-CODE is:
  ;;
  ;;   (if (if '#f
  ;;           '#t
  ;;         (annotated-call (< 1 2) (primitive <) '1 '2))
  ;;       '#t
  ;;     (annotated-call (< 2 3) (primitive <) '2 '3))
  ;;
  ;;GUARD-DESC*  - a  list representing  the libraries  that need  to be
  ;;invoked for the STALE-WHEN code; these are the libraries accumulated
  ;;by   the  INV-COLLECTOR   while   expanding   the  STALE-WHEN   test
  ;;expressions.  Each  item in  the list is  a "library  descriptor" as
  ;;built by the LIBRARY-DESCRIPTOR function.
  ;;
  (case-define expand-library
    ((library-sexp)
     (expand-library library-sexp #f       (lambda (ids ver) (values))))
    ((library-sexp filename)
     (expand-library library-sexp filename (lambda (ids ver) (values))))
    ((library-sexp filename verify-name)
     (receive (libname.ids     ;list of library name symbols
	       libname.version ;null or list of version numbers
	       import-lib* invoke-lib* visit-lib*
	       invoke-code macro*
	       export-subst export-env guard-code guard-lib*)
	 (begin
	   (import CORE-LIBRARY-EXPANDER)
	   (core-library-expander library-sexp verify-name))
       (let ((uid		(gensym)) ;library unique-symbol identifier

	     ;;From  list   of  LIBRARY  records  to   list  of  library
	     ;;descriptors; each descriptor is a list:
	     ;;
	     ;;   (?library-uid ?library-name-ids ?library-version)
	     ;;
	     (import-desc*	(map library-descriptor import-lib*))
	     (visit-desc*	(map library-descriptor visit-lib*))
	     (invoke-desc*	(map library-descriptor invoke-lib*))
	     (guard-desc*	(map library-descriptor guard-lib*))

	     ;;Thunk to eval to visit the library.
	     (visit-proc	(lambda ()
				  (initial-visit! macro*)))
	     ;;Thunk to eval to invoke the library.
	     (invoke-proc	(lambda ()
				  (eval-core (expanded->core invoke-code))))
	     (visit-code	(%build-visit-code macro*)))
	 (install-library uid libname.ids libname.version
			  import-desc* visit-desc* invoke-desc*
			  export-subst export-env
			  visit-proc invoke-proc
			  visit-code invoke-code
			  guard-code guard-desc*
			  #t #;visible?
			  filename)
	 (values uid libname.ids libname.version
		 import-desc* visit-desc* invoke-desc*
		 invoke-code visit-code
		 export-subst export-env
		 guard-code guard-desc*)))))

  (define (%build-visit-code macro*)
    ;;Return a sexp  representing code that initialises  the bindings of
    ;;macro  definitions in  the  core language:  the  visit code;  code
    ;;evaluated whenever the library is visited; each library is visited
    ;;only once the first time an exported binding is used.  MACRO* is a
    ;;list of sublists, each having the format:
    ;;
    ;;   (?loc . (?obj . ?src-code))
    ;;
    ;;The returned sexp looks like this (one SET! for every macro):
    ;;
    ;;  (begin
    ;;    (set! G3
    ;;      (annotated-case-lambda
    ;;	      (#<syntax expr=lambda mark*=(top)>
    ;;	       (#<syntax expr=stx mark*=(top)>)
    ;;         #<syntax expr=3 mark*=(top)>)
    ;;	      ((stx) '3)))
    ;;    (set! G5
    ;;      (annotated-call
    ;;	      (make-compile-time-value (+ 4 5))
    ;;	      (primitive make-compile-time-value)
    ;;	      (annotated-call (+ 4 5)
    ;;          (primitive +) '4 '5))))
    ;;
    (if (null? macro*)
	(build-void)
      (build-sequence no-source
	(map (lambda (x)
	       (let ((loc (car x))
		     (src (cddr x)))
		 (build-global-assignment no-source loc src)))
	  macro*))))

  #| end of module: EXPAND-LIBRARY |# )


(module CORE-LIBRARY-EXPANDER
  (core-library-expander)
  (define-constant __who__ 'core-library-expander)

  (define (core-library-expander library-sexp verify-name)
    ;;Given a  SYNTAX-MATCH expression  argument representing  a LIBRARY
    ;;form:
    ;;
    ;;   (library . _)
    ;;
    ;;parse  it  and return  multiple  values  representing the  library
    ;;contents.
    ;;
    ;;VERIFY-NAME  must  be  a   procedure  accepting  2  arguments  and
    ;;returning  unspecified values:
    ;;
    ;;* The first argument is a list of symbols from a library name.
    ;;
    ;;*  The  second argument  is  null  or  a  list of  exact  integers
    ;;  representing the library version.
    ;;
    ;;VERIFY-NAME is meant  to perform some validation  upon the library
    ;;name  components and  raise an  exception if  something is  wrong;
    ;;otherwise it should just return.
    ;;
    (receive (library-name* export-spec* import-spec* body*)
	(%parse-library library-sexp)
      (receive (libname.ids libname.version)
	  (%parse-library-name library-name*)
	(verify-name libname.ids libname.version)
	(let ((stale-clt (%make-stale-collector)))
	  (receive (import-lib* invoke-lib* visit-lib* invoke-code macro* export-subst export-env)
	      (parametrise ((stale-when-collector stale-clt))
		(begin
		  (import CORE-BODY-EXPANDER)
		  (core-body-expander export-spec* import-spec* body* #f)))
	    (receive (guard-code guard-lib*)
		(stale-clt)
	      (values libname.ids libname.version
		      import-lib* invoke-lib* visit-lib*
		      invoke-code macro* export-subst
		      export-env guard-code guard-lib*)))))))

  (define (%parse-library library-sexp)
    ;;Given an  ANNOTATION struct  representing a LIBRARY  form symbolic
    ;;expression, return 4 values:
    ;;
    ;;1..The name part.  A SYNTAX-MATCH expression argument representing
    ;;   parts of the library name.
    ;;
    ;;2..The   export  specs.    A   SYNTAX-MATCH  expression   argument
    ;;   representing the exports specification.
    ;;
    ;;3..The   import  specs.    A   SYNTAX-MATCH  expression   argument
    ;;   representing the imports specification.
    ;;
    ;;4..The body  of the  library.  A SYNTAX-MATCH  expression argument
    ;;   representing the body of the library.
    ;;
    ;;This function  performs no validation  of the returned  values, it
    ;;just validates the structure of the LIBRARY form.
    ;;
    (syntax-match library-sexp ()
      ((?library (?name* ...)
		 (?export ?exp* ...)
		 (?import ?imp* ...)
		 ?body* ...)
       (and (eq? (syntax->datum ?library) 'library)
	    (eq? (syntax->datum ?export)  'export)
	    (eq? (syntax->datum ?import)  'import))
       (values ?name* ?exp* ?imp* ?body*))
      (_
       (syntax-violation __who__ "malformed library" library-sexp))))

  (define (%parse-library-name libname)
    ;;Given a  SYNTAX-MATCH expression  argument LIBNAME  representing a
    ;;library name as defined by R6RS, return 2 values:
    ;;
    ;;1. A list of symbols representing the name identifiers.
    ;;
    ;;2. A list of fixnums representing the version of the library.
    ;;
    ;;Example:
    ;;
    ;;   (%parse-library-name (foo bar (1 2 3)))
    ;;   => (foo bar) (1 2 3)
    ;;
    (receive (name* ver*)
	(let recur ((sexp libname))
	  (syntax-match sexp ()
	    (((?vers* ...))
	     (for-all library-version-number? (map syntax->datum ?vers*))
	     (values '() (map syntax->datum ?vers*)))

	    ((?id . ?rest)
	     (symbol? (syntax->datum ?id))
	     (receive (name* vers*)
		 (recur ?rest)
	       (values (cons (syntax->datum ?id) name*) vers*)))

	    (()
	     (values '() '()))

	    (_
	     (syntax-violation __who__ "invalid library name" libname))))
      (when (null? name*)
	(syntax-violation __who__ "empty library name" libname))
      (values name* ver*)))

  (module (%make-stale-collector)
    ;;When a library has code like:
    ;;
    ;;   (stale-when (< 1 2) (define a 123))
    ;;   (stale-when (< 2 3) (define b 123))
    ;;
    ;;we build STALE-CODE as follows:
    ;;
    ;;   (if (if '#f
    ;;           '#t
    ;;         (annotated-call (< 1 2) (primitive <) '1 '2))
    ;;       '#t
    ;;     (annotated-call (< 2 3) (primitive <) '2 '3))
    ;;
    ;;The value GUARD-LIB* is the list of LIBRARY records accumulated by
    ;;the INV-COLLECTOR while expanding the STALE-WHEN test expressions.
    ;;
    (define (%make-stale-collector)
      (let ((accumulated-code           (build-data no-source #f))
	    (accumulated-requested-lib* '()))
	(case-lambda
	 (()
	  (values accumulated-code accumulated-requested-lib*))
	 ((new-test-code requested-lib*)
	  (set! accumulated-code
		(build-conditional no-source
		  accumulated-code	    ;test
		  (build-data no-source #t) ;consequent
		  new-test-code))	    ;alternate
	  (set! accumulated-requested-lib*
		(%set-union requested-lib* accumulated-requested-lib*))))))

    (define (%set-union ls1 ls2)
      ;;Build and return a new list holding elements from LS1 and LS2 with
      ;;duplicates removed.
      ;;
      (cond ((null? ls1)
	     ls2)
	    ((memq (car ls1) ls2)
	     (%set-union (cdr ls1) ls2))
	    (else
	     (cons (car ls1)
		   (%set-union (cdr ls1) ls2)))))

    #| end of module: %MAKE-STALE-COLLECTOR |# )

  #| end of module: CORE-LIBRARY-EXPANDER |# )


(module CORE-BODY-EXPANDER
  (core-body-expander)
  ;;Both the R6RS  programs expander and the R6RS  library expander make
  ;;use of this module to expand the body forms.
  ;;
  ;;Let's take this library as example:
  ;;
  ;;   (library (demo)
  ;;     (export var1
  ;;             (rename (var2 the-var2))
  ;;             mac)
  ;;     (import (vicare))
  ;;     (define var1 1)
  ;;     (define var2 2)
  ;;     (define-syntax (mac stx) 3))
  ;;
  ;;When expanding the body of a library: the argument EXPORT-SPEC* is a
  ;;SYNTAX-MATCH  input argument  representing a  set of  library export
  ;;specifications; when  expanding the body of  a program: EXPORT-SPEC*
  ;;is the symbol "all".
  ;;
  ;;IMPORT-SPEC* is a SYNTAX-MATCH input  argument representing a set of
  ;;library import specifications.
  ;;
  ;;BODY-SEXP* is  a SYNTAX-MATCH  input argument representing  the body
  ;;forms.
  ;;
  ;;MIX? is  true when expanding  a program  and false when  expanding a
  ;;library; when  true mixing top-level definitions  and expressions is
  ;;fine.
  ;;
  ;;Return multiple values:
  ;;
  ;;1. A list of LIBRARY records representing the collection accumulated
  ;;    by  the  IMP-COLLECTOR.   The records  represent  the  libraries
  ;;   imported by the IMPORT syntaxes.
  ;;
  ;;2. A list of LIBRARY records representing the collection accumulated
  ;;    by  the  INV-COLLECTOR.   The records  represent  the  libraries
  ;;   exporting the global variable bindings referenced in the run-time
  ;;   code.
  ;;
  ;;3. A list of LIBRARY records representing the collection accumulated
  ;;    by  the  VIS-COLLECTOR.   The records  represent  the  libraries
  ;;    exporting  the  global   variable  bindings  referenced  in  the
  ;;   right-hand sides of syntax definitions.
  ;;
  ;;4.  INVOKE-CODE  is  a   core  language  LIBRARY-LETREC*  expression
  ;;   representing the  result of expanding the input  source.  For the
  ;;   library in the example INVOKE-CODE is:
  ;;
  ;;      (library-letrec*
  ;;          ((#{var1 |5DIy7SQkW5FM0cxk|} #{var1 |P7HvyR0HLiAhK2$r|} '1)
  ;;           (#{var2 |E>%Ta%%32B=RWtyX|} #{var2 |aANiRYtpezblMkJf|} '2))
  ;;        ((primitive void)))
  ;;
  ;;5. MACRO* is  a list of bindings representing the  macros defined in
  ;;   the code.  For the example library MACRO* is:
  ;;
  ;;      ((#{g3 |wHN7M5vmyDul<JV8|} #<procedure> .
  ;;         (annotated-case-lambda (#'lambda (#'stx) #'3) ((#'stx) '3)))
  ;;
  ;;6. EXPORT-SUBST is an alist with entries having the format:
  ;;
  ;;      (?name . ?label)
  ;;
  ;;   where:  ?NAME is a  symbol representing  the external name  of an
  ;;    exported   syntactic  binding;  ?LABEL  is   a  gensym  uniquely
  ;;    identifying such  syntactic  binding.  For  the  library in  the
  ;;   example, EXPORT-SUBST is:
  ;;
  ;;      ((mac      . #{g2 |b78b07G2HAdd7zR6|})
  ;;       (the-var2 . #{g1 |PwmRW?UEJK48Q<tQ|})
  ;;       (var1     . #{g0 |AdFJ$kPI0R39z7%r|}))
  ;;
  ;;7. EXPORT-ENV is the lexical environment of bindings exported by the
  ;;   library.   Its format is different  from the one of  the LEXENV.*
  ;;   values used throughout the expansion process.  For the library in
  ;;   the example, EXPORT-ENV is:
  ;;
  ;;      ((#{g0 |AdFJ$kPI0R39z7%r|} global       . #{var1 |P7HvyR0HLiAhK2$r|})
  ;;       (#{g1 |PwmRW?UEJK48Q<tQ|} global       . #{var2 |aANiRYtpezblMkJf|})
  ;;       (#{g2 |b78b07G2HAdd7zR6|} global-macro . #{g3   |wHN7M5vmyDul<JV8|}))
  ;;
  (define (core-body-expander export-spec* import-spec* body-sexp* mix?)
    (define itc (make-collector))
    (parametrise ((imp-collector      itc)
		  (top-level-context  #f))
      ;;SUBST-NAMES is a  vector of substs; SUBST-LABELS is  a vector of
      ;;gensyms acting as labels.
      (receive (subst-names subst-labels)
	  (let ()
	    (import PARSE-IMPORT-SPEC)
	    (parse-import-spec* import-spec*))
	(let ((rib (make-top-rib subst-names subst-labels)))
	  (define (wrap x)
	    (make-<stx> x top-mark* (list rib) '()))
	  (let ((body-stx*	(map wrap body-sexp*))
		(rtc		(make-collector))
		(vtc		(make-collector)))
	    (parametrise ((inv-collector  rtc)
			  (vis-collector  vtc))
	      ;;INIT-FORM-STX* is a list  of syntax objects representing
	      ;;the trailing  non-definition forms from the  body of the
	      ;;library and the body of the internal modules.
	      ;;
	      ;;LEX*  is  a  list  of  gensyms to  be  used  in  binding
	      ;;definitions   when  building   core  language   symbolic
	      ;;expressions for the glocal  DEFINE forms in the library.
	      ;;There is a gensym for every item in RHS-FORM*.
	      ;;
	      ;;RHS-FORM-STX* is  a list of syntax  objects representing
	      ;;the right-hand side expressions in the DEFINE forms from
	      ;;the body of the library.
	      ;;
	      ;;INTERNAL-EXPORT*  is  a  list  of  identifiers  exported
	      ;;through internal EXPORT syntaxes  rather than the export
	      ;;spec at the beginning of the library.
	      ;;
	      (receive (init-form-stx* lexenv.run lexenv.expand lex* rhs-form-stx* internal-export*)
		  (%chi-library-internal body-stx* rib mix?)
		(receive (export-name* export-id*)
		    (let ()
		      (import PARSE-EXPORT-SPEC)
		      (parse-export-spec* (if (%expanding-program? export-spec*)
					      (map wrap (top-marked-symbols rib))
					    (append (map wrap export-spec*)
						    internal-export*))))
		  (seal-rib! rib)
		  ;;INIT-FORM-CORE* is a list  of core language symbolic
		  ;;expressions representing the trailing init forms.
		  ;;
		  ;;RHS-FORM-CORE* is  a list of core  language symbolic
		  ;;expressions   representing  the   DEFINE  right-hand
		  ;;sides.
		  ;;
		  ;;We want order here!?!
		  (let* ((init-form-core*  (chi-expr* init-form-stx* lexenv.run lexenv.expand))
			 (rhs-form-core*   (chi-rhs*  rhs-form-stx*  lexenv.run lexenv.expand)))
		    (unseal-rib! rib)
		    (let ((loc*          (map gensym-for-location lex*))
			  (export-subst  (%make-export-subst export-name* export-id*)))
		      (receive (export-env macro*)
			  (%make-export-env/macro* lex* loc* lexenv.run)
			(%validate-exports export-spec* export-subst export-env)
			(let ((invoke-code (build-library-letrec* no-source
					     mix? lex* loc* rhs-form-core*
					     (if (null? init-form-core*)
						 (build-void)
					       (build-sequence no-source init-form-core*)))))
			  (values (itc) (rtc) (vtc)
				  invoke-code macro* export-subst export-env)))))))))))))

  (define-syntax-rule (%expanding-program? ?export-spec*)
    (eq? 'all ?export-spec*))

  (define-inline (%chi-library-internal body-stx* rib mix?)
    ;;Perform  the expansion  of the  top-level forms  in the  body; the
    ;;right-hand sides  of DEFINE  syntaxes are  not expanded  here; the
    ;;trailing init forms are not expanded here.
    ;;
    (receive (trailing-init-form-stx*
	      lexenv.run lexenv.expand lex*
	      rhs-form-stx* module-init-form-stx** unused-kwd* internal-export*)
	(chi-body* body-stx* '() '() '() '() '() '() '() rib mix? #t)
      ;;We build  a list of  init form  putting first the  trailing init
      ;;forms from the internal MODULE  syntaxes, then the trailing init
      ;;forms from the library body.
      (let ((init-form-stx* (append (apply append (reverse module-init-form-stx**))
				    trailing-init-form-stx*)))
	(values init-form-stx*
		lexenv.run lexenv.expand
		;;This  is a  list  of  gensyms to  be  used in  binding
		;;definitions  when  building   core  language  symbolic
		;;expressions  for  the  DEFINE forms  in  the  library.
		;;There is a gensym for every item in RHS-FORM-STX*.
		(reverse lex*)
		;;This  is a  list  of syntax  objects representing  the
		;;right-hand side  expressions in the DEFINE  forms from
		;;the body of the library.
		(reverse rhs-form-stx*)
		;;This  is  a  list   of  identifiers  exported  through
		;;internal EXPORT  syntaxes rather than the  export spec
		;;at the beginning of the library.
		internal-export*))))

  (define (%make-export-subst export-name* export-id*)
    ;;For every  identifier in  ID: get  the rib of  ID and  extract the
    ;;lexical environment from it; search  the environment for a binding
    ;;associated  to ID  and acquire  its label  (a gensym).   Return an
    ;;alist with entries having the format:
    ;;
    ;;   (?export-name . ?label)
    ;;
    ;;where ?EXPORT-NAME is  a symbol representing the  external name of
    ;;an exported  binding, ?LABEL is the  corresponding gensym uniquely
    ;;identifying the binding.
    ;;
    (map (lambda (export-name export-id)
	   (let ((label (id->label export-id)))
	     (if label
		 (cons export-name label)
	       (stx-error export-id "cannot export unbound identifier"))))
      export-name* export-id*))

  (module (%make-export-env/macro*)
    ;;For each entry in the  lexical environment LEXENV.RUN: convert the
    ;;syntactic  binding to  an export  environment entry,  accumulating
    ;;EXPORT-ENV; if  the syntactic binding  is a macro  or compile-time
    ;;value: accumulate the MACRO* alist.
    ;;
    ;;Notice that EXPORT-ENV contains an  entry for every global lexical
    ;;variable, both the exported ones and the non-exported ones.  It is
    ;;responsibility  of   the  EXPORT-SUBST   to  select   the  entries
    ;;representing the exported bindings.
    ;;
    ;;LEX* must  be a  list of gensyms  representing the  global lexical
    ;;variables bindings.
    ;;
    ;;LOC* must be a list  of gensyms representing the storage locations
    ;;for the global lexical variables bindings.
    ;;
    (define (%make-export-env/macro* lex* loc* lexenv.run)
      (let loop ((lexenv.run		lexenv.run)
		 (export-env		'())
		 (macro*		'()))
	(if (null? lexenv.run)
	    (values export-env macro*)
	  (let* ((entry    (car lexenv.run))
		 (label    (lexenv-entry-label   entry))
		 (binding  (lexenv-entry-binding entry)))
	    (case (syntactic-binding-type binding)
	      ((lexical)
	       ;;This binding is  a lexical variable.  When  we import a
	       ;;lexical binding from another  library, we must see such
	       ;;entry as "global".
	       ;;
	       ;;The entry from the lexical environment looks like this:
	       ;;
	       ;;   (lexical . (?lexvar . ?mutable))
	       ;;
	       ;;Add to the EXPORT-ENV an entry like:
	       ;;
	       ;;   (?label ?type . ?loc)
	       ;;
	       ;;where  ?TYPE  is the  symbol  "mutable"  or the  symbol
	       ;;"global"; notice that the entries of type "mutable" are
	       ;;forbidden to be exported.
	       ;;
	       (let* ((bind-val  (syntactic-binding-value binding))
		      (loc       (%lookup (lexical-var bind-val) lex* loc*))
		      (type      (if (lexical-var-mutated? bind-val)
				     'mutable
				   'global)))
		 (loop (cdr lexenv.run)
		       (cons (cons* label type loc) export-env)
		       macro*)))

	      ((local-macro)
	       ;;When we  define a binding for  a non-identifier syntax:
	       ;;the local code sees it  as "local-macro".  If we export
	       ;;such   binding:  the   importer  must   see  it   as  a
	       ;;"global-macro".
	       ;;
	       ;;The entry from the lexical environment looks like this:
	       ;;
	       ;;   (local-macro . (?transformer . ?expanded-expr))
	       ;;
	       ;;Add to the EXPORT-ENV an entry like:
	       ;;
	       ;;   (?label global-macro . ?loc)
	       ;;
	       ;;and to the MACRO* an entry like:
	       ;;
	       ;;   (?loc . (?transformer . ?expanded-expr))
	       ;;
	       (let ((loc (gensym)))
		 (loop (cdr lexenv.run)
		       (cons (cons* label 'global-macro loc) export-env)
		       (cons (cons loc (syntactic-binding-value binding)) macro*))))

	      ((local-macro!)
	       ;;When we define a binding  for an identifier syntax: the
	       ;;local  code sees  it as  "local-macro!".  If  we export
	       ;;such   binding:  the   importer  must   see  it   as  a
	       ;;"global-macro!".
	       ;;
	       ;;The entry from the lexical environment looks like this:
	       ;;
	       ;;   (local-macro! . (?transformer . ?expanded-expr))
	       ;;
	       ;;Add to the EXPORT-ENV an entry like:
	       ;;
	       ;;   (?label global-macro . ?loc)
	       ;;
	       ;;and to the MACRO* an entry like:
	       ;;
	       ;;   (?loc . (?transformer . ?expanded-expr))
	       ;;
	       (let ((loc (gensym)))
		 (loop (cdr lexenv.run)
		       (cons (cons* label 'global-macro! loc) export-env)
		       (cons (cons loc (syntactic-binding-value binding)) macro*))))

	      ((local-ctv)
	       ;;When  we  define a  binding  for  a compile-time  value
	       ;;(CTV): the  local code sees  it as "local-ctv".   If we
	       ;;export  such binding:  the importer  must see  it as  a
	       ;;"global-ctv".
	       ;;
	       ;;The entry from the lexical environment looks like this:
	       ;;
	       ;;   (local-ctv . (?object . ?expanded-expr))
	       ;;
	       ;;Add to the EXPORT-ENV an entry like:
	       ;;
	       ;;   (?label global-ctv . ?loc)
	       ;;
	       ;;and to the MACRO* an entry like:
	       ;;
	       ;;   (?loc . (?object . ?expanded-expr))
	       ;;
	       (let ((loc (gensym)))
		 (loop (cdr lexenv.run)
		       (cons (cons* label 'global-ctv loc) export-env)
		       (cons (cons loc (syntactic-binding-value binding)) macro*))))

	      (($rtd $module $fluid)
	       ;;Just add the entry "as is" from the lexical environment
	       ;;to the EXPORT-ENV.
	       ;;
	       (loop (cdr lexenv.run)
		     (cons entry export-env)
		     macro*))

	      (else
	       (assertion-violation 'expander
		 "BUG: do not know how to export"
		 (syntactic-binding-type  binding)
		 (syntactic-binding-value binding))))))))

    (define (%lookup lexical-gensym lex* loc*)
      ;;Search for  LEXICAL-GENSYM in the  list LEX*: when  found return
      ;;the corresponding  gensym from LOC*.  LEXICAL-GENSYM  must be an
      ;;item in LEX*.
      ;;
      (if (pair? lex*)
	  (if (eq? lexical-gensym (car lex*))
	      (car loc*)
	    (%lookup lexical-gensym (cdr lex*) (cdr loc*)))
	(assertion-violation 'lookup-make-export "BUG")))

    #| end of module: %MAKE-EXPORT-ENV/MACRO* |# )

  (define (%validate-exports export-spec* export-subst export-env)
    ;;We want to forbid code like the following:
    ;;
    ;;    (library (proof)
    ;;      (export that doit)
    ;;      (import (vicare))
    ;;      (define that 123)
    ;;      (define (doit a)
    ;;	      (set! that a)))
    ;;
    ;;in which the mutable variable THAT is exported.
    ;;
    (unless (%expanding-program? export-spec*)
      (for-each (lambda (subst)
		  (cond ((assq (subst-entry-label subst) export-env)
			 => (lambda (entry)
			      (when (eq? 'mutable (syntactic-binding-type (lexenv-entry-binding entry)))
				(syntax-violation 'export
				  "attempt to export mutated variable" (subst-entry-name subst)))))))
	export-subst)))

  #| end of module: CORE-BODY-EXPANDER |# )


(module PARSE-EXPORT-SPEC
  (parse-export-spec*)
  ;;Given a  list of SYNTAX-MATCH expression  arguments representing the
  ;;exports specification from a LIBRARY form, return 2 values:
  ;;
  ;;1. A list of symbols representing the external names of the exported
  ;;   bindings.
  ;;
  ;;2.  A  list of  identifiers  (syntax  objects  holding a  symbol  as
  ;;    expression)  representing the  internal  names  of the  exported
  ;;   bindings.
  ;;
  ;;This function checks that none  of the identifiers is BOUND-ID=?  to
  ;;another: the library does not export the same external *name* twice.
  ;;It is instead possible to  export the same identifier multiple times
  ;;if we give it different external names.
  ;;
  ;;According to R6RS, an export specification has the following syntax:
  ;;
  ;;   (export ?export-spec ...)
  ;;
  ;;   ?export-spec
  ;;     == ?identifier
  ;;     == (rename (?internal-identifier ?external-identifier) ...)
  ;;
  ;;Vicare adds the following:
  ;;
  ;;     == (prefix   (?internal-identifier ...) the-prefix)
  ;;     == (deprefix (?internal-identifier ...) the-prefix)
  ;;     == (suffix   (?internal-identifier ...) the-suffix)
  ;;     == (desuffix (?internal-identifier ...) the-suffix)
  ;;
  (define-constant __who__ 'export)

  (define (parse-export-spec* export-spec*)
    (case-define %synner
      ((message)
       (syntax-violation __who__ message export-spec*))
      ((message subform)
       (syntax-violation __who__ message export-spec* subform)))
    (let loop ((export-spec*          export-spec*)
	       (internal-identifier*  '())
	       (external-identifier*  '()))
      (if (null? export-spec*)
	  (if (valid-bound-ids? external-identifier*)
	      (values (map syntax->datum external-identifier*)
		      internal-identifier*)
	    (%synner "invalid exports" (%find-dups external-identifier*)))
	(syntax-match (car export-spec*) ()
	  (?identifier
	   (identifier? ?identifier)
	   (loop (cdr export-spec*)
		 (cons ?identifier internal-identifier*)
		 (cons ?identifier external-identifier*)))

	  ((?rename (?internal* ?external*) ...)
	   (and (eq? (syntax->datum ?rename) 'rename)
		(for-all identifier? ?internal*)
		(for-all identifier? ?external*))
	   (loop (cdr export-spec*)
		 (append ?internal* internal-identifier*)
		 (append ?external* external-identifier*)))

	  ((?prefix (?internal* ...) ?the-prefix)
	   (and (eq? (syntax->datum ?prefix) 'prefix)
		(for-all identifier? ?internal*)
		(identifier? ?the-prefix))
	   (if (strict-r6rs)
	       (%synner "prefix export specification forbidden in strict R6RS mode")
	     (let* ((prefix.str (symbol->string (syntax->datum ?the-prefix)))
		    (external*  (map (lambda (id)
				       (datum->syntax
					id (string->symbol
					    (string-append
					     prefix.str
					     (symbol->string (syntax->datum id))))))
				  ?internal*)))
	       (loop (cdr export-spec*)
		     (append ?internal* internal-identifier*)
		     (append  external* external-identifier*)))))

	  ((?deprefix (?internal* ...) ?the-prefix)
	   (and (eq? (syntax->datum ?deprefix) 'deprefix)
		(for-all identifier? ?internal*)
		(identifier? ?the-prefix))
	   (if (strict-r6rs)
	       (%synner "deprefix export specification forbidden in strict R6RS mode")
	     (let* ((prefix.str (symbol->string (syntax->datum ?the-prefix)))
		    (prefix.len (string-length prefix.str))
		    (external*  (map (lambda (id)
				       (let* ((id.str  (symbol->string (syntax->datum id)))
					      (id.len  (string-length id.str)))
					 (if (and (< prefix.len id.len)
						  (string=? prefix.str
							    (substring id.str 0 prefix.len)))
					     (datum->syntax
					      id (string->symbol
						  (substring id.str prefix.len id.len)))
					   (%synner
					    (string-append "binding name \"" id.str
							   "\" cannot be deprefixed of \""
							   prefix.str "\"")))))
				  ?internal*)))
	       (loop (cdr export-spec*)
		     (append ?internal* internal-identifier*)
		     (append  external* external-identifier*)))))

	  ((?suffix (?internal* ...) ?the-suffix)
	   (and (eq? (syntax->datum ?suffix) 'suffix)
		(for-all identifier? ?internal*)
		(identifier? ?the-suffix))
	   (if (strict-r6rs)
	       (%synner "suffix export specification forbidden in strict R6RS mode")
	     (let* ((suffix.str (symbol->string (syntax->datum ?the-suffix)))
		    (external*  (map (lambda (id)
				       (datum->syntax
					id (string->symbol
					    (string-append
					     (symbol->string (syntax->datum id))
					     suffix.str))))
				  ?internal*)))
	       (loop (cdr export-spec*)
		     (append ?internal* internal-identifier*)
		     (append  external* external-identifier*)))))

	  ((?desuffix (?internal* ...) ?the-suffix)
	   (and (eq? (syntax->datum ?desuffix) 'desuffix)
		(for-all identifier? ?internal*)
		(identifier? ?the-suffix))
	   (if (strict-r6rs)
	       (%synner "desuffix export specification forbidden in strict R6RS mode")
	     (let* ((suffix.str (symbol->string (syntax->datum ?the-suffix)))
		    (suffix.len (string-length suffix.str))
		    (external*  (map (lambda (id)
				       (define id.str
					 (symbol->string (syntax->datum id)))
				       (define id.len
					 (string-length id.str))
				       (define prefix.len
					 (fx- id.len suffix.len))
				       (if (and (< suffix.len id.len)
						(string=? suffix.str
							  (substring id.str prefix.len id.len)))
					   (datum->syntax
					    id (string->symbol
						(substring id.str 0 prefix.len)))
					 (%synner
					  (string-append "binding name \"" id.str
							 "\" cannot be desuffixed of \""
							 suffix.str "\""))))
				  ?internal*)))
	       (loop (cdr export-spec*)
		     (append ?internal* internal-identifier*)
		     (append  external* external-identifier*)))))

	  (_
	   (%synner "invalid export specification" (car export-spec*)))))))

  (module (%find-dups)

    (define-inline (%find-dups ls)
      (let loop ((ls    ls)
		 (dups  '()))
	(cond ((null? ls)
	       dups)
	      ((%find-bound=? (car ls) (cdr ls) (cdr ls))
	       => (lambda (x)
		    (loop (cdr ls)
			  (cons (list (car ls) x)
				dups))))
	      (else
	       (loop (cdr ls) dups)))))

    (define (%find-bound=? x lhs* rhs*)
      (cond ((null? lhs*)
	     #f)
	    ((bound-id=? x (car lhs*))
	     (car rhs*))
	    (else
	     (%find-bound=? x (cdr lhs*) (cdr rhs*)))))

    #| end of module: %FIND-DUPS |# )

  #| end of module: PARSE-EXPORT-SPEC* |# )


(module PARSE-IMPORT-SPEC
  (parse-import-spec*)
  ;;Given  a  list  of SYNTAX-MATCH  expression  arguments  representing
  ;;import specifications from  a LIBRARY form, as defined  by R6RS plus
  ;;Vicare extensions:
  ;;
  ;;1. Parse and validate the import specs.
  ;;
  ;;2. For libraries not yet loaded: load the selected library files and
  ;;    add  them  to  the  current  collector  function  referenced  by
  ;;   IMP-COLLECTOR.
  ;;
  ;;3. Apply to  visible binding names the  transformations described by
  ;;   the import spec.
  ;;
  ;;4. Check for name conflicts between imported bindings.
  ;;
  ;;Return  2  values  which can  be  used  to  build  a new  top  level
  ;;environment object and so a top rib:
  ;;
  ;;1.   A vector  of  symbols  representing the  visible  names of  the
  ;;   imported  bindings.
  ;;
  ;;2. A  list of "labels":  unique symbols associated to  the binding's
  ;;   entry in the lexical environment.
  ;;
  ;;
  ;;A  quick  summary  of  R6RS syntax  definitions  along  with  Vicare
  ;;extensions:
  ;;
  ;;  (import ?import-spec ...)
  ;;
  ;;  ?import-spec
  ;;     == ?import-set
  ;;     == (for ?import-set ?import-level)
  ;;
  ;;  ?import-set
  ;;     == ?library-reference
  ;;     == (library ?library-reference)
  ;;     == (only ?import-set ?identifier ...)
  ;;     == (except ?import-set ?identifier)
  ;;     == (rename ?import-set (?identifier1 ?identifier2) ...)
  ;;
  ;;  ?library-reference
  ;;     == (?identifier0 ?identifier ...)
  ;;     == (?identifier0 ?identifier ... ?version-reference)
  ;;
  ;;  ?version-reference
  ;;     == (?sub-version-reference ...)
  ;;     == (and ?version-reference ...)
  ;;     == (or  ?version-reference ...)
  ;;     == (not ?version-reference)
  ;;
  ;;  ?sub-version-reference
  ;;     == ?sub-version
  ;;     == (>=  ?sub-version)
  ;;     == (<=  ?sub-version)
  ;;     == (and ?sub-version-reference ...)
  ;;     == (or  ?sub-version-reference ...)
  ;;     == (not ?sub-version-reference)
  ;;
  ;;  ?sub-version
  ;;     == #<non-negative fixnum>
  ;;
  ;;Vicare extends ?IMPORT-SET with:
  ;;
  ;;     == (prefix ?import-set ?identifier)
  ;;     == (deprefix ?import-set ?identifier)
  ;;     == (suffix ?import-set ?identifier)
  ;;     == (desuffix ?import-set ?identifier)
  ;;
  ;;Example, given:
  ;;
  ;;  ((rename (only (foo)
  ;;                 x z)
  ;;           (x y))
  ;;   (only (bar)
  ;;         q))
  ;;
  ;;this function returns the names and labels:
  ;;
  ;;   #(z y q)		#(z$label x$label q$label)
  ;;
  ;;Imported bindings are referenced by "substs".  A "subst" is an alist
  ;;whose keys are "names" and whose values are "labels":
  ;;
  ;;*  "Name" is  a syntax  object representing  the public  name of  an
  ;;  imported binding, the one we use  to reference it in the code of a
  ;;  library.
  ;;
  ;;* "Label"  is a unique symbol  associated to the binding's  entry in
  ;;  the lexical environment.
  ;;
  (define-constant __who__ 'import)

  (define (parse-import-spec* import-spec*)
    (let loop ((import-spec*  import-spec*)
	       (subst.table   (make-eq-hashtable)))
      ;;SUBST.TABLE has subst names as  keys and subst labels as values.
      ;;It is used  to check for duplicate names  with different labels,
      ;;which is an error.  Example:
      ;;
      ;;   (import (rename (french)
      ;;                   (salut	ciao))	;ERROR!
      ;;           (rename (british)
      ;;                   (hello	ciao)))	;ERROR!
      ;;
      (if (null? import-spec*)
	  (hashtable-entries subst.table)
	  ;; (receive (names labels)
	  ;;     (hashtable-entries subst.table)
	  ;;   (debug-print who names labels)
	  ;;   (values names labels))
	(begin
	  (for-each (lambda (subst.entry)
		      (%add-subst-entry! subst.table subst.entry))
	    (%import-spec->subst (car import-spec*)))
	  (loop (cdr import-spec*) subst.table)))))

  (define-inline (%add-subst-entry! subst.table subst.entry)
    ;;Add  the  given  SUBST.ENTRY to  SUBST.TABLE;  return  unspecified
    ;;values.  Raise a syntax violation if SUBST.ENTRY has the same name
    ;;of an entry in SUBST.TABLE, but different label.
    ;;
    (let ((entry.name  (car subst.entry))
	  (entry.label (cdr subst.entry)))
      (cond ((hashtable-ref subst.table entry.name #f)
	     => (lambda (label)
		  (unless (eq? label entry.label)
		    (%error-two-import-with-different-bindings entry.name))))
	    (else
	     (hashtable-set! subst.table entry.name entry.label)))))

;;; --------------------------------------------------------------------

  (module (%import-spec->subst)

    (define-inline (%import-spec->subst import-spec)
      ;;Process the IMPORT-SPEC and return the corresponding subst.
      ;;
      ;;The IMPORT-SPEC is  parsed; the specified library  is loaded and
      ;;installed, if  not already  in the  library collection;  the raw
      ;;subst from the library definition  is processed according to the
      ;;rules in IMPORT-SPEC.
      ;;
      ;;If an  error is found, including  library version non-conforming
      ;;to the library reference, an exception is raised.
      ;;
      (syntax-match import-spec ()
	((?for ?import-set . ?import-levels)
	 ;;FIXME Here we should validate ?IMPORT-LEVELS even if it is no
	 ;;used by Vicare.  (Marco Maggi; Tue Apr 23, 2013)
	 (eq? (syntax->datum ?for) 'for)
	 (%import-set->subst ?import-set import-spec))

	(?import-set
	 (%import-set->subst ?import-set import-spec))))

    (define (%import-set->subst import-set import-spec)
      ;;Recursive  function.   Process  the IMPORT-SET  and  return  the
      ;;corresponding   subst.    IMPORT-SPEC   is   the   full   import
      ;;specification from the IMPORT clause: it is used for descriptive
      ;;error reporting.
      ;;
      (define (%recurse import-set)
	(%import-set->subst import-set import-spec))
      (define (%local-synner message)
	(%synner message import-spec import-set))
      (syntax-match import-set ()
	((?spec ?spec* ...)
	 ;;According to R6RS, the symbol LIBRARY  can be used to quote a
	 ;;library reference whose first  identifier is "for", "rename",
	 ;;etc.
	 (not (memq (syntax->datum ?spec)
		    '(rename except only prefix deprefix suffix desuffix library)))
	 (%import-library (cons ?spec ?spec*)))

	((?rename ?import-set (?old-name* ?new-name*) ...)
	 (and (eq? (syntax->datum ?rename) 'rename)
	      (for-all id-stx? ?old-name*)
	      (for-all id-stx? ?new-name*))
	 (let ((subst       (%recurse ?import-set))
	       (?old-name*  (map syntax->datum ?old-name*))
	       (?new-name*  (map syntax->datum ?new-name*)))
	   ;;FIXME Rewrite this  to eliminate find* and  rem* and merge.
	   ;;(Abdulaziz Ghuloum)
	   (let ((old-label* (find* ?old-name* subst ?import-set)))
	     (let ((subst (rem* ?old-name* subst)))
	       ;;FIXME Make sure map is valid. (Abdulaziz Ghuloum)
	       (merge-substs (map cons ?new-name* old-label*) subst)))))

	((?except ?import-set ?sym* ...)
	 (and (eq? (syntax->datum ?except) 'except)
	      (for-all id-stx? ?sym*))
	 (let ((subst (%recurse ?import-set)))
	   (rem* (map syntax->datum ?sym*) subst)))

	((?only ?import-set ?name* ...)
	 (and (eq? (syntax->datum ?only) 'only)
	      (for-all id-stx? ?name*))
	 (let* ((subst  (%recurse ?import-set))
		(name*  (map syntax->datum ?name*))
		(name*  (remove-dups name*))
		(lab*   (find* name* subst ?import-set)))
	   (map cons name* lab*)))

	((?prefix ?import-set ?the-prefix)
	 (and (eq? (syntax->datum ?prefix) 'prefix)
	      (id-stx? ?prefix))
	 (let ((subst   (%recurse ?import-set))
	       (prefix  (symbol->string (syntax->datum ?the-prefix))))
	   (map (lambda (x)
		  (cons (string->symbol
			 (string-append prefix (symbol->string (car x))))
			(cdr x)))
	     subst)))

	((?deprefix ?import-set ?the-prefix)
	 (and (eq? (syntax->datum ?deprefix) 'deprefix)
	      (id-stx? ?the-prefix))
	 (if (strict-r6rs)
	     (%local-synner "deprefix import specification forbidden in strict R6RS mode")
	   (let* ((subst       (%recurse ?import-set))
		  (prefix.str  (symbol->string (syntax->datum ?the-prefix)))
		  (prefix.len  (string-length prefix.str)))
	     ;;This should never happen.
	     (when (zero? prefix.len)
	       (%local-synner "null deprefix prefix"))
	     (map (lambda (subst.entry)
		    (let* ((orig.str  (symbol->string (car subst.entry)))
			   (orig.len  (string-length orig.str)))
		      (if (and (< prefix.len orig.len)
			       (string=? prefix.str (substring orig.str 0 prefix.len)))
			  (cons (string->symbol (substring orig.str prefix.len orig.len))
				(cdr subst.entry))
			(%local-synner
			 (string-append "binding name \"" orig.str
					"\" cannot be deprefixed of \"" prefix.str "\"")))))
	       subst))))

	((?suffix ?import-set ?the-suffix)
	 (and (eq? (syntax->datum ?suffix) 'suffix)
	      (id-stx? ?suffix))
	 (if (strict-r6rs)
	     (%local-synner "suffix import specification forbidden in strict R6RS mode")
	   (let ((subst   (%recurse ?import-set))
		 (suffix  (symbol->string (syntax->datum ?the-suffix))))
	     (map (lambda (x)
		    (cons (string->symbol
			   (string-append (symbol->string (car x)) suffix))
			  (cdr x)))
	       subst))))

	((?desuffix ?import-set ?the-suffix)
	 (and (eq? (syntax->datum ?desuffix) 'desuffix)
	      (id-stx? ?the-suffix))
	 (if (strict-r6rs)
	     (%local-synner "desuffix import specification forbidden in strict R6RS mode")
	   (let* ((subst       (%recurse ?import-set))
		  (suffix.str  (symbol->string (syntax->datum ?the-suffix)))
		  (suffix.len  (string-length suffix.str)))
	     ;;This should never happen.
	     (when (zero? suffix.len)
	       (%local-synner "null desuffix suffix"))
	     (map (lambda (subst.entry)
		    (let* ((orig.str    (symbol->string (car subst.entry)))
			   (orig.len    (string-length orig.str))
			   (prefix.len  (fx- orig.len suffix.len)))
		      (if (and (< suffix.len orig.len)
			       (string=? suffix.str
					 (substring orig.str prefix.len orig.len)))
			  (cons (string->symbol (substring orig.str 0 prefix.len))
				(cdr subst.entry))
			(%local-synner
			 (string-append "binding name \"" orig.str
					"\" cannot be desuffixed of \"" suffix.str "\"")))))
	       subst))))

	;;According to R6RS:  the symbol LIBRARY can be used  to quote a
	;;library reference  whose first identifier is  "for", "rename",
	;;etc.
	((?library (?spec* ...))
	 (eq? (syntax->datum ?library) 'library)
	 (%import-library ?spec*))

	(_
	 (%synner "invalid import set" import-spec import-set))))

    (define (%import-library spec*)
      (receive (name version-conforms-to-reference?)
	  (parse-library-reference spec*)
	(when (null? name)
	  (%synner "empty library name" spec*))
	;;Search  for the  library first  in the  collection of  already
	;;installed libraires, then on  the file system.  If successful:
	;;LIB is an instance of LIBRARY struct.
	(let ((lib (find-library-by-name name)))
	  (unless lib
	    (%synner "cannot find library with required name" name))
	  (unless (version-conforms-to-reference? (library-version lib))
	    (%synner "library does not satisfy version specification" spec* lib))
	  ((imp-collector) lib)
	  (library-subst lib))))

    #| end of module: %IMPORT-SPEC->SUBST |# )

;;; --------------------------------------------------------------------

  (module (parse-library-reference)

    (define (parse-library-reference libref)
      ;;Given a  SYNTAX-MATCH expression argument LIBREF  representing a
      ;;library reference  as defined  by R6RS:  parse and  validate it.
      ;;Return 2 values:
      ;;
      ;;1. A list of symbols representing the library spec identifiers.
      ;;
      ;;2. A predicate function to be used to check if a library version
      ;;   conforms with the requirements of this library specification.
      ;;
      (let recur ((spec libref))
	(syntax-match spec ()

	  (((?version-spec* ...))
	   (values '() (%build-version-pred ?version-spec* libref)))

	  ((?id . ?rest*)
	   (id-stx? ?id)
	   (receive (name pred)
	       (recur ?rest*)
	     (values (cons (syntax->datum ?id) name)
		     pred)))

	  (()
	   (values '() (lambda (x) #t)))

	  (_
	   (%synner "invalid library specification in import set" libref spec)))))

    (define (%build-version-pred version-reference libref)
      ;;Recursive function.  Given a  version reference: validate it and
      ;;build and return a predicate function that can be used to verify
      ;;if library versions do conform.
      ;;
      ;;LIBREF must be  the enclosing library reference, it  is used for
      ;;descriptive error reporting.
      ;;
      (define (%recurse X)
	(%build-version-pred X libref))
      (syntax-match version-reference ()
	(()
	 (lambda (x) #t))

	((?and ?version* ...)
	 (eq? (syntax->datum ?and) 'and)
	 (let ((predicate* (map %recurse ?version*)))
	   (lambda (x)
	     (for-all (lambda (pred)
			(pred x))
	       predicate*))))

	((?or ?version* ...)
	 (eq? (syntax->datum ?or) 'or)
	 (let ((predicate* (map %recurse ?version*)))
	   (lambda (x)
	     (exists (lambda (pred)
		       (pred x))
	       predicate*))))

	((?not ?version)
	 (eq? (syntax->datum ?not) 'not)
	 (let ((pred (%recurse ?version)))
	   (lambda (x)
	     (not (pred x)))))

	((?subversion* ...)
	 (let ((predicate* (map (lambda (subversion)
				  (%build-subversion-pred subversion libref))
			     ?subversion*)))
	   (lambda (x)
	     (let loop ((predicate* predicate*)
			(x          x))
	       (cond ((null? predicate*)
		      #t)
		     ((null? x)
		      #f)
		     (else
		      (and ((car predicate*) (car x))
			   (loop (cdr predicate*) (cdr x)))))))))

	(_
	 (%synner "invalid version reference" libref version-reference))))

    (define (%build-subversion-pred subversion* libref)
      ;;Recursive function.   Given a subversion reference:  validate it
      ;;and build  and return a predicate  function that can be  used to
      ;;verify if library versions do conform.
      ;;
      ;;LIBREF must be  the enclosing library reference, it  is used for
      ;;descriptive error reporting.
      ;;
      (define (%recurse X)
	(%build-subversion-pred X libref))
      (syntax-match subversion* ()
	(?subversion-number
	 (%subversion? ?subversion-number)
	 (let ((N (syntax->datum ?subversion-number)))
	   (lambda (x)
	     (= x N))))

	((?and ?subversion* ...)
	 (eq? (syntax->datum ?and) 'and)
	 (let ((predicate* (map %recurse ?subversion*)))
	   (lambda (x)
	     (for-all (lambda (pred)
			(pred x))
	       predicate*))))

	((?or ?subversion* ...)
	 (eq? (syntax->datum ?or) 'or)
	 (let ((predicate* (map %recurse ?subversion*)))
	   (lambda (x)
	     (exists (lambda (pred)
		       (pred x))
	       predicate*))))

	((?not ?subversion)
	 (eq? (syntax->datum ?not) 'not)
	 (let ((pred (%recurse ?subversion)))
	   (lambda (x)
	     (not (pred x)))))

        ((?<= ?subversion-number)
	 (and (eq? (syntax->datum ?<=) '<=)
	      (%subversion? ?subversion-number))
	 (let ((N (syntax->datum ?subversion-number)))
	   (lambda (x)
	     (<= x N))))

	((?>= ?subversion-number)
	 (and (eq? (syntax->datum ?>=) '>=)
	      (%subversion? ?subversion-number))
	 (let ((N (syntax->datum ?subversion-number)))
	   (lambda (x)
	     (>= x N))))

	(_
	 (%synner "invalid sub-version specification in library reference"
		  libref subversion*))))

    (define-inline (%subversion? stx)
      (library-version-number? (syntax->datum stx)))

    #| end of module: PARSE-LIBRARY-REFERENCE |# )

;;; --------------------------------------------------------------------

  (module (merge-substs)

    (define (merge-substs subst1 subst2)
      ;;Recursive function.  Given two substs: merge them and return the
      ;;result.
      ;;
      ;;Assume that SUBST1  has unique entries in itself  and SUBST2 has
      ;;unique entrie in  itself.  If an entry from SUBST1  has the name
      ;;name but different label from an entry in SUBST2: raise a syntax
      ;;error.
      ;;
      (if (null? subst1)
	  subst2
	(%insert-to-subst (car subst1)
			  (merge-substs (cdr subst1) subst2))))

    (define-inline (%insert-to-subst entry subst)
      ;;Given a subst  ENTRY and a SUBST: insert the  entry in the subst
      ;;if it is not already present  and return the result; else return
      ;;SUBST.
      ;;
      (let ((name  (car entry))
	    (label (cdr entry)))
	(cond ((assq name subst)
	       => (lambda (x)
		    (if (eq? (cdr x) label)
			;;Same name and same label: OK.
			subst
		      ;;Same name but different label: ERROR.
		      (%error-two-import-with-different-bindings name))))
	      (else
	       (cons entry subst)))))

    #| end of module: MERGE-SUBSTS |# )

;;; --------------------------------------------------------------------

  (define (find* sym* subst import-spec-stx)
    ;;Find all the entries in SUBST  having as name the symbols in SYM*;
    ;;return the  list of labels  from the  selected entries.  It  is an
    ;;error if a name in SYM* is not present in the SUBST.
    ;;
    ;;IMPORT-SPEC-STX must  be a  syntax object representing  the import
    ;;spec in which  we search for the SYM*; it  is used for descriptive
    ;;error reporting.
    ;;
    ;;This function is the one that raises  an error if we try to import
    ;;an unexistent binding, as in:
    ;;
    ;;   (import (only (vicare) this-does-not-exist))
    ;;
    (map (lambda (sym)
	   (cond ((assq sym subst)
		  => cdr)
		 (else
		  (%synner "cannot find identifier in export list of import spec"
			   import-spec-stx sym))))
      sym*))

  (define (rem* sym* subst)
    ;;Remove  from SUBST  all the  entries having  name in  the list  of
    ;;symbols SYM*.  Return the new  subst with the entries removed.  It
    ;;is fine if some names in SYM* are not present in SUBST.
    ;;
    (let recur ((subst subst))
      (cond ((null? subst)
	     '())
	    ((memq (caar subst) sym*)
	     (recur (cdr subst)))
	    (else
	     (cons (car subst) (recur (cdr subst)))))))

  (define (remove-dups ls)
    ;;Recursive  function.  Remove  duplicate  items from  the list  LS.
    ;;Compare items with EQ?.
    ;;
    (cond ((null? ls)
	   '())
	  ((memq (car ls) (cdr ls))
	   (remove-dups (cdr ls)))
	  (else
	   (cons (car ls) (remove-dups (cdr ls))))))

;;; --------------------------------------------------------------------

  (define (id-stx? x)
    ;;Return true if X is an identifier.
    ;;
    (symbol? (syntax->datum x)))

;;; --------------------------------------------------------------------

  (define (%error-two-import-with-different-bindings name)
    (%synner "two imports with different bindings" name))

  (case-define %synner
    ((message form)
     (syntax-violation __who__ message form))
    ((message form subform)
     (syntax-violation __who__ message form subform)))

  #| end of module: PARSE-IMPORT-SPEC* |# )


;;;; lexical environment: LEXENV entries and syntactic bindings helpers

;;Given the entry  from a lexical environment: return  the gensym acting
;;as label.
;;
(define lexenv-entry-label car)

;;Given the entry from a lexical environment: return the binding value.
;;
(define lexenv-entry-binding cdr)

;;Build and return a new binding.
;;
(define-syntax-rule (make-binding ?bind-type ?bind-val)
  (cons ?bind-type ?bind-val))

;;Given a binding, return its type: a symbol.
;;
(define syntactic-binding-type car)

;;Given a binding, return its value: a pair.
;;
(define syntactic-binding-value cdr)

;;; --------------------------------------------------------------------
;;; lexical variable bindings

(define (make-lexical-var-binding lex)
  ;;Build  and  return a  syntactic  binding  representing an  immutated
  ;;lexical variable.  LEX  must be a symbol representing the  name of a
  ;;lexical variable in the expanded language forms.
  ;;
  (cons* 'lexical lex #f))

;;Accessors for the value in a lexical variable binding.
;;
(define lexical-var		car)
(define lexical-var-mutated?	cdr)

(define (set-lexical-mutable! bind-val)
  ;;Mutator  for the  ?MUTATED  boolean in  a  lexical variable  binding
  ;;value.  This  function must  be applied to  the ?BINDING-VALUE  of a
  ;;lexical variable LEXENV  entry to signal that somewhere  in the code
  ;;this variable is mutated.
  ;;
  (set-cdr! bind-val #t))

(define (add-lexical-binding label lex lexenv)
  ;;Push on  the LEXENV  a new entry  representing an  immutated lexical
  ;;variable binding; return the resulting LEXENV.
  ;;
  ;;LABEL  must be  a syntactic  binding label.   LEX must  be a  symbol
  ;;representing the name of a lexical variable in the expanded language
  ;;forms.
  ;;
  (cons (cons label (make-lexical-var-binding lex))
	lexenv))

(define (add-lexical-bindings label* lex* lexenv)
  ;;Push  on the  given LEXENV  multiple entries  representing immutated
  ;;lexical variable bindings; return the resulting LEXENV.
  ;;
  ;;LABEL* must be  a list of syntactic binding labels.   LEX* must be a
  ;;list of symbols  representing the names of lexical  variables in the
  ;;expanded language forms.
  ;;
  (if (null? label*)
      lexenv
    (add-lexical-bindings ($cdr label*) ($cdr lex*)
			  (add-lexical-binding ($car label*) ($car lex*) lexenv))))

;;; --------------------------------------------------------------------
;;; local macro with non-variable transformer bindings

(define (make-local-macro-binding transformer expanded-expr)
  (cons* 'local-macro transformer expanded-expr))

;;; --------------------------------------------------------------------
;;; local macro with variable transformer bindings

(define (make-local-identifier-macro-binding transformer expanded-expr)
  (cons* 'local-macro! transformer expanded-expr))

;;; --------------------------------------------------------------------
;;; Vicare struct type descriptor bindings
;;; R6RS record type descriptors bindings

(define (struct-or-record-type-descriptor-binding? binding)
  (and (pair? binding)
       (eq? '$rtd (syntactic-binding-type binding))))

(define (make-struct-or-record-type-descriptor-binding bind-val)
  (cons '$rtd bind-val))

(define (core-rtd-binding? binding)
  (and (pair? binding)
       (eq? '$core-rtd (syntactic-binding-type binding))))

;;; --------------------------------------------------------------------
;;; fluid syntax bindings

(define (make-fluid-syntax-binding label)
  (cons '$fluid label))

(define (fluid-syntax-binding? binding)
  (and (pair? binding)
       (eq? '$fluid (syntactic-binding-type binding))))

;;; --------------------------------------------------------------------
;;; compile-time values bindings

(define (make-local-compile-time-value-binding obj expanded-expr)
  ;;Given as arguments:  the actual object computed  from a compile-time
  ;;expression  and  a  core  language sexp  representing  the  original
  ;;expression already expanded, build and return a syntax binding.
  ;;
  (cons* 'local-ctv obj expanded-expr))

(define (local-compile-time-value-binding? binding)
  ;;Given a binding object: return  true if it represents a compile-time
  ;;value; otherwise return false.
  ;;
  (and (pair? binding)
       (eq? 'local-ctv (syntactic-binding-type binding))))

(define local-compile-time-value-binding-object
  ;;Given a binding representing a  local compile time value: return the
  ;;actual compile-time object.
  ;;
  cadr)

;;; --------------------------------------------------------------------
;;; module bindings

(define (make-module-binding iface)
  (cons '$module iface))

;;; --------------------------------------------------------------------

(define (label->syntactic-binding label lexenv)
  ;;Look up  the symbol  LABEL in the  LEXENV as well  as in  the global
  ;;environment.   If an  entry  with  key LABEL  is  found: return  the
  ;;associated binding value; if no  matching entry is found, return the
  ;;special binding:
  ;;
  ;;   (displaced-lexical . #f)
  ;;
  ;;Since all labels are unique,  it doesn't matter which environment we
  ;;consult first; we  lookup the global environment  first because it's
  ;;faster.
  ;;
  (let ((binding (label->syntactic-binding/no-fluids label lexenv)))
    (if (fluid-syntax-binding? binding)
	;;Fluid syntax bindings (created by DEFINE-FLUID-SYNTAX) require
	;;reversed logic: we  have to look them up in  the LEXENV first,
	;;and then in the global environment.
	;;
	;;This is  because we  can nest  at will  FLUID-LET-SYNTAX forms
	;;that  redefine  the binding  by  pushing  new entries  on  the
	;;LEXENV.  To reach  for the innermost we must  query the LEXENV
	;;first.
	;;
	(let ((label (syntactic-binding-value binding)))
	  (cond ((assq label lexenv)
		 => syntactic-binding-value)
		(else
		 (label->syntactic-binding/no-fluids label '()))))
      binding)))

(define (label->syntactic-binding/no-fluids label lexenv)
  ;;Like LABEL->SYNTACTIC-BINDING, but actually does the job.
  ;;
  (cond ((not (symbol? label))
	 '(displaced-lexical))

	;;If a label is associated to  a binding from the the boot image
	;;environment or  to a binding  from a library's  EXPORT-ENV: it
	;;has  the associated  binding in  its "value"  field; otherwise
	;;such field is set to #f.
	;;
	;;So,  if we  have a  label, we  can check  if it  references an
	;;imported binding simply by checking its "value" field; this is
	;;what IMPORTED-LABEL->SYNTACTIC-BINDING does.
	;;
	((imported-label->syntactic-binding label)
	 => (lambda (binding)
	      (if (core-rtd-binding? binding)
		  (make-struct-or-record-type-descriptor-binding
		   (map bless (syntactic-binding-value binding)))
		binding)))

	;;Search the given LEXENV.
	;;
	((assq label lexenv)
	 => syntactic-binding-value)

	;;Search the interaction top-level environment, if any.
	;;
	((top-level-context)
	 => (lambda (env)
	      (cond ((assq label (interaction-env-locs env))
		     => (lambda (binding)
			  ;;Build and  return a binding  representing an
			  ;;immutated lexical variable.
			  (cons* 'lexical (syntactic-binding-value binding) #f)))
		    (else
		     ;;Unbound label.
		     '(displaced-lexical . #f)))))

	;;Unbound label.
	;;
	(else
	 '(displaced-lexical . #f))))


;;;; <RIB> type definition

;;A  <RIB> is  a  record constructed  at  every lexical  contour in  the
;;program to  hold informations about  the variables introduced  in that
;;contour; "lexical contours" are, for example, LET and similar syntaxes
;;that can introduce bindings.
;;
(define-record <rib>
  (sym*
		;List of symbols representing the original binding names
		;in the source code.
		;
		;When the  <RIB> is sealed:  the list is converted  to a
		;vector.

   mark**
		;List of  lists of marks; there  is a list of  marks for
		;every item in SYM*.
		;
		;When the  <RIB> is sealed:  the list is converted  to a
		;vector.

   label*
		;List  of  gensyms  uniquely identifying  the  syntactic
		;bindings; there is a label for each item in SYM*.
		;
		;When the  <RIB> is sealed:  the list is converted  to a
		;vector.

   sealed/freq
		;False or  vector of  exact integers.  When  false: this
		;<RIB> is extensible, that is  new bindings can be added
		;to it.  When a vector: this <RIB> is selaed.
		;
		;See  below  the  code  section "sealing  ribs"  for  an
		;explanation of the frequency vector.
   ))

(define-inline (make-empty-rib)
  (make-<rib> '() '() '() #f))

(define (make-full-rib id* label*)
  ;;Build and  return a  new <RIB> record  taking the binding  names and
  ;;marks  from the  list  of syntax  objects  ID* and  the labels  from
  ;;LABEL*.
  ;;
  ;;It may be a good idea to seal this <RIB>.
  ;;
  (make-<rib> (map identifier->symbol id*)
	      (map <stx>-mark* id*)
	      label*
	      #f))

(define* (make-top-rib name* label*)
  ;;A top <RIB> is constructed as follows: given a subst:
  ;;
  ;;   name* -> label*
  ;;
  ;;where NAME* is a vector of symbols and LABEL* is a vector of labels,
  ;;generate a <RIB> containing:
  ;;
  ;;* name* as the <RIB>-SYM*,
  ;;
  ;;* a list of TOP-MARK* as the <RIB>-MARK**,
  ;;
  ;;* label* as the <RIB>-LABEL*
  ;;
  ;;so, a name in  a top <RIB> maps to its label if  and only if its set
  ;;of marks is TOP-MARK*.
  ;;
  (let ((rib (make-empty-rib)))
    (vector-for-each
        (lambda (name label)
          (if (symbol? name)
	      (extend-rib! rib
			   (make-<stx> name top-mark*
				       '()  #;subst*
				       '()) #;ae*
			   label #t)
            (assertion-violation __who__
	      "Vicare bug: expected symbol as binding name" name)))
      name* label*)
    rib))

(define (subst->rib subst)
  ;;Build and return a new <RIB> structure initialised with SUBST.
  ;;
  ;;A "subst"  is an alist whose  keys are "names" and  whose values are
  ;;"labels":
  ;;
  ;;* "Name"  is a symbol  representing the  public name of  an imported
  ;;  binding, the one we use to reference it in the code of a library.
  ;;
  ;;* "Label"  is a unique symbol  associated to the binding's  entry in
  ;;  the lexical environment.
  ;;
  (let ((rib (make-empty-rib)))
    ($set-<rib>-sym*!   rib (map car subst))
    ($set-<rib>-mark**! rib (map (lambda (x) top-mark*) subst))
    ($set-<rib>-label*! rib (map cdr subst))
    rib))


;;;; extending ribs
;;
;;A <RIB>  may be extensible, or sealed.   Adding an identifier-to-label
;;mapping  to an  extensible <RIB>  is  achieved by  performing all  the
;;following operations:
;;
;;* consing the identifier's name to the list of symbols SYM*;
;;
;;* consing  the identifier's list of  marks to the  <RIB>'s MARK**;
;;
;;* consing the label to the <RIB>'s LABEL*.
;;
;;For example, an empty extensible <RIB> has fields:
;;
;;  sym*   = ()
;;  mark** = ()
;;  label* = ()
;;
;;adding a binding to it with  name "ciao", marks ("m.0") and label "G0"
;;means mutating the fields to:
;;
;;  sym*   = (ciao)
;;  mark** = (("m.0"))
;;  label* = (G0)
;;
;;pushing the "binding tuple": ciao, ("m.0"), G0.
;;
;;Adding another binding with name  "hello", mark ("m.0") and label "G1"
;;means mutating the fields to:
;;
;;  sym*   = (hello ciao)
;;  mark** = (("m.0") ("m.0"))
;;  label* = (G1 G0)
;;
;;As further example, let's consider the form:
;;
;;  (lambda ()
;;    (define a 1)
;;    (define b 2)
;;    (list a b))
;;
;;when starting to process the LAMBDA syntax: a new <RIB> is created and
;;is  added to  the  metadata of  the  LAMBDA form;  when each  internal
;;definition is  encountered, a  new entry for  the identifier  is added
;;(via side effect) to the <RIB>:
;;
;;  sym*   = (b a)
;;  mark** = (("m.0") ("m.0"))
;;  label* = (G1 G0)
;;
;;Notice that the order in which  the binding tuples appear in the <RIB>
;;does not matter: two tuples are different when both the symbol and the
;;marks are  different and it is  an error to  add twice a tuple  to the
;;same <RIB>.
;;

(define (extend-rib! rib id label sd?)
  ;;Extend RIB.
  ;;
  (define (%find sym mark* sym* mark** label*)
    ;;We know  that the list  of symbols SYM*  has at least  one element
    ;;equal to SYM; iterate through  SYM*, MARK** and LABEL* looking for
    ;;a tuple having marks equal to  MARK* and return the tail of LABEL*
    ;;having the associated label as  car.  If such binding is not found
    ;;return false.
    ;;
    (and (pair? sym*)
	 (if (and (eq? sym (car sym*))
		  (same-marks? mark* (car mark**)))
	     label*
	   (%find sym mark* (cdr sym*) (cdr mark**) (cdr label*)))))
  (when (<rib>-sealed/freq rib)
    (assertion-violation 'extend-rib!
      "Vicare: internal error: attempt to extend sealed RIB" rib))
  (let ((sym   (identifier->symbol id))
	(mark* (<stx>-mark* id))
	(sym*  (<rib>-sym* rib)))
    (cond ((and (memq sym (<rib>-sym* rib))
		(%find sym mark* sym* (<rib>-mark** rib) (<rib>-label* rib)))
	   => (lambda (label*-tail)
		(unless (eq? label (car label*-tail))
		  (if (not sd?) ;(top-level-context)
		      ;;XXX override label
		      (set-car! label*-tail label)
		    ;;Signal an error if the identifier was already in
		    ;;the rib.
		    (syntax-violation 'expander "multiple definitions of identifier" id)))))
	  (else
	   (set-<rib>-sym*!   rib (cons sym sym*))
	   (set-<rib>-mark**! rib (cons mark* (<rib>-mark** rib)))
	   (set-<rib>-label*! rib (cons label (<rib>-label* rib)))))))


;;;; sealing ribs
;;
;;A non-empty  <RIB> can be sealed  once all bindings  are inserted.  To
;;seal a <RIB>, we convert the  lists SYM*, MARK** and LABEL* to vectors
;;and insert a frequency vector in the SEALED/FREQ field.  The frequency
;;vector is a Scheme vector of exact integers.
;;
;;The  frequency vector  is an  optimization  that allows  the <RIB>  to
;;reorganize itself by  bubbling frequently used mappings to  the top of
;;the <RIB>.   This is possible because  the order in  which the binding
;;tuples appear in a <RIB> does not matter.
;;
;;The vector  is maintained in non-descending order  and an identifier's
;;entry in the <RIB> is incremented at every access.  If an identifier's
;;frequency  exceeds the  preceeding one,  the identifier's  position is
;;promoted  to the  top of  its  class (or  the bottom  of the  previous
;;class).
;;

(define (seal-rib! rib)
  (let ((sym* (<rib>-sym* rib)))
    (unless (null? sym*) ;only seal if RIB is not empty
      (let ((sym* (list->vector sym*)))
	(set-<rib>-sym*!        rib sym*)
	(set-<rib>-mark**!      rib (list->vector (<rib>-mark** rib)))
	(set-<rib>-label*!      rib (list->vector (<rib>-label* rib)))
	(set-<rib>-sealed/freq! rib (make-vector (vector-length sym*) 0))))))

(define (unseal-rib! rib)
  (when (<rib>-sealed/freq rib)
    (set-<rib>-sealed/freq! rib #f)
    (set-<rib>-sym*!        rib (vector->list (<rib>-sym*   rib)))
    (set-<rib>-mark**!      rib (vector->list (<rib>-mark** rib)))
    (set-<rib>-label*!      rib (vector->list (<rib>-label* rib)))))

(define (increment-rib-frequency! rib idx)
  (let* ((freq* (<rib>-sealed/freq rib))
	 (freq  (vector-ref freq* idx))
	 (i     (let loop ((i idx))
		  (if (zero? i)
		      0
		    (let ((j (- i 1)))
		      (if (= freq (vector-ref freq* j))
			  (loop j)
			i))))))
    (vector-set! freq* i (+ freq 1))
    (unless (= i idx)
      (let ((sym*   (<rib>-sym*   rib))
	    (mark** (<rib>-mark** rib))
	    (label* (<rib>-label* rib)))
	(let-syntax ((%vector-swap (syntax-rules ()
				     ((_ ?vec ?idx1 ?idx2)
				      (let ((V (vector-ref ?vec ?idx1)))
					(vector-set! ?vec ?idx1 (vector-ref ?vec ?idx2))
					(vector-set! ?vec ?idx2 V))))))
	  (%vector-swap sym*   idx i)
	  (%vector-swap mark** idx i)
	  (%vector-swap label* idx i))))))


;;;; syntax object type definition

(define-record <stx>
  (expr
   mark*
   subst*
   ae*)
  (lambda (S port subwriter) ;record printer function
    (define-inline (%display thing)
      (display thing port))
    (define-inline (%write thing)
      (write thing port))
    (define-inline (%pretty-print thing)
      (pretty-print* thing port 0 #f))
    (%display "#<syntax")
    (%display " expr=")		(%pretty-print (syntax->datum S))
    (%display " mark*=")	(%pretty-print (<stx>-mark* S))
    (let ((expr (<stx>-expr S)))
      (when (annotation? expr)
	(let ((pos (annotation-textual-position expr)))
	  (when (source-position-condition? pos)
	    (%display " line=")		(%display (source-position-line    pos))
	    (%display " column=")	(%display (source-position-column  pos))
	    (%display " source=")	(%display (source-position-port-id pos))))))
    (%display ">")))


;;;; marks

;;The body  of a library, when it  is first processed, gets  this set of
;;marks...
(define top-mark* '(top))

;;... consequently, every syntax object that  has a TOP in its marks set
;;was present in the program source.
(define-inline (top-marked? m*)
  (memq 'top m*))

(define (top-marked-symbols rib)
  ;;Scan the <RIB> RIB and return a list of symbols representing binding
  ;;names and having the top mark.
  ;;
  (receive (sym* mark**)
      ;;If RIB is sealed the fields  hold vectors, else they hold lists;
      ;;we want lists here.
      (let ((sym*   (<rib>-sym*   rib))
	    (mark** (<rib>-mark** rib)))
	(if (<rib>-sealed/freq rib)
	    (values (vector->list sym*)
		    (vector->list mark**))
	  (values sym* mark**)))
    (let recur ((sym*   sym*)
		(mark** mark**))
      (cond ((null? sym*)
	     '())
	    ((equal? (car mark**) top-mark*)
	     (cons (car sym*)
		   (recur (cdr sym*) (cdr mark**))))
	    (else
	     (recur (cdr sym*) (cdr mark**)))))))


;;;; stuff about labels, lexical variables, location gensyms

(define top-level-context
  (make-parameter #f))

(define* (gensym-for-lexical-var seed)
  ;;Generate a unique symbol to represent the name of a lexical variable
  ;;in the core language forms.  Such  symbols have the purpose of being
  ;;unique in the core language  expressions representing a full library
  ;;or full program.
  ;;
  (if-wants-descriptive-gensyms
      (cond ((identifier? seed)
	     (gensym (string-append "lex." (symbol->string (identifier->symbol seed)))))
	    ((symbol? seed)
	     (gensym (string-append "lex." (symbol->string seed))))
	    (else
	     (assertion-violation __who__
	       "expected symbol or identifier as argument" seed)))
    (cond ((identifier? seed)
	   (gensym (identifier->symbol seed)))
	  ((symbol? seed)
	   (gensym seed))
	  (else
	   (assertion-violation __who__
	     "expected symbol or identifier as argument" seed)))))

(define (gensym-for-location seed)
  ;;Build  and return  a gensym  to be  used as  storage location  for a
  ;;global lexical variable.  The "value" slot of such gensym is used to
  ;;hold the value of the variable.
  ;;
  (if-wants-descriptive-gensyms
      (cond ((identifier? seed)
	     (gensym (string-append "loc." (symbol->string (identifier->symbol seed)))))
	    ((symbol? seed)
	     (gensym (string-append "loc." (symbol->string seed))))
	    ((string? seed)
	     (gensym (string-append "loc." seed)))
	    (else
	     (gensym)))
    (gensym)))

(define (gensym-for-label seed)
  ;;Every  syntactic binding  has a  label  associated to  it as  unique
  ;;identifier  in the  whole running  process; this  function generates
  ;;such labels as gensyms.
  ;;
  ;;Labels  must have  read/write  EQ?  invariance  to support  separate
  ;;compilation (when we write the expanded sexp to a file and then read
  ;;it back, the labels must not change and still be globally unique).
  ;;
  (if-wants-descriptive-gensyms
      (cond ((identifier? seed)
	     (gensym (string-append "lab." (symbol->string (identifier->symbol seed)))))
	    ((symbol? seed)
	     (gensym (string-append "lab." (symbol->string seed))))
	    ((string? seed)
	     (gensym (string-append "lab." seed)))
	    (else
	     (gensym)))
    (gensym)))

(module (gen-define-label+loc
	 gen-define-label)

  (define (gen-define-label+loc id rib sd?)
    (if sd?
	(values (gensym) (gensym-for-lexical-var id))
      (let* ((env   (top-level-context))
	     (label (%gen-top-level-label id rib))
	     (locs  (interaction-env-locs env)))
	(values label (cond ((assq label locs)
			     => cdr)
			    (else
			     (receive-and-return (loc)
				 (gensym-for-location id)
			       (set-interaction-env-locs! env (cons (cons label loc) locs)))))))))

  (define (gen-define-label id rib sd?)
    (if sd?
	(gensym)
      (%gen-top-level-label id rib)))

  (define (%gen-top-level-label id rib)
    (let ((sym   (identifier->symbol id))
	  (mark* (<stx>-mark*        id))
	  (sym*  (<rib>-sym*         rib)))
      (cond ((and (memq sym (<rib>-sym* rib))
		  (%find sym mark* sym* (<rib>-mark** rib) (<rib>-label* rib)))
	     => (lambda (label)
		  ;;If we  are here  RIB contains a  binding for  ID and
		  ;;LABEL is its label.
		  ;;
		  ;;If  the symbol  LABEL is  associated to  an imported
		  ;;binding: the data  structure implementing the symbol
		  ;;object holds  informations about  the binding  in an
		  ;;internal field; else such field is set to false.
		  (if (imported-label->syntactic-binding label)
		      ;;Create new label to shadow imported binding.
		      (gensym)
		    ;;Recycle old label.
		    label)))
	    (else
	     ;;Create a new label for a new binding.
	     (gensym)))))

  (define (%find sym mark* sym* mark** label*)
    ;;We know  that the list  of symbols SYM*  has at least  one element
    ;;equal to SYM; iterate through  SYM*, MARK** and LABEL* looking for
    ;;a  tuple having  marks equal  to MARK*  and return  the associated
    ;;label.  If such binding is not found return false.
    ;;
    (and (pair? sym*)
	 (if (and (eq? sym (car sym*))
		  (same-marks? mark* (car mark**)))
	     (car label*)
	   (%find sym mark* (cdr sym*) (cdr mark**) (cdr label*)))))

  #| end of module |# )


;;;; syntax objects handling
;;
;;First, let's  look at identifiers,  since they're the real  reason why
;;syntax objects are here to begin  with.  An identifier is an STX whose
;;EXPR is a symbol; in addition to the symbol naming the identifier, the
;;identifer has a  list of marks and a list  of substitutions.
;;
;;The idea  is that to get  the label of  an identifier, we look  up the
;;identifier's substitutions for  a mapping with the same  name and same
;;marks (see SAME-MARKS? below).
;;

(define (datum->stx id datum)
  ;;Since all the identifier->label bindings are encapsulated within the
  ;;identifier, converting a datum to a syntax object (non-hygienically)
  ;;is  done simply  by creating  an  STX that  has the  same marks  and
  ;;substitutions as the identifier.
  ;;
  (make-<stx> datum
	      (<stx>-mark*  id)
	      (<stx>-subst* id)
	      (<stx>-ae*    id)))

(define (datum->syntax id datum)
  (if (identifier? id)
      (datum->stx id datum)
    (assertion-violation 'datum->syntax
      "expected identifier as context syntax object" id)))

(define (syntax->datum S)
  (strip S '()))

(define (mkstx stx/expr mark* subst* ae*)
  ;;This is the proper constructor for wrapped syntax objects.
  ;;
  ;;STX/EXPR can be a raw sexp, an instance of <STX> or a wrapped syntax
  ;;object.  MARK* is a list of marks.  SUBST* is a list of substs.
  ;;
  ;;AE* == annotated expressions???
  ;;
  ;;When STX/EXPR  is a  raw sexp:  just build and  return a  new syntax
  ;;object with the lexical context described by the given arguments.
  ;;
  ;;When STX/EXPR is a syntax object:  join the wraps from STX/EXPR with
  ;;given wraps, making sure that marks and anti-marks and corresponding
  ;;shifts cancel properly.
  ;;
  (if (and (<stx>? stx/expr)
	   (not (top-marked? mark*)))
      (receive (mark* subst* ae*)
	  (join-wraps mark* subst* ae* stx/expr)
	(make-<stx> (<stx>-expr stx/expr) mark* subst* ae*))
    (make-<stx> stx/expr mark* subst* ae*)))

(define (bless x)
  ;;Given a raw  sexp, a single syntax object, a  wrapped syntax object,
  ;;an unwrapped  syntax object or  a partly unwrapped syntax  object X:
  ;;return a syntax object representing the input, possibly X itself.
  ;;
  ;;When  X is  a sexp  or a  (partially) unwrapped  syntax object:  raw
  ;;symbols  in X  are considered  references  to bindings  in the  core
  ;;language:  they are  converted to  identifiers having  empty lexical
  ;;contexts.
  ;;
  (mkstx (let recur ((x x))
	   (cond ((<stx>? x)
		  x)
		 ((pair? x)
		  (cons (recur (car x)) (recur (cdr x))))
		 ((symbol? x)
		  (scheme-stx x))
		 ((vector? x)
		  (list->vector (map recur (vector->list x))))
		 ;;If we are here X is a self-evaluating datum.
		 (else x)))
	 '() #;mark*
	 '() #;subst*
	 '() #;ae*
	 ))

;;; --------------------------------------------------------------------

(define (expression-position x)
  (if (<stx>? x)
      (let ((x (<stx>-expr x)))
	(if (annotation? x)
	    (annotation-textual-position x)
	  (condition)))
    (condition)))

(define (syntax-annotation x)
  (if (<stx>? x)
      (<stx>-expr x)
    x))


;;;; syntax objects and marks

;;A syntax  object may be wrapped  or unwrapped, so what  does that mean
;;exactly?
;;
;;A "wrapped syntax object" is just  a way of saying it's an STX record.
;;All identifiers are  STX records (with a symbol  in their EXPR field);
;;other objects such  as pairs and vectors may  be wrapped or unwrapped.
;;A wrapped pair is an STX whose EXPR is a pair.  An unwrapped pair is a
;;pair whose car  and cdr fields are themselves  syntax objects (wrapped
;;or unwrapped).
;;
;;We always  maintain the  invariant that we  do not double  wrap syntax
;;objects.  The  only way  to get a  doubly-wrapped syntax object  is by
;;doing DATUM->STX  (above) where the  datum is itself a  wrapped syntax
;;object (R6RS  may not even  consider wrapped syntax objects  as datum,
;;but let's not worry now).
;;
;;Syntax objects  have, in  addition to the  EXPR, a  substitution field
;;SUBST*: it is a list where each  element is either a RIB or the symbol
;;"shift".  Normally,  a new  RIB is  added to an  STX at  every lexical
;;contour of the program in  order to capture the bindings introduced in
;;that contour.
;;
;;The MARK* field of an STX is  a list of marks; each of these marks can
;;be  either  a  generated mark  or  an  antimark.   Two marks  must  be
;;EQ?-comparable, so we use a string of one char (we assume that strings
;;are mutable in the underlying Scheme implementation).

(define gen-mark
  ;;Generate a new unique mark.  We want a new string for every function
  ;;call.
  string)
;;The version below is useful for debugging.
;;
;; (define gen-mark
;;   (let ((i 0))
;;     (lambda ()
;;       (set! i (+ i 1))
;;       (string-append "m." (number->string i)))))

;;We use #f as the anti-mark.
(define anti-mark #f)
(define anti-mark? not)

;;So, what's an anti-mark and why is it there?
;;
;;The theory goes like this: when a macro call is encountered, the input
;;stx to the  macro transformer gets an extra  anti-mark, and the output
;;of the  transformer gets a fresh  mark.  When a mark  collides with an
;;anti-mark, they cancel one another.   Therefore, any part of the input
;;transformer that gets copied to  the output would have a mark followed
;;immediately by an  anti-mark, resulting in the same  syntax object (no
;;extra marks).  Parts of the output  that were not present in the input
;;(e.g. inserted by the macro  transformer) would have no anti-mark and,
;;therefore, the mark would stick to them.
;;
;;Every time  a mark is pushed  to an <stx>-mark* list,  a corresponding
;;'shift  is pushed  to the  <stx>-subst* list.   Every time  a mark  is
;;cancelled  by   an  anti-mark,  the  corresponding   shifts  are  also
;;cancelled.

;;The procedure join-wraps,  here, is used to compute the  new mark* and
;;subst* that would  result when the m1*  and s1* are added  to an stx's
;;mark* and subst*.
;;
;;The only tricky part here is that  e may have an anti-mark that should
;;cancel with the last mark in m1*.  So, if:
;;
;;  m1* = (mx* ... mx)
;;  m2* = (#f my* ...)
;;
;;then the resulting marks should be:
;;
;;  (mx* ... my* ...)
;;
;;since mx  would cancel with the  anti-mark.  The substs would  have to
;;also cancel since:
;;
;;    s1* = (sx* ... sx)
;;    s2* = (sy sy* ...)
;;
;;then the resulting substs should be:
;;
;;    (sx* ... sy* ...)
;;
;;Notice that both SX and SY would be shift marks.
;;
;;All   this  work   is  performed   by  the   functions  ADD-MARK   and
;;DO-MACRO-CALL.
;;

(module (join-wraps)

  (define (join-wraps mark1* subst1* ae1* stx2)
    (let ((mark2*   ($<stx>-mark*  stx2))
	  (subst2*  ($<stx>-subst* stx2))
	  (ae2*     ($<stx>-ae*    stx2)))
      ;;If the first item in mark2* is an anti-mark...
      (if (and (not (null? mark1*))
	       (not (null? mark2*))
	       (anti-mark? ($car mark2*)))
	  ;;...cancel mark, anti-mark, and corresponding shifts.
	  (values (%append-cancel-facing mark1*  mark2*)
		  (%append-cancel-facing subst1* subst2*)
		  (%merge-ae* ae1* ae2*))
	;;..else no cancellation takes place.
	(values (append mark1*  mark2*)
		(append subst1* subst2*)
		(%merge-ae* ae1* ae2*)))))

  (define (%merge-ae* ls1 ls2)
    (if (and (pair? ls1)
	     (pair? ls2)
	     (not ($car ls2)))
	(%append-cancel-facing ls1 ls2)
      (append ls1 ls2)))

  (define (%append-cancel-facing ls1 ls2)
    ;;Given two non-empty lists: append them discarding the last item in
    ;;LS1 and the first item in LS2.  Examples:
    ;;
    ;;   (%append-cancel-facing '(1 2 3) '(4 5 6))	=> (1 2 5 6)
    ;;   (%append-cancel-facing '(1)     '(2 3 4))	=> (3 4)
    ;;   (%append-cancel-facing '(1)     '(2))		=> ()
    ;;
    (let recur ((x   ($car ls1))
		(ls1 ($cdr ls1)))
      (if (null? ls1)
	  ($cdr ls2)
	(cons x (recur ($car ls1) ($cdr ls1))))))

  #| end of module: JOIN-WRAPS |# )

(define (same-marks? x y)
  ;;Two lists  of marks are  considered the same  if they have  the same
  ;;length and the corresponding marks on each are EQ?.
  ;;
  (or (and (null? x) (null? y)) ;(eq? x y)
      (and (pair? x) (pair? y)
	   (eq? ($car x) ($car y))
	   (same-marks? ($cdr x) ($cdr y)))))


(define (push-lexical-contour rib stx/expr)
  ;;Add a rib to a syntax  object or expression and return the resulting
  ;;syntax object.  This  procedure introduces a lexical  contour in the
  ;;context of the given syntax object or expression.
  ;;
  ;;RIB must be an instance of <RIB>.
  ;;
  ;;STX/EXPR can be a raw sexp, an instance of <STX> or a wrapped syntax
  ;;object.
  ;;
  ;;This function prepares  a computation that will  be lazily performed
  ;;later; the RIB will be pushed on the stack of substitutions in every
  ;;identifier in the fully unwrapped returned syntax object.
  ;;
  (mkstx stx/expr
	 '() #;mark*
	 (list rib)
	 '() #;ae*
	 ))

(define (add-mark mark subst expr ae)
  ;;Build and return  a new syntax object wrapping  EXPR and having MARK
  ;;pushed on its list of marks.
  ;;
  ;;SUBST can be #f or a list of substitutions.
  ;;
  (define (merge-ae* ls1 ls2)
    ;;Append LS1 and LS2 and return the result; if the car or LS2 is #f:
    ;;append LS1 and (cdr LS2).
    ;;
    ;;   (merge-ae* '(a b c) '(d  e f))   => (a b c d e f)
    ;;   (merge-ae* '(a b c) '(#f e f))   => (a b c e f)
    ;;
    (if (and (pair? ls1)
	     (pair? ls2)
	     (not (car ls2)))
	(cancel ls1 ls2)
      (append ls1 ls2)))
  (define (cancel ls1 ls2)
    ;;Expect LS1 to be a proper list  of one or more elements and LS2 to
    ;;be a proper  list of one or more elements.  Append  the cdr of LS2
    ;;to LS1 and return the result:
    ;;
    ;;   (cancel '(a b c) '(d e f))
    ;;   => (a b c e f)
    ;;
    ;;This function is like:
    ;;
    ;;   (append ls1 (cdr ls2))
    ;;
    ;;we just hope to be a bit more efficient.
    ;;
    (let recur ((A (car ls1))
		(D (cdr ls1)))
      (if (null? D)
	  (cdr ls2)
	(cons A (recur (car D) (cdr D))))))
  (define (f sub-expr mark subst1* ae*)
    (cond ((pair? sub-expr)
	   (let ((a (f (car sub-expr) mark subst1* ae*))
		 (d (f (cdr sub-expr) mark subst1* ae*)))
	     (if (eq? a d)
		 sub-expr
	       (cons a d))))
	  ((vector? sub-expr)
	   (let* ((ls1 (vector->list sub-expr))
		  (ls2 (map (lambda (x)
			      (f x mark subst1* ae*))
			 ls1)))
	     (if (for-all eq? ls1 ls2)
		 sub-expr
	       (list->vector ls2))))
	  ((<stx>? sub-expr)
	   (let ((mark*   (<stx>-mark*  sub-expr))
		 (subst2* (<stx>-subst* sub-expr)))
	     (cond ((null? mark*)
		    (f (<stx>-expr sub-expr)
		       mark
		       (append subst1* subst2*)
		       (merge-ae* ae* (<stx>-ae* sub-expr))))
		   ((eq? (car mark*) anti-mark)
		    (make-<stx> (<stx>-expr sub-expr) (cdr mark*)
				(cdr (append subst1* subst2*))
				(merge-ae* ae* (<stx>-ae* sub-expr))))
		   (else
		    (make-<stx> (<stx>-expr sub-expr)
				(cons mark mark*)
				(let ((s* (cons 'shift (append subst1* subst2*))))
				  (if subst
				      (cons subst s*)
				    s*))
				(merge-ae* ae* (<stx>-ae* sub-expr)))))))
	  ((symbol? sub-expr)
	   (syntax-violation #f
	     "raw symbol encountered in output of macro"
	     expr sub-expr))
	  (else
	   (make-<stx> sub-expr (list mark) subst1* ae*))))
  (mkstx (f expr mark '() '()) '() '() (list ae)))


;;;; deconstructors and predicates for syntax objects

(define (syntax-kind? x pred?)
  (cond ((<stx>? x)
	 (syntax-kind? (<stx>-expr x) pred?))
	((annotation? x)
	 (syntax-kind? (annotation-expression x) pred?))
	(else
	 (pred? x))))

(define (syntax-vector->list x)
  (cond ((<stx>? x)
	 (let ((ls (syntax-vector->list (<stx>-expr x)))
	       (m* (<stx>-mark* x))
	       (s* (<stx>-subst* x))
	       (ae* (<stx>-ae* x)))
	   (map (lambda (x)
		  (mkstx x m* s* ae*))
	     ls)))
	((annotation? x)
	 (syntax-vector->list (annotation-expression x)))
	((vector? x)
	 (vector->list x))
	(else
	 (assertion-violation 'syntax-vector->list "BUG: not a syntax vector" x))))

(define (syntax-pair? x)
  (syntax-kind? x pair?))

(define (syntax-vector? x)
  (syntax-kind? x vector?))

(define (syntax-null? x)
  (syntax-kind? x null?))

(define (syntax-list? x)
  ;;FIXME Should terminate on cyclic input.  (Abdulaziz Ghuloum)
  (or (syntax-null? x)
      (and (syntax-pair? x)
	   (syntax-list? (syntax-cdr x)))))

(define (syntax-car x)
  (cond ((<stx>? x)
	 (mkstx (syntax-car ($<stx>-expr x))
		($<stx>-mark*  x)
		($<stx>-subst* x)
		($<stx>-ae*    x)))
	((annotation? x)
	 (syntax-car (annotation-expression x)))
	((pair? x)
	 ($car x))
	(else
	 (assertion-violation 'syntax-car "BUG: not a pair" x))))

(define (syntax-cdr x)
  (cond ((<stx>? x)
	 (mkstx (syntax-cdr ($<stx>-expr x))
		($<stx>-mark*  x)
		($<stx>-subst* x)
		($<stx>-ae*    x)))
	((annotation? x)
	 (syntax-cdr (annotation-expression x)))
	((pair? x)
	 ($cdr x))
	(else
	 (assertion-violation 'syntax-cdr "BUG: not a pair" x))))

(define (syntax->list x)
  (cond ((syntax-pair? x)
	 (cons (syntax-car x)
	       (syntax->list (syntax-cdr x))))
	((syntax-null? x)
	 '())
	(else
	 (assertion-violation 'syntax->list "BUG: invalid argument" x))))

;;; --------------------------------------------------------------------

(define (identifier? x)
  ;;Return true if X is an  identifier: a syntax object whose expression
  ;;is a symbol.
  ;;
  (and (<stx>? x)
       (let ((expr ($<stx>-expr x)))
	 (symbol? (if (annotation? expr)
		      (annotation-stripped expr)
		    expr)))))

(define* (identifier->symbol x)
  ;;Given an identifier return its symbol expression.
  ;;
  (define (%error)
    (assertion-violation __who__
      "Vicare bug: expected identifier as argument" x))
  (unless (<stx>? x)
    (%error))
  (let* ((expr ($<stx>-expr x))
	 (sym  (if (annotation? expr)
		   (annotation-stripped expr)
		 expr)))
    (if (symbol? sym)
	sym
      (%error))))

(define (generate-temporaries list-stx)
  (syntax-match list-stx ()
    ((?item* ...)
     (map (lambda (x)
	    (make-<stx> (let ((x (syntax->datum x)))
			  (if (or (symbol? x)
				  (string? x))
			      (gensym x)
			    (gensym 't)))
			top-mark* '() '()))
       ?item*))
    (_
     (assertion-violation 'generate-temporaries
       "not a list" list-stx))))

(define (free-identifier=? x y)
  (if (identifier? x)
      (if (identifier? y)
	  (free-id=? x y)
	(assertion-violation 'free-identifier=? "not an identifier" y))
    (assertion-violation 'free-identifier=? "not an identifier" x)))

(define (bound-identifier=? x y)
  (if (identifier? x)
      (if (identifier? y)
	  (bound-id=? x y)
	(assertion-violation 'bound-identifier=? "not an identifier" y))
    (assertion-violation 'bound-identifier=? "not an identifier" x)))


;;;; utilities for identifiers

(define (bound-id=? id1 id2)
  ;;Two identifiers  are BOUND-ID=? if they  have the same name  and the
  ;;same set of marks.
  ;;
  (and (eq? (identifier->symbol id1) (identifier->symbol id2))
       (same-marks? ($<stx>-mark* id1) ($<stx>-mark* id2))))

(define (free-id=? id1 id2)
  ;;Two identifiers are  FREE-ID=? if either both are bound  to the same
  ;;label or if both are unbound and they have the same name.
  ;;
  (let ((t1 (id->label id1))
	(t2 (id->label id2)))
    (if (or t1 t2)
	(eq? t1 t2)
      (eq? (identifier->symbol id1) (identifier->symbol id2)))))

(define (valid-bound-ids? id*)
  ;;Given a list return #t if it  is made of identifers none of which is
  ;;BOUND-ID=? to another; else return #f.
  ;;
  ;;This function is called to validate  both list of LAMBDA formals and
  ;;list of LET binding identifiers.  The only guarantee about the input
  ;;is that it is a list.
  ;;
  (and (for-all identifier? id*)
       (distinct-bound-ids? id*)))

(define (distinct-bound-ids? id*)
  ;;Given a list of identifiers: return #t if none of the identifiers is
  ;;BOUND-ID=? to another; else return #f.
  ;;
  (or (null? id*)
      (and (not (bound-id-member? ($car id*) ($cdr id*)))
	   (distinct-bound-ids? ($cdr id*)))))

(define (bound-id-member? id id*)
  ;;Given an identifier  ID and a list of identifiers  ID*: return #t if
  ;;ID is BOUND-ID=? to one of the identifiers in ID*; else return #f.
  ;;
  (and (pair? id*)
       (or (bound-id=? id ($car id*))
	   (bound-id-member? id ($cdr id*)))))


(define (self-evaluating? x)
  (or (number?		x)
      (string?		x)
      (char?		x)
      (boolean?		x)
      (bytevector?	x)
      (keyword?		x)
      (would-block-object? x)))

(module (strip)
  ;;STRIP is used  to remove the wrap  of a syntax object.   It takes an
  ;;stx's expr  and marks.  If  the marks  contain a top-mark,  then the
  ;;expr is returned.
  ;;
  (define (strip x m*)
    (if (top-marked? m*)
	(if (or (annotation? x)
		(and (pair? x)
		     (annotation? ($car x)))
		(and (vector? x)
		     (> ($vector-length x) 0)
		     (annotation? ($vector-ref x 0))))
	    ;;TODO Ask Kent  why this is a  sufficient test.  (Abdulaziz
	    ;;Ghuloum)
	    (strip-annotations x)
	  x)
      (let f ((x x))
	(cond ((<stx>? x)
	       (strip ($<stx>-expr x) ($<stx>-mark* x)))
	      ((annotation? x)
	       (annotation-stripped x))
	      ((pair? x)
	       (let ((a (f ($car x)))
		     (d (f ($cdr x))))
		 (if (and (eq? a ($car x))
			  (eq? d ($cdr x)))
		     x
		   (cons a d))))
	      ((vector? x)
	       (let* ((old (vector->list x))
		      (new (map f old)))
		 (if (for-all eq? old new)
		     x
		   (list->vector new))))
	      (else x)))))

  (define (strip-annotations x)
    (cond ((pair? x)
	   (cons (strip-annotations ($car x))
		 (strip-annotations ($cdr x))))
	  ((vector? x)
	   (vector-map strip-annotations x))
	  ((annotation? x)
	   (annotation-stripped x))
	  (else x)))

  #| end of module: STRIP |# )


;;;; identifiers and labels

(module (id->label)

  (define (id->label id)
    ;;Given the identifier  ID search its substs for  a label associated
    ;;with the same sym and marks.  If found return the symbol being the
    ;;label, else return false.
    ;;
    (let ((sym (identifier->symbol id)))
      (let search ((subst* ($<stx>-subst* id))
		   (mark*  ($<stx>-mark*  id)))
	(cond ((null? subst*)
	       #f)
	      ((eq? ($car subst*) 'shift)
	       ;;A shift is inserted when a  mark is added.  So, we search
	       ;;the rest of the substitution without the mark.
	       (search ($cdr subst*) ($cdr mark*)))
	      (else
	       (let ((rib ($car subst*)))
		 (define (next-search)
		   (search ($cdr subst*) mark*))
		 (if ($<rib>-sealed/freq rib)
		     (%search-in-sealed-rib rib sym mark* next-search)
		   (%search-in-rib rib sym mark* next-search))))))))

  (define-inline (%search-in-sealed-rib rib sym mark* next-search)
    (define sym* ($<rib>-sym* rib))
    (let loop ((i       0)
	       (rib.len ($vector-length sym*)))
      (cond (($fx= i rib.len)
	     (next-search))
	    ((and (eq? ($vector-ref sym* i) sym)
		  (same-marks? mark* ($vector-ref ($<rib>-mark** rib) i)))
	     (let ((label ($vector-ref ($<rib>-label* rib) i)))
	       (increment-rib-frequency! rib i)
	       label))
	    (else
	     (loop ($fxadd1 i) rib.len)))))

  (define-inline (%search-in-rib rib sym mark* next-search)
    (let loop ((sym*    ($<rib>-sym*   rib))
	       (mark**  ($<rib>-mark** rib))
	       (label*  ($<rib>-label* rib)))
      (cond ((null? sym*)
	     (next-search))
	    ((and (eq? ($car sym*) sym)
		  (same-marks? ($car mark**) mark*))
	     ($car label*))
	    (else
	     (loop ($cdr sym*) ($cdr mark**) ($cdr label*))))))

  #| end of module: ID->LABEL |# )

(define (id->label/intern id)
  (or (id->label id)
      (cond ((top-level-context)
	     => (lambda (env)
		  ;;Fabricate binding.
		  (let ((rib (interaction-env-rib env)))
		    (receive (lab _loc)
			(gen-define-label+loc id rib #f)
		      ;;FIXME (Abdulaziz Ghuloum)
		      (extend-rib! rib id lab #t)
		      lab))))
	    (else #f))))


;;;; public interface: variable transformer
;;
;;As  specified  by  R6RS:  we   can  define  identifier  syntaxes  with
;;IDENTIFIER-SYNTAX  and with  MAKE-VARIABLE-TRANSFORMER; both  of these
;;return  a "special"  value that,  when used  as right-hand  side of  a
;;syntax  definition,  is  recognised  by the  expander  as  a  variable
;;transformer  as opposed  to  a normal  transformer  or a  compile-time
;;value.
;;
;;Let's say we define an identifier syntax with:
;;
;;   (define-syntax ?kwd ?expression)
;;
;;where ?EXPRESSION is:
;;
;;   (identifier-syntax ?stuff)
;;
;;here is what happen:
;;
;;1..The DEFINE-SYNTAX form is expanded and a syntax object is created:
;;
;;      (syntax ?expression)
;;
;;2..The syntax object is  expanded by %EXPAND-MACRO-TRANSFORMER and the
;;   result is a core language sexp representing the transformer.
;;
;;3..The   sexp   is   compiled    and   evaluated   by   the   function
;;   %EVAL-MACRO-TRANSFORMER.   The  result  of   the  evaluation  is  a
;;   "special value" with format:
;;
;;      (identifier-macro! . ?transformer)
;;
;;   where ?TRANSFORMER is a transformer function.
;;
;;4..%EVAL-MACRO-TRANSFORMER  recognises  the  value  as  special  using
;;   VARIABLE-TRANSFORMER?  and   transforms  it  to   a  "local-macro!"
;;   syntactic binding.
;;

(define* (make-variable-transformer x)
  ;;R6RS's  make-variable-transformer.   Build  and return  a  "special"
  ;;value that, when used as right-hand  side of a syntax definition, is
  ;;recognised by the expander as a variable transformer as opposed to a
  ;;normal transformer or a compile-time value.
  ;;
  (if (procedure? x)
      (cons 'identifier-macro! x)
    (assertion-violation __who__ "not a procedure" x)))

(define (variable-transformer? x)
  ;;Return  true if  X  is  recognised by  the  expander  as a  variable
  ;;transformer as  opposed to  a normal  transformer or  a compile-time
  ;;value; otherwise return false.
  ;;
  (and (pair? x)
       (eq? (car x) 'identifier-macro!)
       (procedure? (cdr x))))

(define* (variable-transformer-procedure x)
  ;;If X is recognised by the expander as a variable transformer: return
  ;;the  actual  transformer  function,  otherwise  raise  an  assertion
  ;;violation.
  ;;
  (if (variable-transformer? x)
      (cdr x)
    (assertion-violation __who__ "not a variable transformer" x)))


;;;; public interface: compile-time values
;;
;;Compile-time values are objects computed  at expand-time and stored in
;;the lexical environment.  We can  define a compile-time value and push
;;it on the lexical environment with:
;;
;;   (define-syntax it
;;     (make-compile-time-value (+ 1 2)))
;;
;;later  we can  retrieve it  by  defining a  transformer function  that
;;returns a function:
;;
;;   (define-syntax get-it
;;     (lambda (stx)
;;       (lambda (ctv-retriever)
;;         (ctv-retriever #'it) => 3
;;         )))
;;
;;Let's say we define a compile-time value with:
;;
;;   (define-syntax ?kwd ?expression)
;;
;;where ?EXPRESSION is:
;;
;;   (make-compile-time-value ?stuff)
;;
;;here is what happen:
;;
;;1..The DEFINE-SYNTAX form is expanded and a syntax object is created:
;;
;;      (syntax ?expression)
;;
;;2..The syntax object is  expanded by %EXPAND-MACRO-TRANSFORMER and the
;;   result is a core language sexp representing the right-hand side.
;;
;;3..The   sexp   is   compiled    and   evaluated   by   the   function
;;   %EVAL-MACRO-TRANSFORMER.   The  result  of   the  evaluation  is  a
;;   "special value" with format:
;;
;;      (ctv! . ?obj)
;;
;;   where ?OBJ is the actual compile-time value.
;;
;;4..%EVAL-MACRO-TRANSFORMER  recognises  the  value  as  special  using
;;   COMPILE-TIME-VALUE?  and  transforms it to a  "local-ctv" syntactic
;;   binding.
;;

(define (make-compile-time-value obj)
  (cons 'ctv obj))

(define (compile-time-value? obj)
  (and (pair? obj)
       (eq? 'ctv (car obj))))

(define compile-time-value-object
  ;;Given  a compile-time  value datum:  return the  actual compile-time
  ;;object.
  ;;
  cdr)


(define-syntax syntax-match
  ;;The SYNTAX-MATCH macro is almost like SYNTAX-CASE macro.  Except that:
  ;;
  ;;*  The syntax  objects matched  are OUR  stx objects,  not the  host
  ;;  systems syntax objects (whatever they may be we don't care).
  ;;
  ;;*  The literals  are matched  against  those in  the system  library
  ;;  (psyntax system $all).  -- see scheme-stx
  ;;
  ;;* The variables  in the patters are bound to  ordinary variables not
  ;;  to special pattern variables.
  ;;
  ;;The actual matching between the input expression and the patterns is
  ;;performed  by   the  function   SYNTAX-DISPATCH;  the   patterns  in
  ;;SYNTAX-MATCH are converted to a  sexps and handed to SYNTAX-DISPATCH
  ;;along with the input expression.
  ;;
  (let ()
    (define (transformer stx)
      (syntax-case stx ()

	;;No  clauses.  Some  of  the  SYNTAX-MATCH clauses  recursively
	;;expand  to uses  of  SYNTAX-MATCH; when  no  more clauses  are
	;;available in the input  form, this SYNTAX-CASE clause matches.
	;;When this happens: we want to raise a syntax error.
	;;
	;;Notice that we  do not want to raise a  syntax error here, but
	;;in the expanded code.
	((_ ?expr (?literals ...))
	 (for-all sys.identifier? (syntax (?literals ...)))
	 (syntax (syntax-violation #f "invalid syntax" ?expr)))

	;;The next clause has a fender.
	((_ ?expr (?literals ...) (?pattern ?fender ?body) ?clause* ...)
	 (for-all sys.identifier? (syntax (?literals ...)))
	 (receive (pattern ptnvars/levels)
	     (%convert-single-pattern (syntax ?pattern) (syntax (?literals ...)))
	   (with-syntax
	       ((PATTERN                   (sys.datum->syntax (syntax here) pattern))
		(((PTNVARS . LEVELS) ...)  ptnvars/levels))
	     (syntax
	      (let ((T ?expr))
		;;If   the  input   expression   matches  the   symbolic
		;;expression PATTERN...
		(let ((ls/false (syntax-dispatch T 'PATTERN)))
		  (if (and ls/false
			   ;;...and  the pattern  variables satisfy  the
			   ;;fender...
			   (apply (lambda (PTNVARS ...) ?fender) ls/false))
		      ;;...evaluate the body  with the pattern variables
		      ;;assigned.
		      (apply (lambda (PTNVARS ...) ?body) ls/false)
		    ;;...else try to match the next clause.
		    (syntax-match T (?literals ...) ?clause* ...))))))))

	;;The next clause has NO fender.
	((_ ?expr (?literals ...) (?pattern ?body) clause* ...)
	 (for-all sys.identifier? (syntax (?literals ...)))
	 (receive (pattern ptnvars/levels)
	     (%convert-single-pattern (syntax ?pattern) (syntax (?literals ...)))
	   (with-syntax
	       ((PATTERN                   (sys.datum->syntax (syntax here) pattern))
		(((PTNVARS . LEVELS) ...)  ptnvars/levels))
	     (syntax
	      (let ((T ?expr))
		;;If   the  input   expression   matches  the   symbolic
		;;expression PATTERN...
		(let ((ls/false (syntax-dispatch T 'PATTERN)))
		  (if ls/false
		      ;;...evaluate the body  with the pattern variables
		      ;;assigned.
		      (apply (lambda (PTNVARS ...) ?body) ls/false)
		    ;;...else try to match the next clause.
		    (syntax-match T (?literals ...) clause* ...))))))))

	;;This is a true error in he use of SYNTAX-MATCH.  We still want
	;;the  expanded  code  to  raise  the  violation.   Notice  that
	;;SYNTAX-VIOLATION  is not  bound in  the expand  environment of
	;;SYNTAX-MATCH's transformer.
	;;
	(?stuff
	 (syntax (syntax-violation #f "invalid syntax" stx)))
	))

    (module (%convert-single-pattern)

      (case-define %convert-single-pattern
	;;Recursive function.  Transform the PATTERN-STX into a symbolic
	;;expression to be handed  to SYNTAX-DISPATCH.  PATTERN-STX must
	;;be  a  syntax  object  holding  the  SYNTAX-MATCH  pattern  to
	;;convert.  LITERALS must  be a syntax object holding  a list of
	;;identifiers being the literals in the PATTERN-STX.
	;;
	;;Return 2 values:
	;;
	;;1. The pattern as sexp.
	;;
	;;2.   An ordered  list of  pairs, each  representing a  pattern
	;;   variable that must be bound whenever the body associated to
	;;   the  pattern is  evaluated.  The  car of  each pair  is the
	;;   symbol  being the pattern  variable name.  The cdr  of each
	;;   pair is an exact  integer representing the nesting level of
	;;   the pattern variable.
	;;
	((pattern-stx literals)
	 (%convert-single-pattern pattern-stx literals 0 '()))

	((pattern-stx literals nesting-level pattern-vars)
	 (syntax-case pattern-stx ()

	   ;;A literal identifier is encoded as:
	   ;;
	   ;;   #(scheme-id ?identifier)
	   ;;
	   ;;the wildcard underscore identifier is encoded as:
	   ;;
	   ;;   _
	   ;;
	   ;;any other identifier will bind a variable and it is encoded
	   ;;as:
	   ;;
	   ;;   any
	   ;;
	   (?identifier
	    (sys.identifier? (syntax ?identifier))
	    (cond ((%bound-identifier-member? pattern-stx literals)
		   (values `#(scheme-id ,(sys.syntax->datum pattern-stx)) pattern-vars))
		  ((sys.free-identifier=? pattern-stx (syntax _))
		   (values '_ pattern-vars))
		  (else
		   (values 'any (cons (cons pattern-stx nesting-level)
				      pattern-vars)))))

	   ;;A  tail  pattern  with  ellipsis which  does  not  bind  a
	   ;;variable is encoded as:
	   ;;
	   ;;   #(each ?pattern)
	   ;;
	   ;;a tail pattern with ellipsis which does bind a variable is
	   ;;encoded as:
	   ;;
	   ;;   each-any
	   ;;
	   ((?pattern ?dots)
	    (%ellipsis? (syntax ?dots))
	    (receive (pattern^ pattern-vars^)
		(%convert-single-pattern (syntax ?pattern) literals
					 (+ nesting-level 1) pattern-vars)
	      (values (if (eq? pattern^ 'any)
			  'each-any
			`#(each ,pattern^))
		      pattern-vars^)))

	   ;;A non-tail pattern with ellipsis is encoded as:
	   ;;
	   ;;  #(each+ ?pattern-ellipsis (?pattern-following ...) . ?tail-pattern)
	   ;;
	   ((?pattern-x ?dots ?pattern-y ... . ?pattern-z)
	    (%ellipsis? (syntax ?dots))
	    (let*-values
		(((pattern-z pattern-vars)
		  (%convert-single-pattern (syntax ?pattern-z) literals
					   nesting-level pattern-vars))

		 ((pattern-y* pattern-vars)
		  (%convert-multi-pattern  (syntax (?pattern-y ...)) literals
					   nesting-level pattern-vars))

		 ((pattern-x pattern-vars)
		  (%convert-single-pattern (syntax ?pattern-x) literals
					   (+ nesting-level 1) pattern-vars)))
	      (values `#(each+ ,pattern-x ,(reverse pattern-y*) ,pattern-z)
		      pattern-vars)))

	   ;;A pair is encoded as pair.
	   ;;
	   ((?car . ?cdr)
	    (let*-values
		(((pattern-cdr pattern-vars)
		  (%convert-single-pattern (syntax ?cdr) literals
					   nesting-level pattern-vars))

		 ((pattern-car pattern-vars)
		  (%convert-single-pattern (syntax ?car) literals
					   nesting-level pattern-vars)))
	      (values (cons pattern-car pattern-cdr) pattern-vars)))

	   ;;Null is encoded as null.
	   ;;
	   (()
	    (values '() pattern-vars))

	   ;;A vector is encoded as:
	   ;;
	   ;;   #(vector ?datum)
	   ;;
	   (#(?item ...)
	    (receive (pattern-item* pattern-vars)
		(%convert-single-pattern (syntax (?item ...)) literals
					 nesting-level pattern-vars)
	      (values `#(vector ,pattern-item*) pattern-vars)))

	   ;;A datum is encoded as:
	   ;;
	   ;;   #(atom ?datum)
	   ;;
	   (?datum
	    (values `#(atom ,(sys.syntax->datum (syntax ?datum))) pattern-vars))
	   )))

      (define (%convert-multi-pattern pattern* literals nesting-level pattern-vars)
	;;Recursive function.
	;;
	(if (null? pattern*)
	    (values '() pattern-vars)
	  (let*-values
	      (((y pattern-vars^)
		(%convert-multi-pattern  (cdr pattern*) literals nesting-level pattern-vars))
	       ((x pattern-vars^^)
		(%convert-single-pattern (car pattern*) literals nesting-level pattern-vars^)))
	    (values (cons x y) pattern-vars^^))))

      (define (%bound-identifier-member? id list-of-ids)
	;;Return #t if  the identifier ID is  BOUND-IDENTIFIER=?  to one
	;;of the identifiers in LIST-OF-IDS.
	;;
	(and (pair? list-of-ids)
	     (or (sys.bound-identifier=? id (car list-of-ids))
		 (%bound-identifier-member? id (cdr list-of-ids)))))

      (define (%ellipsis? x)
	(and (sys.identifier? x)
	     (sys.free-identifier=? x (syntax (... ...)))))

      ;;Commented out because unused.  (Marco Maggi; Thu Apr 25, 2013)
      ;;
      ;; (define (%free-identifier-member? id1 list-of-ids)
      ;;   ;;Return #t if  the identifier ID1 is  FREE-IDENTIFIER=?  to one
      ;;   ;;of the identifiers in LIST-OF-IDS.
      ;;   ;;
      ;;   (and (exists (lambda (id2)
      ;; 		     (sys.free-identifier=? id1 id2))
      ;; 	     list-of-ids)
      ;; 	   #t))

      #| end of module: %CONVERT-SINGLE-PATTERN |# )

    transformer))


(define scheme-stx
  ;;Take a symbol  and if it's in the library:
  ;;
  ;;   (psyntax system $all)
  ;;
  ;;create a fresh identifier that maps  only the symbol to its label in
  ;;that library.  Symbols not in that library become fresh.
  ;;
  (let ((scheme-stx-hashtable (make-eq-hashtable)))
    (lambda (sym)
      (or (hashtable-ref scheme-stx-hashtable sym #f)
	  (let* ((subst  (library-subst (find-library-by-name '(psyntax system $all))))
		 (stx    (make-<stx> sym top-mark* '() '()))
		 (stx    (cond ((assq sym subst)
				=> (lambda (subst.entry)
				     (let ((name  (car subst.entry))
					   (label (cdr subst.entry)))
				       (push-lexical-contour
					(make-<rib> (list name)
						    (list top-mark*)
						    (list label)
						    #f)
					stx))))
			       (else stx))))
	    (hashtable-set! scheme-stx-hashtable sym stx)
	    stx)))))


(module NON-CORE-MACRO-TRANSFORMER
  (non-core-macro-transformer)
  ;;We distinguish between "non-core macros" and "core macros".
  ;;
  ;;Core macros  are part of the  core language: they cannot  be further
  ;;expanded to a  composition of other more basic  macros.  Core macros
  ;;*do*  introduce bindings,  so their  transformer functions  take the
  ;;lexical environments as arguments.
  ;;
  ;;Non-core macros are  *not* part of the core language:  they *can* be
  ;;expanded to  a composition of  core macros.  Non-core macros  do not
  ;;introduce bindings, so their transformer functions do *not* take the
  ;;lexical environments as arguments.
  ;;
  ;;The  function NON-CORE-MACRO-TRANSFORMER  maps symbols  representing
  ;;non-core  macros  to  their   macro  transformers.   The  expression
  ;;returned by a non-core transformer is further visited to process the
  ;;core macros and introduce bindings.
  ;;
  ;;NOTE This  module is very  long, so it  is split into  multiple code
  ;;pages.  (Marco Maggi; Sat Apr 27, 2013)
  ;;
  (define* (non-core-macro-transformer x)
    (define (%error-invalid-macro)
      (error __who__ "Vicare: internal error: invalid macro" x))
    (assert (symbol? x))
    (case x
      ((define-record-type)		define-record-type-macro)
      ((record-type-and-record?)	record-type-and-record?-macro)
      ((define-struct)			define-struct-macro)
      ((define-condition-type)		define-condition-type-macro)
      ((cond)				cond-macro)
      ((let)				let-macro)
      ((do)				do-macro)
      ((or)				or-macro)
      ((and)				and-macro)
      ((let*)				let*-macro)
      ((let-values)			let-values-macro)
      ((let*-values)			let*-values-macro)
      ((values->list)			values->list-macro)
      ((syntax-rules)			syntax-rules-macro)
      ((quasiquote)			quasiquote-macro)
      ((quasisyntax)			quasisyntax-macro)
      ((with-syntax)			with-syntax-macro)
      ((when)				when-macro)
      ((unless)				unless-macro)
      ((case)				case-macro)
      ((identifier-syntax)		identifier-syntax-macro)
      ((time)				time-macro)
      ((delay)				delay-macro)
      ((assert)				assert-macro)
      ((guard)				guard-macro)
      ((define-enumeration)		define-enumeration-macro)
      ((let*-syntax)			let*-syntax-macro)
      ((let-constants)			let-constants-macro)
      ((let*-constants)			let*-constants-macro)
      ((letrec-constants)		letrec-constants-macro)
      ((letrec*-constants)		letrec*-constants-macro)
      ((case-define)			case-define-macro)
      ((define*)			define*-macro)
      ((case-define*)			case-define*-macro)
      ((lambda*)			lambda*-macro)
      ((case-lambda*)			case-lambda*-macro)

      ((trace-lambda)			trace-lambda-macro)
      ((trace-define)			trace-define-macro)
      ((trace-let)			trace-let-macro)
      ((trace-define-syntax)		trace-define-syntax-macro)
      ((trace-let-syntax)		trace-let-syntax-macro)
      ((trace-letrec-syntax)		trace-letrec-syntax-macro)

      ((include)			include-macro)
      ((define-integrable)		define-integrable-macro)
      ((define-inline)			define-inline-macro)
      ((define-constant)		define-constant-macro)
      ((define-inline-constant)		define-inline-constant-macro)
      ((define-values)			define-values-macro)
      ((define-constant-values)		define-constant-values-macro)
      ((receive)			receive-macro)
      ((receive-and-return)		receive-and-return-macro)
      ((begin0)				begin0-macro)
      ((xor)				xor-macro)
      ((define-syntax-rule)		define-syntax-rule-macro)
      ((define-auxiliary-syntaxes)	define-auxiliary-syntaxes-macro)
      ((define-syntax*)			define-syntax*-macro)
      ((unwind-protect)			unwind-protect-macro)
      ((with-implicits)			with-implicits-macro)
      ((set-cons!)			set-cons!-macro)

      ((eval-for-expand)		eval-for-expand-macro)

      ;; non-Scheme style syntaxes
      ((return)				return-macro)
      ((continue)			continue-macro)
      ((break)				break-macro)
      ((while)				while-macro)
      ((until)				until-macro)
      ((for)				for-macro)
      ((define-returnable)		define-returnable-macro)
      ((lambda-returnable)		lambda-returnable-macro)
      ((begin-returnable)		begin-returnable-macro)

      ((parameterize)			parameterize-macro)
      ((parametrise)			parameterize-macro)

      ;; compensations
      ((with-compensations)		with-compensations-macro)
      ((with-compensations/on-error)	with-compensations/on-error-macro)
      ((compensate)			compensate-macro)
      ((with)				with-macro)
      ((push-compensation)		push-compensation-macro)

      ((eol-style)
       (lambda (x)
	 (%allowed-symbol-macro x '(none lf cr crlf nel crnel ls))))

      ((error-handling-mode)
       (lambda (x)
	 (%allowed-symbol-macro x '(ignore raise replace))))

      ((buffer-mode)
       (lambda (x)
	 (%allowed-symbol-macro x '(none line block))))

      ((endianness)
       endianness-macro)

      ((file-options)
       file-options-macro)

      ((... => _ else unquote unquote-splicing
	    unsyntax unsyntax-splicing
	    fields mutable immutable parent protocol
	    sealed opaque nongenerative parent-rtd)
       (lambda (expr-stx)
	 (syntax-violation #f "incorrect usage of auxiliary keyword" expr-stx)))

      (else
       (%error-invalid-macro))))


;;;; module non-core-macro-transformer: DEFINE-AUXILIARY-SYNTAXES

(define (define-auxiliary-syntaxes-macro expr-stx)
  ;;Transformer      function      used     to      expand      Vicare's
  ;;DEFINE-AUXILIARY-SYNTAXES  macros   from  the  top-level   built  in
  ;;environment.  Expand  the contents  of EXPR-STX.  Return  a symbolic
  ;;expression in the core language.
  ;;
  ;;Using an empty SYNTAX-RULES as  transformer function makes sure that
  ;;whenever an auxiliary syntax is referenced an error is raised.
  ;;
  (syntax-match expr-stx ()
    ((_ ?id* ...)
     (for-all identifier? ?id*)
     (bless
      `(begin
	 ,@(map (lambda (id)
		  `(define-syntax ,id (syntax-rules ())))
	     ?id*))))))


;;;; module non-core-macro-transformer: control structures macros

(define (when-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?test ?expr ?expr* ...)
     (bless `(if ,?test (begin ,?expr . ,?expr*))))))

(define (unless-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?test ?expr ?expr* ...)
     (bless `(if (not ,?test) (begin ,?expr . ,?expr*))))))


;;;; module non-core-macro-transformer: CASE

(module (case-macro)
  ;;Transformer  function used  to expand  R6RS's CASE  macros from  the
  ;;top-level built  in environment.   Expand the contents  of EXPR-STX.
  ;;Return a sexp in the core language.
  ;;
  (define (case-macro expr-stx)
    (syntax-match expr-stx ()
      ((_ ?expr)
       (bless `(let ((t ,?expr))
		 (if #f #f))))
      ((_ ?expr ?clause ?clause* ...)
       (bless
	`(let ((t ,?expr))
	   ,(let recur ((clause  ?clause)
			(clause* ?clause*))
	      (if (null? clause*)
		  (%build-last clause)
		(%build-one clause (recur (car clause*) (cdr clause*))))))))))

  (define (%build-one clause-stx k)
    (syntax-match clause-stx (=>)
      (((?datum* ...) => ?expr)
       (if (strict-r6rs)
	   (syntax-violation 'case
	     "invalid usage of auxiliary keyword => in strict R6RS mode"
	     clause-stx)
	 `(if (memv t ',?datum*)
	      (,?expr t)
	    ,k)))
      (((?datum* ...) ?expr ?expr* ...)
       `(if (memv t ',?datum*)
	    (begin ,?expr . ,?expr*)
	  ,k))
      ))

  (define (%build-last clause)
    (syntax-match clause (else)
      ((else ?expr ?expr* ...)
       `(let () #f ,?expr . ,?expr*))
      (_
       (%build-one clause '(if #f #f)))))

  #| end of module: CASE-MACRO |# )


;;;; module non-core-macro-transformer: DEFINE-RECORD-TYPE

(define (define-record-type-macro x)
  (define-constant __who__ 'define-record-type)

  (define (main stx)
    (syntax-match stx ()
      ((_ namespec clause* ...)
       (begin
	 (%verify-clauses x clause*)
	 (%do-define-record namespec clause*)))
      ))

;;; --------------------------------------------------------------------

  (define (%do-define-record namespec clause*)
    (define foo		(%get-record-name namespec))
    (define foo-rtd	(gensym))
    (define foo-rcd	(gensym))
    (define protocol	(gensym))
    (define make-foo	(%get-record-constructor-name namespec))
    (define fields	(%get-fields clause*))
    (define field-names
      (%get-field-names fields))
    (define mutable-field-names
      (%get-mutable-field-names fields))
    ;;Indexes for safe accessors and mutators.
    (define idx*	(%enumerate fields))
    (define set-foo-idx*
      (%get-mutator-indices fields))
    ;;Names of safe accessors and mutators.
    (define foo-x*
      (%get-accessors foo fields))
    (define set-foo-x!*
      (%get-mutators foo fields))
    ;;Names of unsafe accessors and mutators.
    (define unsafe-foo-x*
      (%get-unsafe-accessors foo fields))
    (define unsafe-set-foo-x!*
      (%get-unsafe-mutators foo fields))
    ;;Names for unsafe index bindings.
    (define unsafe-foo-x-idx*
      (%get-unsafe-accessors-idx-names foo fields))
    (define unsafe-set-foo-x!-idx*
      (%get-unsafe-mutators-idx-names foo fields))

    ;;Safe field accessors and mutators alists.
    (define foo-fields-safe-accessors-table
      ;;Here we want to build a sexp  which will be BLESSed below in the
      ;;output code.  The sexp will  evluate to an alist, having symbols
      ;;representing field  names as  keys and  an identifiers  bound to
      ;;unsafe accessors as values.
      (map (lambda (name func)
	     (list 'quasiquote (cons name (list 'unquote (list 'syntax func)))))
	(map syntax->datum field-names)
	foo-x*))
    (define foo-fields-safe-mutators-table
      ;;Here we want to build a sexp  which will be BLESSed below in the
      ;;output code.  The sexp will  evluate to an alist, having symbols
      ;;representing field  names as  keys and  an identifiers  bound to
      ;;unsafe mutators as values.
      (map (lambda (name func)
	     (list 'quasiquote (cons name (list 'unquote (list 'syntax func)))))
	(map syntax->datum mutable-field-names)
	set-foo-x!*))

    ;;Unsafe field accessors and mutators alists.
    (define foo-fields-unsafe-accessors-table
      ;;Here we want to build a sexp  which will be BLESSed below in the
      ;;output code.  The sexp will  evluate to an alist, having symbols
      ;;representing field  names as  keys and  an identifiers  bound to
      ;;unsafe accessors as values.
      (map (lambda (name func)
	     (list 'quasiquote (cons name (list 'unquote (list 'syntax func)))))
	(map syntax->datum field-names)
	unsafe-foo-x*))
    (define foo-fields-unsafe-mutators-table
      ;;Here we want to build a sexp  which will be BLESSed below in the
      ;;output code.  The sexp will  evluate to an alist, having symbols
      ;;representing field  names as  keys and  an identifiers  bound to
      ;;unsafe mutators as values.
      (map (lambda (name func)
	     (list 'quasiquote (cons name (list 'unquote (list 'syntax func)))))
	(map syntax->datum mutable-field-names)
	unsafe-set-foo-x!*))

    ;;Predicate name.
    (define foo?
      (%get-record-predicate-name namespec))
    ;;Code  for  record-type   descriptor  and  record-type  constructor
    ;;descriptor.
    (define foo-rtd-code
      (%make-rtd-code foo clause* (%make-parent-rtd-code clause*)))
    (define foo-rcd-code
      (%make-rcd-code clause* foo-rtd protocol (%make-parent-rcd-code clause*)))
    ;;Code for protocol.
    (define protocol-code
      (%get-protocol-code clause*))
    (define r6rs-output-code
      `(begin
	 ;;Record type descriptor.
	 (define ,foo-rtd ,foo-rtd-code)
	 ;;Protocol function.
	 (define ,protocol ,protocol-code)
	 ;;Record constructor descriptor.
	 (define ,foo-rcd ,foo-rcd-code)
	 ;;Record instance predicate.
	 (define ,foo? (record-predicate ,foo-rtd))
	 ;;Record instance constructor.
	 (define ,make-foo (record-constructor ,foo-rcd))
	 ;;Safe record fields accessors.
	 ,@(map (lambda (foo-x idx)
		  `(define ,foo-x (record-accessor ,foo-rtd ,idx)))
	     foo-x* idx*)
	 ;;Safe record fields mutators (if any).
	 ,@(map (lambda (set-foo-x! idx)
		  `(define ,set-foo-x! (record-mutator ,foo-rtd ,idx)))
	     set-foo-x!* set-foo-idx*)))
    (define vicare-output-code
      (if (strict-r6rs)
	  `( ;;Binding for record type name.   It is a spcial binding in
	     ;;the environment.
	    (define-syntax ,foo
	      (list '$rtd (syntax ,foo-rtd) (syntax ,foo-rcd)
		    (list ,@foo-fields-safe-accessors-table)
		    (list ,@foo-fields-safe-mutators-table))))
	`( ;;Binding  for record type name.   It is a spcial  binding in
	   ;;the environment.
	  (define-syntax ,foo
	    (list '$rtd (syntax ,foo-rtd) (syntax ,foo-rcd)
		  (list ,@foo-fields-safe-accessors-table)
		  (list ,@foo-fields-safe-mutators-table)
		  (list ,@foo-fields-unsafe-accessors-table)
		  (list ,@foo-fields-unsafe-mutators-table)))
	  ;; Unsafe record fields accessors.
	  ,@(map (lambda (unsafe-foo-x idx unsafe-foo-x-idx)
		   `(begin
		      (define ,unsafe-foo-x-idx
			;;The field at index 3  in the RTD is: the index
			;;of  the first  field  of this  subtype in  the
			;;layout of instances; it is the total number of
			;;fields of the parent type.
			(fx+ ,idx ($struct-ref ,foo-rtd 3)))
		      (define-syntax-rule (,unsafe-foo-x x)
			($struct-ref x ,unsafe-foo-x-idx))
		      ))
	      unsafe-foo-x* idx* unsafe-foo-x-idx*)
	  ;; Unsafe record fields mutators.
	  ,@(map (lambda (unsafe-set-foo-x! idx unsafe-set-foo-x!-idx)
		   `(begin
		      (define ,unsafe-set-foo-x!-idx
			;;The field at index 3  in the RTD is: the index
			;;of  the first  field  of this  subtype in  the
			;;layout of instances; it is the total number of
			;;fields of the parent type.
			(fx+ ,idx ($struct-ref ,foo-rtd 3)))
		      (define-syntax-rule (,unsafe-set-foo-x! x v)
			($struct-set! x ,unsafe-set-foo-x!-idx v))
		      ))
	      unsafe-set-foo-x!* set-foo-idx* unsafe-set-foo-x!-idx*)
	  )))
    (bless (append r6rs-output-code vicare-output-code)))

;;; --------------------------------------------------------------------

  (define (%get-record-name spec)
    (syntax-match spec ()
      ((foo make-foo foo?) foo)
      (foo foo)))

  (define (%get-record-constructor-name spec)
    (syntax-match spec ()
      ((foo make-foo foo?) make-foo)
      (foo (identifier? foo) (id foo "make-" (syntax->datum foo)))))

  (define (%get-record-predicate-name spec)
    (syntax-match spec ()
      ((foo make-foo foo?)
       foo?)
      (foo
       (identifier? foo)
       (id foo foo "?"))))

  (define (get-clause id ls)
    (syntax-match ls ()
      (()
       #f)
      (((x . rest) . ls)
       (if (free-id=? (bless id) x)
	   `(,x . ,rest)
	 (get-clause id ls)))))

  (define (%make-rtd-code name clause* parent-rtd-code)
    (define (convert-field-spec* ls)
      (list->vector
       (map (lambda (x)
	      (syntax-match x (mutable immutable)
		((mutable name . rest) `(mutable ,name))
		((immutable name . rest) `(immutable ,name))
		(name `(immutable ,name))))
	 ls)))
    (let ((uid-code
	   (syntax-match (get-clause 'nongenerative clause*) ()
	     ((_)     `',(gensym))
	     ((_ uid) `',uid)
	     (_       #f)))
	  (sealed?
	   (syntax-match (get-clause 'sealed clause*) ()
	     ((_ #t) #t)
	     (_      #f)))
	  (opaque?
	   (syntax-match (get-clause 'opaque clause*) ()
	     ((_ #t) #t)
	     (_      #f)))
	  (fields
	   (syntax-match (get-clause 'fields clause*) ()
	     ((_ field-spec* ...)
	      `(quote ,(convert-field-spec* field-spec*)))
	     (_ ''#()))))
      (bless
       `(make-record-type-descriptor ',name
				     ,parent-rtd-code
				     ,uid-code ,sealed? ,opaque? ,fields))))

  (define (%make-parent-rtd-code clause*)
    (syntax-match (get-clause 'parent clause*) ()
      ;;If there is  a PARENT clause insert code that  retrieves the RTD
      ;;from the parent type name.
      ((_ name)
       `(record-type-descriptor ,name))

      ;;If  there is  no PARENT  clause try  to retrieve  the expression
      ;;evaluating to the RTD.
      (#f
       (syntax-match (get-clause 'parent-rtd clause*) ()
	 ((_ rtd rcd)
	  rtd)
	 ;;If neither the PARENT nor the PARENT-RTD clauses are present:
	 ;;just return false.
	 (#f #f)))
      ))

  (define (%make-parent-rcd-code clause*)
    (syntax-match (get-clause 'parent clause*) ()
      ;;If there is  a PARENT clause insert code that  retrieves the RCD
      ;;from the parent type name.
      ((_ name)
       `(record-constructor-descriptor ,name))

      ;;If  there is  no PARENT  clause try  to retrieve  the expression
      ;;evaluating to the RCD.
      (#f
       (syntax-match (get-clause 'parent-rtd clause*) ()
	 ((_ rtd rcd)
	  rcd)
	 ;;If neither the PARENT nor the PARENT-RTD clauses are present:
	 ;;just return false.
	 (#f #f)))
      ))

  (define (%make-rcd-code clause* foo-rtd protocol parent-rcd-code)
    `(make-record-constructor-descriptor ,foo-rtd ,parent-rcd-code ,protocol))

  (define (%get-protocol-code clause*)
    (syntax-match (get-clause 'protocol clause*) ()
      ((_ expr)		expr)
      (_		#f)))

  (define (%get-fields clause*)
    (syntax-match clause* (fields)
      (()
       '())
      (((fields f* ...) . _)
       f*)
      ((_ . rest)
       (%get-fields rest))))

;;; --------------------------------------------------------------------

  (define (%get-field-names fields)
    ;;Given the fields specification clause return a list of identifiers
    ;;representing all the field names.
    ;;
    (map (lambda (field)
	   (syntax-match field (mutable immutable)
	     ((mutable name accessor mutator)	(identifier? accessor)	name)
	     ((immutable name accessor)		(identifier? accessor)	name)
	     ((mutable name)			(identifier? name)	name)
	     ((immutable name)			(identifier? name)	name)
	     (name				(identifier? name)	name)
	     (others
	      (stx-error field "invalid field spec"))))
      fields))

  (define (%get-mutable-field-names fields)
    ;;Given the fields specification clause return a list of identifiers
    ;;representing the mutable field names.
    ;;
    (syntax-match fields (mutable immutable)
      (()
       '())

      (((mutable name accessor mutator) . rest)
       (identifier? accessor)
       (cons name (%get-mutable-field-names rest)))

      (((immutable name accessor) . rest)
       (identifier? accessor)
       (%get-mutable-field-names rest))

      (((mutable name) . rest)
       (identifier? name)
       (cons name (%get-mutable-field-names rest)))

      (((immutable name) . rest)
       (identifier? name)
       (%get-mutable-field-names rest))

      ((name . rest)
       (identifier? name)
       (%get-mutable-field-names rest))

      (others
       (stx-error fields "invalid field spec"))))

;;; --------------------------------------------------------------------

  (define (%get-mutator-indices fields)
    (let recur ((fields fields) (i 0))
      (syntax-match fields (mutable)
	(()
	 '())
	(((mutable . _) . rest)
	 (cons i (recur rest (+ i 1))))
	((_ . rest)
	 (recur rest (+ i 1))))))

  (define (%get-mutators foo fields)
    (define (gen-name x)
      (id foo foo "-" x "-set!"))
    (let recur ((fields fields))
      (syntax-match fields (mutable)
	(()
	 '())
	(((mutable name accessor mutator) . rest)
	 (cons mutator (recur rest)))
	(((mutable name) . rest)
	 (cons (gen-name name) (recur rest)))
	((_ . rest)
	 (recur rest)))))

  (define (%get-unsafe-mutators foo fields)
    (define (gen-name x)
      (id foo "$" foo "-" x "-set!"))
    (let f ((fields fields))
      (syntax-match fields (mutable)
	(() '())
	(((mutable name accessor mutator) . rest)
	 (cons (gen-name name) (f rest)))
	(((mutable name) . rest)
	 (cons (gen-name name) (f rest)))
	((_ . rest) (f rest)))))

  (define (%get-unsafe-mutators-idx-names foo fields)
    (let f ((fields fields))
      (syntax-match fields (mutable)
	(() '())
	(((mutable name accessor mutator) . rest)
	 (cons (gensym) (f rest)))
	(((mutable name) . rest)
	 (cons (gensym) (f rest)))
	((_ . rest) (f rest)))))

;;; --------------------------------------------------------------------

  (define (%get-accessors foo fields)
    (define (gen-name x)
      (id foo foo "-" x))
    (map (lambda (field)
	   (syntax-match field (mutable immutable)
	     ((mutable name accessor mutator) (identifier? accessor) accessor)
	     ((immutable name accessor)       (identifier? accessor) accessor)
	     ((mutable name)                  (identifier? name) (gen-name name))
	     ((immutable name)                (identifier? name) (gen-name name))
	     (name                            (identifier? name) (gen-name name))
	     (others (stx-error field "invalid field spec"))))
      fields))

  (define (%get-unsafe-accessors foo fields)
    (define (gen-name x)
      (id foo "$" foo "-" x))
    (map (lambda (field)
	   (syntax-match field (mutable immutable)
	     ((mutable name accessor mutator) (identifier? accessor) (gen-name name))
	     ((immutable name accessor)       (identifier? accessor) (gen-name name))
	     ((mutable name)                  (identifier? name) (gen-name name))
	     ((immutable name)                (identifier? name) (gen-name name))
	     (name                            (identifier? name) (gen-name name))
	     (others (stx-error field "invalid field spec"))))
      fields))

  (define (%get-unsafe-accessors-idx-names foo fields)
    (map (lambda (x)
	   (gensym))
      fields))

;;; --------------------------------------------------------------------

  (define (%enumerate ls)
    ;;Return a list of zero-based exact integers with the same length of
    ;;LS.
    ;;
    (let recur ((ls ls)
		(i  0))
      (if (null? ls)
	  '()
	(cons i (recur (cdr ls) (+ i 1))))))

;;; --------------------------------------------------------------------

  (define (%verify-clauses x cls*)
    (define VALID-KEYWORDS
      (map bless
	'(fields parent parent-rtd protocol sealed opaque nongenerative)))
    (define (%free-id-member? x ls)
      (and (pair? ls)
	   (or (free-id=? x (car ls))
	       (%free-id-member? x (cdr ls)))))
    (let loop ((cls*  cls*)
	       (seen* '()))
      (unless (null? cls*)
	(syntax-match (car cls*) ()
	  ((kwd . rest)
	   (cond ((or (not (identifier? kwd))
		      (not (%free-id-member? kwd VALID-KEYWORDS)))
		  (stx-error kwd "not a valid define-record-type keyword"))
		 ((bound-id-member? kwd seen*)
		  (syntax-violation #f "duplicate use of keyword " x kwd))
		 (else
		  (loop (cdr cls*) (cons kwd seen*)))))
	  (cls
	   (stx-error cls "malformed define-record-type clause"))))))

  (define (id ctxt . str*)
    ;;Given the  identifier CTXT  and a  list of  strings or  symbols or
    ;;identifiers  STR*: concatenate  all the  items in  STR*, with  the
    ;;result build  and return a new  identifier in the same  context of
    ;;CTXT.
    ;;
    (datum->syntax ctxt (string->symbol (apply string-append
					       (map (lambda (x)
						      (cond ((symbol? x)
							     (symbol->string x))
							    ((string? x)
							     x)
							    ((identifier? x)
							     (symbol->string (syntax->datum x)))
							    (else
							     (assertion-violation __who__ "BUG"))))
						 str*)))))

;;; --------------------------------------------------------------------

  (main x))


;;;; module non-core-macro-transformer: RECORD-TYPE-AND-RECORD?

(define (record-type-and-record?-macro expr-stx)
  ;;Transformer function used to expand Vicare's RECORD-TYPE-AND-RECORD?
  ;;macros from the top-level built in environment.  Expand the contents
  ;;of EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?type-name ?record)
     (identifier? ?type-name)
     (bless
      `(record-and-rtd? ,?record (record-type-descriptor ,?type-name))))
    ))


;;;; module non-core-macro-transformer: DEFINE-CONDITION-TYPE

(define define-condition-type-macro
  (lambda (x)
    (define (mkname name suffix)
      (datum->syntax name
		     (string->symbol
		      (string-append
		       (symbol->string (syntax->datum name))
		       suffix))))
    (syntax-match x ()
      ((ctxt name super constructor predicate (field* accessor*) ...)
       (and (identifier? name)
	    (identifier? super)
	    (identifier? constructor)
	    (identifier? predicate)
	    (for-all identifier? field*)
	    (for-all identifier? accessor*))
       (let ((aux-accessor* (map (lambda (x) (gensym)) accessor*)))
	 (bless
	  `(begin
	     (define-record-type (,name ,constructor ,(gensym))
	       (parent ,super)
	       (fields ,@(map (lambda (field aux)
				`(immutable ,field ,aux))
			   field* aux-accessor*))
	       (nongenerative)
	       (sealed #f) (opaque #f))
	     (define ,predicate (condition-predicate
				 (record-type-descriptor ,name)))
	     ,@(map
		   (lambda (accessor aux)
		     `(define ,accessor
			(condition-accessor
			 (record-type-descriptor ,name) ,aux)))
		 accessor* aux-accessor*))))))))


;;;; module non-core-macro-transformer: PARAMETERIZE and PARAMETRISE

(define parameterize-macro
  ;;
  ;;Notice that  MAKE-PARAMETER is  a primitive function  implemented in
  ;;"ikarus.compiler.sls" by "E-make-parameter".
  ;;
  (lambda (e)
    (syntax-match e ()
      ((_ () b b* ...)
       (bless `(let () ,b . ,b*)))
      ((_ ((olhs* orhs*) ...) b b* ...)
       (let ((lhs* (generate-temporaries olhs*))
	     (rhs* (generate-temporaries orhs*)))
	 (bless
	  `((lambda ,(append lhs* rhs*)
	      (let* ((guard? #t) ;apply the guard function only the first time
		     (swap   (lambda ()
			       ,@(map (lambda (lhs rhs)
					`(let ((t (,lhs)))
					   (,lhs ,rhs guard?)
					   (set! ,rhs t)))
				   lhs* rhs*)
			       (set! guard? #f))))
		(dynamic-wind
		    swap
		    (lambda () ,b . ,b*)
		    swap)))
	    ,@(append olhs* orhs*))))
       ;;Below is the original Ikarus code (Marco Maggi; Feb 3, 2012).
       ;;
       ;; (let ((lhs* (generate-temporaries olhs*))
       ;;       (rhs* (generate-temporaries orhs*)))
       ;;   (bless
       ;;     `((lambda ,(append lhs* rhs*)
       ;;         (let ((swap (lambda ()
       ;;                       ,@(map (lambda (lhs rhs)
       ;;                                `(let ((t (,lhs)))
       ;;                                   (,lhs ,rhs)
       ;;                                   (set! ,rhs t)))
       ;;                              lhs* rhs*))))
       ;;           (dynamic-wind
       ;;             swap
       ;;             (lambda () ,b . ,b*)
       ;;             swap)))
       ;;       ,@(append olhs* orhs*))))
       ))))


;;;; module non-core-macro-transformer: UNWIND-PROTECT

(define (unwind-protect-macro expr-stx)
  ;;Transformer function  used to expand Vicare's  UNWIND-PROTECT macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  ;;Not a  general UNWIND-PROTECT for Scheme,  but fine where we  do not
  ;;make the body return continuations to  the caller and then come back
  ;;again and again, calling CLEANUP multiple times.
  ;;
  (syntax-match expr-stx ()
    ((_ ?body ?cleanup0 ?cleanup* ...)
     (bless
      `(let ((cleanup (lambda () ,?cleanup0 ,@?cleanup*)))
	 (with-exception-handler
	     (lambda (E)
	       (cleanup)
	       (raise E))
	   (lambda ()
	     (begin0
		 ,?body
	       (cleanup)))))))
    ))


;;;; module non-core-macro-transformer: WITH-IMPLICITS

(define (with-implicits-macro expr-stx)
  ;;Transformer function  used to expand Vicare's  WITH-IMPLICITS macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  (define (%make-bindings ctx ids)
    (map (lambda (id)
	   `(,id (datum->syntax ,ctx (quote ,id))))
      ids))

  (syntax-match expr-stx ()

    ((_ () ?body0 ?body* ...)
     (bless
      `(begin ,?body0 ,@?body*)))

    ((_ ((?ctx ?symbol0 ?symbol* ...))
	?body0 ?body* ...)
     (let ((BINDINGS (%make-bindings ?ctx (cons ?symbol0 ?symbol*))))
       (bless
	`(with-syntax ,BINDINGS ,?body0 ,@?body*))))

    ((_ ((?ctx ?symbol0 ?symbol* ...) . ?other-clauses)
	?body0 ?body* ...)
     (let ((BINDINGS (%make-bindings ?ctx (cons ?symbol0 ?symbol*))))
       (bless
	`(with-syntax ,BINDINGS (with-implicits ,?other-clauses ,?body0 ,@?body*)))))

    ))


;;;; module non-core-macro-transformer: SET-CONS!

(define (set-cons!-macro expr-stx)
  ;;Transformer function  used to expand Vicare's  SET-CONS! macros from
  ;;the  top-level  built  in   environment.   Expand  the  contents  of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?id ?obj)
     (identifier? ?id)
     (bless `(set! ,?id (cons ,?obj ,?id))))
    ))


;;;; module non-core-macro-transformer: WITH-IMPLICITS

(define (eval-for-expand-macro expr-stx)
  ;;Transformer function used to  expand Vicare's EVAL-FOR-EXPAND macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?body0 ?body* ...)
     (bless
      `(define-syntax ,(gensym "eval-for-expand")
	 (begin ,?body0 ,@?body* values))))
    ))


;;;; module non-core-macro-transformer: compensations

(define (with-macro expr-stx)
  (syntax-match expr-stx ()
    ((_)
     (bless
      (lambda (stx)
	(syntax-error 'with "syntax \"with\" out of context"))))))

(module (with-compensations/on-error-macro
	 with-compensations-macro)

  (define (with-compensations/on-error-macro expr-stx)
    (syntax-match expr-stx ()
      ((_ ?body0 ?body* ...)
       (bless
	`(let ,(%make-store-binding)
	   (parametrise ((compensations store))
	     ,(%make-with-exception-handler ?body0 ?body*)))))
      ))

  (define (with-compensations-macro expr-stx)
    (syntax-match expr-stx ()
      ((_ ?body0 ?body* ...)
       (bless
	`(let ,(%make-store-binding)
	   (parametrise ((compensations store))
	     (begin0
		 ,(%make-with-exception-handler ?body0 ?body*)
	       ;;Better  run  the  cleanup   compensations  out  of  the
	       ;;WITH-EXCEPTION-HANDLER.
	       (run-compensations-store store))))))
      ))

  (define (%make-store-binding)
    '((store (let ((stack '()))
	       (case-lambda
		(()
		 stack)
		((false/thunk)
		 (if false/thunk
		     (set! stack (cons false/thunk stack))
		   (set! stack '()))))))))

  (define (%make-with-exception-handler body0 body*)
    ;;We really have to close the handler upon the STORE function, it is
    ;;wrong to access the COMPENSATIONS parameter from the handler.  The
    ;;dynamic environment  is synchronised with continuations:  when the
    ;;handler is called by  RAISE or RAISE-CONTINUABLE, the continuation
    ;;is the one of the RAISE or RAISE-CONTINUABLE forms.
    ;;
    `(with-exception-handler
	 (lambda (E)
	   (run-compensations-store store)
	   (raise E))
       (lambda ()
	 ,body0 ,@body*)))

  #| end of module |# )

(define (push-compensation-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?release0 ?release* ...)
     (bless
      `(push-compensation-thunk (lambda () ,?release0 ,@?release*))))
    ))

(define (compensate-macro expr-stx)
  (define-constant __who__ 'compensate)
  (define (%synner message subform)
    (syntax-violation __who__ message expr-stx subform))
  (syntax-match expr-stx ()
    ((_ ?alloc0 ?form* ...)
     (let ()
       (define free #f)
       (define alloc*
	 (let recur ((form-stx ?form*))
	   (syntax-match form-stx (with)
	     (((with ?release0 ?release* ...))
	      (begin
		(set! free `(push-compensation ,?release0 ,@?release*))
		'()))

	     (()
	      (%synner "invalid compensation syntax: missing WITH keyword" form-stx))

	     (((with))
	      (%synner "invalid compensation syntax: empty WITH keyword"
		       (bless '(with))))

	     ((?alloc ?form* ...)
	      (cons ?alloc (recur ?form*)))
	     )))
       (bless
	`(begin0 (begin ,?alloc0 ,@alloc*) ,free))))
    ))


;;;; module non-core-macro-transformer: DEFINE-STRUCT

(define define-struct-macro
  (if-wants-define-struct
   (lambda (e)
     (define enumerate
       (lambda (ls)
	 (let f ((i 0) (ls ls))
	   (cond
	    ((null? ls) '())
	    (else (cons i (f (+ i 1) (cdr ls))))))))
     (define mkid
       (lambda (id str)
	 (datum->stx id (string->symbol str))))
     (syntax-match e ()
       ((_ name (field* ...))
	(let* ((namestr		(symbol->string (identifier->symbol name)))
	       (fields		(map identifier->symbol field*))
	       (fieldstr*	(map symbol->string fields))
	       (rtd		(datum->stx name (make-struct-type namestr fields)))
	       (constr		(mkid name (string-append "make-" namestr)))
	       (pred		(mkid name (string-append namestr "?")))
	       (i*		(enumerate field*))
	       (getters		(map (lambda (x)
				       (mkid name (string-append namestr "-" x)))
				  fieldstr*))
	       (setters		(map (lambda (x)
				       (mkid name (string-append "set-" namestr "-" x "!")))
				  fieldstr*))
	       (unsafe-getters	(map (lambda (x)
				       (mkid name (string-append "$" namestr "-" x)))
				  fieldstr*))
	       (unsafe-setters	(map (lambda (x)
				       (mkid name (string-append "$set-" namestr "-" x "!")))
				  fieldstr*)))
	  (bless
	   `(begin
	      (define-syntax ,name (cons '$rtd ',rtd))
	      (define ,constr
		(lambda ,field*
		  (let ((S ($struct ',rtd ,@field*)))
		    (if ($struct-ref ',rtd 5) ;destructor
			($struct-guardian S)
		      S))))
	      (define ,pred
		(lambda (x) ($struct/rtd? x ',rtd)))
	      ,@(map (lambda (getter i)
		       `(define ,getter
			  (lambda (x)
			    (if ($struct/rtd? x ',rtd)
				($struct-ref x ,i)
			      (assertion-violation ',getter
				"not a struct of required type as struct getter argument"
				x ',rtd)))))
		  getters i*)
	      ,@(map (lambda (setter i)
		       `(define ,setter
			  (lambda (x v)
			    (if ($struct/rtd? x ',rtd)
				($struct-set! x ,i v)
			      (assertion-violation ',setter
				"not a struct of required type as struct setter argument"
				x ',rtd)))))
		  setters i*)
	      ,@(map (lambda (unsafe-getter i)
		       `(define-syntax ,unsafe-getter
			  (syntax-rules ()
			    ((_ x)
			     ($struct-ref x ,i))))
		       ;; (unquote (define ,unsafe-getter
		       ;; 		  (lambda (x)
		       ;; 		    ($struct-ref x ,i))))
		       )
		  unsafe-getters i*)
	      ,@(map (lambda (unsafe-setter i)
		       `(define-syntax ,unsafe-setter
			  (syntax-rules ()
			    ((_ x v)
			     ($struct-set! x ,i v))))
		       ;; (unquote (define ,unsafe-setter
		       ;; 	       (lambda (x v)
		       ;; 		 ($struct-set! x ,i v))))
		       )
		  unsafe-setters i*))
	   )))))
   (lambda (stx)
     (stx-error stx "define-struct not supported"))))


;;;; module non-core-macro-transformer: SYNTAX-RULES

(define syntax-rules-macro
  (lambda (e)
    (syntax-match e ()
      ((_ (lits ...)
	  (pat* tmp*) ...)
       (begin
	 (%verify-literals lits e)
	 (bless `(lambda (x)
		   (syntax-case x ,lits
		     ,@(map (lambda (pat tmp)
			      (syntax-match pat ()
				((_ . rest)
				 `((g . ,rest) (syntax ,tmp)))
				(_
				 (syntax-violation #f
				   "invalid syntax-rules pattern"
				   e pat))))
			 pat* tmp*)))))))))

(define (define-syntax-rule-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ (?name ?arg* ... . ?rest) ?body0 ?body* ...)
     (identifier? ?name)
     (bless
      `(define-syntax ,?name
	 (syntax-rules ()
	   ((_ ,@?arg* . ,?rest)
	    (begin ,?body0 ,@?body*))))))
    ))


;;;; module non-core-macro-transformer: DEFINE-SYNTAX*

(define (define-syntax*-macro expr-stx)
  ;;Transformer function  used to expand Vicare's  DEFINE-SYNTAX* macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?name)
     (identifier? ?name)
     (bless
      `(define-syntax ,?name (syntax-rules ()))))
    ((_ ?name ?expr)
     (identifier? ?name)
     (bless
      `(define-syntax ,?name ,?expr)))
    ((_ (?name ?stx) ?body0 ?body* ...)
     (and (identifier? ?name)
	  (identifier? ?stx))
     (let ((WHO     (datum->syntax ?name '__who__))
	   (SYNNER  (datum->syntax ?name 'synner)))
       (bless
	`(define-syntax ,?name
	   (lambda (,?stx)
	     (let-syntax
		 ((,WHO (identifier-syntax (quote ,?name))))
	       (letrec
		   ((,SYNNER (case-lambda
			      ((message)
			       (,SYNNER message #f))
			      ((message subform)
			       (syntax-violation ,WHO message ,?stx subform)))))
		 ,?body0 ,@?body*)))))))
    ))


;;;; module non-core-macro-transformer: WITH-SYNTAX

(define with-syntax-macro
  (lambda (e)
    (syntax-match e ()
      ((_ ((pat* expr*) ...) b b* ...)
       (let ((idn*
	      (let f ((pat* pat*))
		(cond
		 ((null? pat*) '())
		 (else
		  (let-values (((pat idn*) (convert-pattern (car pat*) '())))
		    (append idn* (f (cdr pat*)))))))))
	 (%verify-formals-syntax (map car idn*) e)
	 (let ((t* (generate-temporaries expr*)))
	   (bless
	    `(let ,(map list t* expr*)
	       ,(let f ((pat* pat*) (t* t*))
		  (cond
		   ((null? pat*) `(let () ,b . ,b*))
		   (else
		    `(syntax-case ,(car t*) ()
		       (,(car pat*) ,(f (cdr pat*) (cdr t*)))
		       (_ (assertion-violation 'with-syntax
			    "pattern does not match value"
			    ',(car pat*)
			    ,(car t*)))))))))))))))


;;;; module non-core-macro-transformer: IDENTIFIER-SYNTAX

(define (identifier-syntax-macro stx)
  (syntax-match stx (set!)
    ((_ expr)
     (bless
      `(lambda (x)
	 (syntax-case x ()
	   (id
	    (identifier? (syntax id))
	    (syntax ,expr))
	   ((id e* ...)
	    (identifier? (syntax id))
	    (cons (syntax ,expr) (syntax (e* ...))))
	   ))))
    ((_ (id1
	 expr1)
	((set! id2 expr2)
	 expr3))
     (and (identifier? id1)
	  (identifier? id2)
	  (identifier? expr2))
     (bless
      `(make-variable-transformer
	(lambda (x)
	  (syntax-case x (set!)
	    (id
	     (identifier? (syntax id))
	     (syntax ,expr1))
	    ((set! id ,expr2)
	     (syntax ,expr3))
	    ((id e* ...)
	     (identifier? (syntax id))
	     (syntax (,expr1 e* ...))))))))
    ))


;;;; module non-core-macro-transformer: LET, LET*, TRACE-LET

(define let-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ ((lhs* rhs*) ...) b b* ...)
       (if (valid-bound-ids? lhs*)
	   (bless `((lambda ,lhs* ,b . ,b*) . ,rhs*))
	 (%error-invalid-formals-syntax stx lhs*)))
      ((_ f ((lhs* rhs*) ...) b b* ...) (identifier? f)
       (if (valid-bound-ids? lhs*)
	   (bless `((letrec ((,f (lambda ,lhs* ,b . ,b*))) ,f) . ,rhs*))
	 (%error-invalid-formals-syntax stx lhs*))))))

(define let*-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ ((lhs* rhs*) ...) b b* ...) (for-all identifier? lhs*)
       (bless
	(let f ((x* (map list lhs* rhs*)))
	  (cond
	   ((null? x*) `(let () ,b . ,b*))
	   (else `(let (,(car x*)) ,(f (cdr x*)))))))))))

(define trace-let-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ f ((lhs* rhs*) ...) b b* ...) (identifier? f)
       (if (valid-bound-ids? lhs*)
	   (bless
	    `((letrec ((,f (trace-lambda ,f ,lhs* ,b . ,b*))) ,f) . ,rhs*))
	 (%error-invalid-formals-syntax stx lhs*))))))


;;;; module non-core-macro-transformer: LET-VALUES

(define let-values-macro
  (lambda (stx)
    (define (rename x old* new*)
      (unless (identifier? x)
	(syntax-violation #f "not an indentifier" stx x))
      (when (bound-id-member? x old*)
	(syntax-violation #f "duplicate binding" stx x))
      (let ((y (gensym (syntax->datum x))))
	(values y (cons x old*) (cons y new*))))
    (define (rename* x* old* new*)
      (cond
       ((null? x*) (values '() old* new*))
       (else
	(let*-values (((x old* new*) (rename (car x*) old* new*))
		      ((x* old* new*) (rename* (cdr x*) old* new*)))
	  (values (cons x x*) old* new*)))))
    (syntax-match stx ()
      ((_ () b b* ...)
       (cons* (bless 'let) '() b b*))
      ((_ ((lhs* rhs*) ...) b b* ...)
       (bless
	(let f ((lhs* lhs*) (rhs* rhs*) (old* '()) (new* '()))
	  (cond
	   ((null? lhs*)
	    `(let ,(map list old* new*) ,b . ,b*))
	   (else
	    (syntax-match (car lhs*) ()
	      ((x* ...)
	       (let-values (((y* old* new*) (rename* x* old* new*)))
		 `(call-with-values
		      (lambda () ,(car rhs*))
		    (lambda ,y*
		      ,(f (cdr lhs*) (cdr rhs*) old* new*)))))
	      ((x* ... . x)
	       (let*-values (((y old* new*) (rename x old* new*))
			     ((y* old* new*) (rename* x* old* new*)))
		 `(call-with-values
		      (lambda () ,(car rhs*))
		    (lambda ,(append y* y)
		      ,(f (cdr lhs*) (cdr rhs*)
			  old* new*)))))
	      (others
	       (syntax-violation #f "malformed bindings"
				 stx others)))))))))))


;;;; module non-core-macro-transformer: LET*-VALUES

(define let*-values-macro
  (lambda (stx)
    (define (check x*)
      (unless (null? x*)
	(let ((x (car x*)))
	  (unless (identifier? x)
	    (syntax-violation #f "not an identifier" stx x))
	  (check (cdr x*))
	  (when (bound-id-member? x (cdr x*))
	    (syntax-violation #f "duplicate identifier" stx x)))))
    (syntax-match stx ()
      ((_ () b b* ...)
       (cons* (bless 'let) '() b b*))
      ((_ ((lhs* rhs*) ...) b b* ...)
       (bless
	(let f ((lhs* lhs*) (rhs* rhs*))
	  (cond
	   ((null? lhs*)
	    `(begin ,b . ,b*))
	   (else
	    (syntax-match (car lhs*) ()
	      ((x* ...)
	       (begin
		 (check x*)
		 `(call-with-values
		      (lambda () ,(car rhs*))
		    (lambda ,x*
		      ,(f (cdr lhs*) (cdr rhs*))))))
	      ((x* ... . x)
	       (begin
		 (check (cons x x*))
		 `(call-with-values
		      (lambda () ,(car rhs*))
		    (lambda ,(append x* x)
		      ,(f (cdr lhs*) (cdr rhs*))))))
	      (others
	       (syntax-violation #f "malformed bindings"
				 stx others)))))))))))


;;;; module non-core-macro-transformer: VALUES->LIST-MACRO

(define (values->list-macro stx)
  (syntax-match stx ()
    ((_ expr)
     (bless
      `(call-with-values
	   (lambda () ,expr)
	 list)))))


;;;; module non-core-macro-transformer: LET*-SYNTAX

(define (let*-syntax-macro stx)
  (syntax-match stx ()
    ;;No bindings.
    ((_ () ?body ?body* ...)
     (bless
      `(begin ,?body ,@?body*)))
    ;;Single binding.
    ((_ ((?lhs ?rhs)) ?body ?body* ...)
     (bless
      `(let-syntax ((,?lhs ,?rhs))
	 ,?body ,@?body*)))
    ;;Multiple bindings
    ((_ ((?lhs ?rhs) (?lhs* ?rhs*) ...) ?body ?body* ...)
     (bless
      `(let-syntax ((,?lhs ,?rhs))
	 (let*-syntax ,(map list ?lhs* ?rhs*)
	   ,?body ,@?body*))))
    ))


;;;; module non-core-macro-transformer: LET-CONSTANTS, LET*-CONSTANTS, LETREC-CONSTANTS, LETREC*-CONSTANTS

(define (let-constants-macro stx)
  (syntax-match stx ()
    ;;No bindings.
    ((_ () ?body ?body* ...)
     (bless
      `(let () ,?body ,@?body*)))
    ;;Multiple bindings
    ((_ ((?lhs ?rhs) (?lhs* ?rhs*) ...) ?body ?body* ...)
     (let ((SHADOW* (generate-temporaries (cons ?lhs ?lhs*))))
       (bless
	`(let ,(map list SHADOW* (cons ?rhs ?rhs*))
	   (let-syntax ,(map (lambda (lhs shadow)
			       `(,lhs (identifier-syntax ,shadow)))
			  (cons ?lhs ?lhs*) SHADOW*)
	     ,?body ,@?body*)))))
    ))

(define (let*-constants-macro stx)
  (syntax-match stx ()
    ;;No bindings.
    ((_ () ?body ?body* ...)
     (bless
      `(let () ,?body ,@?body*)))
    ;;Multiple bindings
    ((_ ((?lhs ?rhs) (?lhs* ?rhs*) ...) ?body ?body* ...)
     (bless
      `(let-constants ((,?lhs ,?rhs))
	 (let*-constants ,(map list ?lhs* ?rhs*)
	   ,?body ,@?body*))))
    ))

(define (letrec-constants-macro stx)
  (syntax-match stx ()
    ((_ () ?body0 ?body* ...)
     (bless
      `(let () ,?body0 ,@?body*)))

    ((_ ((?lhs* ?rhs*) ...) ?body0 ?body* ...)
     (let ((TMP* (generate-temporaries ?lhs*))
	   (VAR* (generate-temporaries ?lhs*)))
       (bless
	`(let ,(map (lambda (var)
		      `(,var (void)))
		 VAR*)
	   (let-syntax ,(map (lambda (lhs var)
			       `(,lhs (identifier-syntax ,var)))
			  ?lhs* VAR*)
	     ;;Do not enforce the order of evaluation of ?RHS.
	     (let ,(map list TMP* ?rhs*)
	       ,@(map (lambda (var tmp)
			`(set! ,var ,tmp))
		   VAR* TMP*)
	       (let () ,?body0 ,@?body*)))))))
    ))

(define (letrec*-constants-macro stx)
  (syntax-match stx ()
    ((_ () ?body0 ?body* ...)
     (bless
      `(let () ,?body0 ,@?body*)))

    ((_ ((?lhs* ?rhs*) ...) ?body0 ?body* ...)
     (let ((TMP* (generate-temporaries ?lhs*))
	   (VAR* (generate-temporaries ?lhs*)))
       (bless
	`(let ,(map (lambda (var)
		      `(,var (void)))
		 VAR*)
	   (let-syntax ,(map (lambda (lhs var)
			       `(,lhs (identifier-syntax ,var)))
			  ?lhs* VAR*)
	     ;;Do enforce the order of evaluation of ?RHS.
	     (let* ,(map list TMP* ?rhs*)
	       ,@(map (lambda (var tmp)
			`(set! ,var ,tmp))
		   VAR* TMP*)
	       (let () ,?body0 ,@?body*)))))))
    ))


;;;; module non-core-macro-transformer: CASE-DEFINE

(define (case-define-macro stx)
  (syntax-match stx ()
    ((_ ?who ?cl-clause ?cl-clause* ...)
     (identifier? ?who)
     (bless
      `(define ,?who
	 (case-lambda ,?cl-clause ,@?cl-clause*))))
    ))


;;;; module non-core-macro-transformer: DEFINE*, LAMBDA*, CASE-DEFINE*, CASE-LAMBDA*

(module (lambda*-macro
	 define*-macro
	 case-lambda*-macro
	 case-define*-macro)

  (define-record argument-validation-spec
    (arg-id
		;Identifier representing the formal name of the argument
		;being validated.
     expr
		;Syntax  object  representing   an  argument  validation
		;expression.
     ))

  (define-record retval-validation-spec
    (rv-id
		;Identifier representing the internal formal name of the
		;return value being validated.
     pred
		;Identifier bound to the predicate  to be applied to the
		;return value.
     ))

;;; --------------------------------------------------------------------

  (module (define*-macro)
    ;;Transformer function  used to expand Vicare's  DEFINE* macros from
    ;;the  top-level  built  in  environment.  Expand  the  contents  of
    ;;EXPR-STX.  Return a sexp in the core language.
    ;;
    ;;We want to implement the following example expansions:
    ;;
    ;;  (define* ?id ?value)	==> (define ?id ?value)
    ;;  (define* ?id)		==> (define ?id)
    ;;
    ;;  (define* (?who . ?common-formals) . ?body)
    ;;  ==> (define (?who . ?common-formals)
    ;;        (let-constants ((__who__ (quote ?who))) (let () . ?body)))
    ;;
    ;;  (define* (?who (?var ?pred)) . ?body)
    ;;  ==> (define (?who ?var)
    ;;        (let-constants ((__who__ (quote ?who)))
    ;;          (unless (?pred ?var)
    ;; 	          (procedure-argument-violation __who__
    ;; 	            "failed argument validation" '(?pred ?var) ?var))
    ;;          (let () . ?body)))
    ;;
    ;;  (define* ((?who ?pred) ?var) . ?body)
    ;;  ==> (define (?who ?var)
    ;;        (let-constants ((__who__ (quote ?who)))
    ;;          (receive-and-return (rv)
    ;;              (let () . ?body)
    ;;            (unless (?pred rv)
    ;;              (expression-return-value-violation __who__
    ;; 	              "failed return value validation" (list '?pred rv))))))
    ;;
    (define (define*-macro stx)
      (define (%synner message subform)
	(syntax-violation 'define* message stx subform))
      (syntax-match stx ()
	;;No ret-pred.
	((_ (?who . ?formals) ?body0 ?body* ...)
	 (identifier? ?who)
	 (%generate-define-output-form/without-ret-pred ?who ?formals (cons ?body0 ?body*) %synner))

	;;Ret-pred with list spec.
	((_ ((?who ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (identifier? ?who)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-define-output-form/with-ret-pred ?who (cons ?ret-pred0 ?ret-pred*) ?formals (cons ?body0 ?body*) %synner))

	;;Ret-pred with vector spec.
	((_ (#(?who ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (identifier? ?who)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-define-output-form/with-ret-pred ?who (cons ?ret-pred0 ?ret-pred*) ?formals (cons ?body0 ?body*) %synner))

	((_ ?who ?expr)
	 (identifier? ?who)
	 (bless
	  `(define ,?who ,?expr)))

	((_ ?who)
	 (identifier? ?who)
	 (bless
	  `(define ,?who (void))))

	))

    (define (%generate-define-output-form/without-ret-pred ?who ?predicate-formals ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?who '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner)))
	  (bless
	   `(define (,?who . ,?standard-formals)
	      (let-constants ((,WHO (quote ,?who)))
		,@ARG-VALIDATION*
		(let () . ,?body*)))))))

    (define (%generate-define-output-form/with-ret-pred ?who ?ret-pred* ?predicate-formals ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?who '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner))
	       (RET*            (generate-temporaries ?ret-pred*))
	       (RET-VALIDATION  (%make-ret-validation-form WHO
							   (map make-retval-validation-spec RET* ?ret-pred*)
							   synner)))
	  (bless
	   `(define (,?who . ,?standard-formals)
	      (let-constants ((,WHO (quote ,?who)))
		,@ARG-VALIDATION*
		(receive-and-return (,@RET*)
		    (let () . ,?body*)
		  ,RET-VALIDATION)))))))

    #| end of module |# )

;;; --------------------------------------------------------------------

  (module (case-define*-macro)

    (define (case-define*-macro stx)
      ;;Transformer function used to expand Vicare's CASE-DEFINE* macros
      ;;from the top-level built in environment.  Expand the contents of
      ;;EXPR-STX.  Return a sexp in the core language.
      ;;
      (define (%synner message subform)
	(syntax-violation 'case-define* message stx subform))
      (syntax-match stx ()
	((_ ?who ?clause0 ?clause* ...)
	 (identifier? ?who)
	 (bless
	  `(define ,?who
	     (case-lambda
	      ,@(map (lambda (?clause)
		       (%generate-case-define-form ?who ?clause %synner))
		  (cons ?clause0 ?clause*))))))
	))

    (define (%generate-case-define-form ?who ?clause synner)
      (syntax-match ?clause ()
	;;Ret-pred with list spec.
	((((?underscore ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (%underscore? ?underscore)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-case-define-clause-form/with-ret-pred ?who (cons ?ret-pred0 ?ret-pred*) ?formals ?body0 ?body* synner))

	;;Ret-pred with vector spec.
	(((#(?underscore ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (%underscore? ?underscore)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-case-define-clause-form/with-ret-pred ?who (cons ?ret-pred0 ?ret-pred*) ?formals ?body0 ?body* synner))

	;;No ret-pred.
	((?formals ?body0 ?body* ...)
	 (%generate-case-define-clause-form/without-ret-pred ?who ?formals ?body0 ?body* synner))
	))

    (define (%generate-case-define-clause-form/without-ret-pred ?who ?predicate-formals ?body0 ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?who '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner)))
	  `(,?standard-formals
	    (let-constants ((,WHO (quote ,?who)))
	      ,@ARG-VALIDATION*
	      (let () ,?body0 ,@?body*))))))

    (define (%generate-case-define-clause-form/with-ret-pred ?who ?ret-pred* ?predicate-formals ?body0 ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?who '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner))
	       (RET*            (generate-temporaries ?ret-pred*))
	       (RET-VALIDATION  (%make-ret-validation-form WHO
							   (map make-retval-validation-spec RET* ?ret-pred*)
							   synner)))
	  `(,?standard-formals
	    (let-constants ((,WHO (quote ,?who)))
	      ,@ARG-VALIDATION*
	      (receive-and-return (,@RET*)
		  (let () ,?body0 ,@?body*)
		,RET-VALIDATION))))))

    #| end of module |# )

;;; --------------------------------------------------------------------

  (module (lambda*-macro)

    (define (lambda*-macro stx)
      ;;Transformer function used to expand Vicare's LAMBDA* macros from
      ;;the  top-level built  in  environment.  Expand  the contents  of
      ;;EXPR-STX.  Return a sexp in the core language.
      ;;
      (define (%synner message subform)
	(syntax-violation 'lambda* message stx subform))
      (syntax-match stx ()
	;;Ret-pred with list spec.
	((?kwd ((?underscore ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (%underscore? ?underscore)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-lambda-output-form/with-ret-pred ?kwd (cons ?ret-pred0 ?ret-pred*) ?formals ?body0 ?body* %synner))

	;;Ret-pred with vector spec.
	((?kwd (#(?underscore ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (%underscore? ?underscore)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-lambda-output-form/with-ret-pred ?kwd (cons ?ret-pred0 ?ret-pred*) ?formals ?body0 ?body* %synner))

	;;No ret-pred.
	((?kwd ?formals ?body0 ?body* ...)
	 (%generate-lambda-output-form/without-ret-pred ?kwd ?formals ?body0 ?body* %synner))

	))

    (define (%generate-lambda-output-form/without-ret-pred ?ctx ?predicate-formals ?body0 ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?ctx '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner)))
	  (bless
	   `(lambda ,?standard-formals
	      (let-constants ((,WHO (quote _)))
		,@ARG-VALIDATION*
		(let () ,?body0 ,@?body*)))))))

    (define (%generate-lambda-output-form/with-ret-pred ?ctx ?ret-pred* ?predicate-formals ?body0 ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?ctx '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner))
	       (RET*            (generate-temporaries ?ret-pred*))
	       (RET-VALIDATION  (%make-ret-validation-form WHO
							   (map make-retval-validation-spec RET* ?ret-pred*)
							   synner)))
	  (bless
	   `(lambda ,?standard-formals
	      (let-constants ((,WHO (quote _)))
		,@ARG-VALIDATION*
		(receive-and-return (,@RET*)
		    (let () ,?body0 ,@?body*)
		  ,RET-VALIDATION)))))))

    #| end of module |# )

;;; --------------------------------------------------------------------

  (module (case-lambda*-macro)

    (define (case-lambda*-macro stx)
      ;;Transformer function used to expand Vicare's CASE-LAMBDA* macros
      ;;from the top-level built in environment.  Expand the contents of
      ;;EXPR-STX.  Return a sexp in the core language.
      ;;
      (define (%synner message subform)
	(syntax-violation 'case-lambda* message stx subform))
      (syntax-match stx ()
	((?kwd ?clause0 ?clause* ...)
	 (bless
	  `(case-lambda
	    ,@(map (lambda (?clause)
		     (%generate-case-lambda-form ?kwd ?clause %synner))
		(cons ?clause0 ?clause*)))))
	))

    (define (%generate-case-lambda-form ?ctx ?clause synner)
      (syntax-match ?clause ()
	;;Ret-pred with list spec.
	((((?underscore ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (%underscore? ?underscore)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-case-lambda-clause-form/with-ret-pred ?ctx (cons ?ret-pred0 ?ret-pred*) ?formals ?body0 ?body* synner))

	;;Ret-pred with vector spec.
	(((#(?underscore ?ret-pred0 ?ret-pred* ...) . ?formals) ?body0 ?body* ...)
	 (and (%underscore? ?underscore)
	      (identifier? ?ret-pred0)
	      (for-all identifier? ?ret-pred*))
	 (%generate-case-lambda-clause-form/with-ret-pred ?ctx (cons ?ret-pred0 ?ret-pred*) ?formals ?body0 ?body* synner))

	;;No ret-pred.
	((?formals ?body0 ?body* ...)
	 (%generate-case-lambda-clause-form/without-ret-pred ?ctx ?formals ?body0 ?body* synner))
	))

    (define (%generate-case-lambda-clause-form/without-ret-pred ?ctx ?predicate-formals ?body0 ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?ctx '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner)))
	  `(,?standard-formals
	    (let-constants ((,WHO (quote _)))
	      ,@ARG-VALIDATION*
	      (let () ,?body0 ,@?body*))))))

    (define (%generate-case-lambda-clause-form/with-ret-pred ?ctx ?ret-pred* ?predicate-formals ?body0 ?body* synner)
      (receive (?standard-formals arg-validation-spec*)
	  (%parse-predicate-formals ?predicate-formals synner)
	(let* ((WHO             (datum->syntax ?ctx '__who__))
	       (ARG-VALIDATION* (%make-arg-validation-forms WHO arg-validation-spec* synner))
	       (RET*            (generate-temporaries ?ret-pred*))
	       (RET-VALIDATION  (%make-ret-validation-form WHO
							   (map make-retval-validation-spec RET* ?ret-pred*)
							   synner)))
	  `(,?standard-formals
	    (let-constants ((,WHO (quote _)))
	      ,@ARG-VALIDATION*
	      (receive-and-return (,@RET*)
		  (let () ,?body0 ,@?body*)
		,RET-VALIDATION))))))

    #| end of module |# )

;;; --------------------------------------------------------------------

  (define (%parse-predicate-formals ?predicate-formals synner)
    ;;Split  formals from  tags.   We  rely on  the  DEFINE, LAMBDA  and
    ;;CASE-LAMBDA syntaxes  in the output  form to further  validate the
    ;;formals against duplicate bindings.
    ;;
    ;;We use  the conventions: ?ID,  ?REST-ID and ?ARGS-ID  are argument
    ;;identifiers;  ?PRED   is  a  predicate  identifier;   ?EXPR  is  a
    ;;validation expression.
    ;;
    ;;We accept the following standard formals formats:
    ;;
    ;;   ?args-id
    ;;   (?id ...)
    ;;   (?id0 ?id ... . ?rest-id)
    ;;
    ;;and in addition the following predicate formals:
    ;;
    ;;   #(?args-id ?pred ?expr ...)
    ;;   (?pred-arg ...)
    ;;   (?pred-arg0 ?pred-arg ... . ?rest-id)
    ;;   (?pred-arg0 ?pred-arg ... . #(?rest ?pred ?expr ...))
    ;;
    ;;where ?PRED-ARG is a predicate argument with one of the formats:
    ;;
    ;;   ?id
    ;;   (?id ?pred ?expr ...)
    ;;
    ;;Return 3 values:
    ;;
    ;;* A list  of syntax objects representing the  standard formals for
    ;;the DEFINE, LAMBDA and CASE-LAMBDA syntaxes.
    ;;
    ;;* A list of  ARGUMENT-VALIDATION-SPEC structures each representing
    ;;a validation predicate.
    ;;
    (syntax-match ?predicate-formals ()

      ;;Untagged identifiers without rest argument.
      ;;
      ((?id* ...)
       (for-all identifier? ?id*)
       (values ?id* '()))

      ;;Untagged identifiers with rest argument.
      ;;
      ((?id* ... . ?rest-id)
       (and (for-all identifier? ?id*)
	    (identifier? ?rest-id))
       (values ?predicate-formals '()))

      ;;Possibly tagged identifiers without rest argument.
      ;;
      ((?pred-arg* ...)
       (let recur ((?pred-arg* ?pred-arg*))
	 (if (pair? ?pred-arg*)
	     (receive (?standard-formals arg-validation-spec*)
		 (recur (cdr ?pred-arg*))
	       (let ((?pred-arg (car ?pred-arg*)))
		 (syntax-match ?pred-arg ()
		   ;;Untagged argument.
		   (?id
		    (identifier? ?id)
		    (values (cons ?id ?standard-formals)
			    arg-validation-spec*))
		   ;;Tagged argument, list spec.
		   ((?id ?pred)
		    (and (identifier? ?id)
			 (identifier? ?pred))
		    (values (cons ?id ?standard-formals)
			    (cons (make-argument-validation-spec ?id (list ?pred ?id))
				  arg-validation-spec*)))
		   ;;Tagged argument, vector spec.
		   (#(?id ?pred)
		    (and (identifier? ?id)
			 (identifier? ?pred))
		    (values (cons ?id ?standard-formals)
			    (cons (make-argument-validation-spec ?id (list ?pred ?id))
				  arg-validation-spec*)))
		   (else
		    (synner "invalid argument specification" ?pred-arg)))))
	   (values '() '()))))

      ;;Possibly tagged identifiers with rest argument.
      ;;
      ((?pred-arg* ... . ?rest-var)
       (let recur ((?pred-arg* ?pred-arg*))
	 (if (pair? ?pred-arg*)
	     (receive (?standard-formals arg-validation-spec*)
		 (recur (cdr ?pred-arg*))
	       (let ((?pred-arg (car ?pred-arg*)))
		 (syntax-match ?pred-arg ()
		   ;;Untagged argument.
		   (?id
		    (identifier? ?id)
		    (values (cons ?id ?standard-formals)
			    arg-validation-spec*))
		   ;;Tagged argument, list spec.
		   ((?id ?pred)
		    (and (identifier? ?id)
			 (identifier? ?pred))
		    (values (cons ?id ?standard-formals)
			    (cons (make-argument-validation-spec ?id (list ?pred ?id))
				  arg-validation-spec*)))
		   ;;Tagged argument, vector spec.
		   (#(?id ?pred)
		    (and (identifier? ?id)
			 (identifier? ?pred))
		    (values (cons ?id ?standard-formals)
			    (cons (make-argument-validation-spec ?id (list ?pred ?id))
				  arg-validation-spec*)))
		   (else
		    (synner "invalid argument specification" ?pred-arg)))))
	   ;;Process rest argument.
	   (syntax-match ?rest-var ()
	     ;;Untagged rest argument.
	     (?rest-id
	      (identifier? ?rest-id)
	      (values ?rest-id '()))
	     ;;Tagged rest argument.
	     (#(?rest-id ?rest-pred)
	      (and (identifier? ?rest-id)
		   (identifier? ?rest-pred))
	      (values ?rest-id
		      (list (make-argument-validation-spec ?rest-id (list ?rest-pred ?rest-id)))))
	     (else
	      (synner "invalid argument specification" ?rest-var))))))
      ))

;;; --------------------------------------------------------------------

  (define (%make-arg-validation-forms WHO arg-validation-spec* synner)
    (if (enable-arguments-validation?)
	(map (lambda (spec)
	       (let ((?arg-expr (argument-validation-spec-expr   spec))
		     (?arg-id   (argument-validation-spec-arg-id spec)))
		 `(unless ,?arg-expr
		    (procedure-argument-violation ,WHO
		      "failed argument validation"
		      (quote ,?arg-expr) ,?arg-id))))
	  arg-validation-spec*)
      '()))

  (define (%make-ret-validation-form WHO retval-validation-spec* synner)
    (if (enable-arguments-validation?)
	`(begin
	   ,@(map (lambda (spec)
		    (let ((?pred (retval-validation-spec-pred  spec))
			  (?ret  (retval-validation-spec-rv-id spec)))
		      `(unless (,?pred ,?ret)
			 (expression-return-value-violation ,WHO
			   "failed return value validation"
			   ;;This list  represents the application  of the
			   ;;predicate to the offending value.
			   (list (quote ,?pred) ,?ret)))))
	       retval-validation-spec*))
      '(void)))

  (define (%underscore? stx)
    (and (identifier? stx)
	 (eq? '_ (syntax->datum stx))))

  #| end of module |# )


;;;; module non-core-macro-transformer: TRACE-LAMBDA, TRACE-DEFINE and TRACE-DEFINE-SYNTAX

(define trace-lambda-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ who (fmls ...) b b* ...)
       (if (valid-bound-ids? fmls)
	   (bless `(make-traced-procedure ',who
					  (lambda ,fmls ,b . ,b*)))
	 (%error-invalid-formals-syntax stx fmls)))
      ((_  who (fmls ... . last) b b* ...)
       (if (valid-bound-ids? (cons last fmls))
	   (bless `(make-traced-procedure ',who
					  (lambda (,@fmls . ,last) ,b . ,b*)))
	 (%error-invalid-formals-syntax stx (append fmls last)))))))

(define trace-define-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ (who fmls ...) b b* ...)
       (if (valid-bound-ids? fmls)
	   (bless `(define ,who
		     (make-traced-procedure ',who
					    (lambda ,fmls ,b . ,b*))))
	 (%error-invalid-formals-syntax stx fmls)))
      ((_ (who fmls ... . last) b b* ...)
       (if (valid-bound-ids? (cons last fmls))
	   (bless `(define ,who
		     (make-traced-procedure ',who
					    (lambda (,@fmls . ,last) ,b . ,b*))))
	 (%error-invalid-formals-syntax stx (append fmls last))))
      ((_ who expr)
       (if (identifier? who)
	   (bless `(define ,who
		     (let ((v ,expr))
		       (if (procedure? v)
			   (make-traced-procedure ',who v)
			 v))))
	 (stx-error stx "invalid name"))))))

(define trace-define-syntax-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ who expr)
       (if (identifier? who)
	   (bless
	    `(define-syntax ,who
	       (make-traced-macro ',who ,expr)))
	 (stx-error stx "invalid name"))))))


;;;; module non-core-macro-transformer: TRACE-LET, TRACE-LET-SYNTAX, TRACE-LETREC-SYNTAX

(define trace-let/rec-syntax
  (lambda (who)
    (lambda (stx)
      (syntax-match stx ()
	((_ ((lhs* rhs*) ...) b b* ...)
	 (if (valid-bound-ids? lhs*)
	     (let ((rhs* (map (lambda (lhs rhs)
				`(make-traced-macro ',lhs ,rhs))
			   lhs* rhs*)))
	       (bless `(,who ,(map list lhs* rhs*) ,b . ,b*)))
	   (%error-invalid-formals-syntax stx lhs*)))))))

(define trace-let-syntax-macro
  (trace-let/rec-syntax 'let-syntax))

(define trace-letrec-syntax-macro
  (trace-let/rec-syntax 'letrec-syntax))


;;;; module non-core-macro-transformer: GUARD

(define guard-macro
  (lambda (x)
    (define (gen-clauses raised-obj con outerk clause*)
      (define (f x k)
	(syntax-match x (=>)
	  ((e => p)
	   (let ((t (gensym)))
	     `(let ((,t ,e))
		(if ,t (,p ,t) ,k))))
	  ((e)
	   (let ((t (gensym)))
	     `(let ((,t ,e))
		(if ,t ,t ,k))))
	  ((e v v* ...)
	   `(if ,e (begin ,v ,@v*) ,k))
	  (_ (stx-error x "invalid guard clause"))))
      (define (f* x*)
	(syntax-match x* (else)
	  (()
	   (let ((g (gensym)))
	     (values `(,g (lambda () (raise-continuable ,raised-obj))) g)))
	  (((else e e* ...))
	   (values `(begin ,e ,@e*) #f))
	  ((cls . cls*)
	   (let-values (((e g) (f* cls*)))
	     (values (f cls e) g)))
	  (others (stx-error others "invalid guard clause"))))
      (let-values (((code raisek) (f* clause*)))
	(if raisek
	    `((call/cc
                  (lambda (,raisek)
                    (,outerk
		     (lambda () ,code)))))
	  `(,outerk (lambda () ,code)))))
    (syntax-match x ()
      ((_ (con clause* ...) b b* ...)
       (identifier? con)
       (let ((outerk     (gensym))
	     (raised-obj (gensym)))
	 (bless
	  `((call/cc
		(lambda (,outerk)
		  (lambda ()
		    (with-exception-handler
			(lambda (,raised-obj)
			  (let ((,con ,raised-obj))
			    ,(gen-clauses raised-obj con outerk clause*)))
		      (lambda () ,b ,@b*))))))))))))


;;;; module non-core-macro-transformer: DEFINE-ENUMERATION

(define (define-enumeration-macro stx)
  (define-constant __who__ 'define-enumeration)
  (define (set? x)
    (or (null? x)
	(and (not (memq (car x) (cdr x)))
	     (set? (cdr x)))))
  (define (remove-dups ls)
    (if (null? ls)
	'()
      (cons (car ls)
	    (remove-dups (remq (car ls) (cdr ls))))))
  (syntax-match stx ()
    ((_ name (id* ...) maker)
     (begin
       (unless (identifier? name)
	 (syntax-violation __who__
	   "expected identifier as enumeration type name" stx name))
       (unless (for-all identifier? id*)
	 (syntax-violation __who__
	   "expected list of symbols as enumeration elements" stx id*))
       (unless (identifier? maker)
	 (syntax-violation __who__
	   "expected identifier as enumeration constructor syntax name" stx maker))
       (let ((name*		(remove-dups (syntax->datum id*)))
	     (the-constructor	(gensym)))
	 (bless
	  `(begin
	     (define ,the-constructor
	       (enum-set-constructor (make-enumeration ',name*)))

	     (define-syntax ,name
	       ;;Check at macro-expansion time whether the symbol ?ARG
	       ;;is in  the universe associated with NAME.   If it is,
	       ;;the result  of the  expansion is equivalent  to ?ARG.
	       ;;It is a syntax violation if it is not.
	       ;;
	       (lambda (x)
		 (define universe-of-symbols ',name*)
		 (define (%synner message subform)
		   (syntax-violation ',name message
				     (syntax->datum x) (syntax->datum subform)))
		 (syntax-case x ()
		   ((_ ?arg)
		    (not (identifier? (syntax ?arg)))
		    (%synner "expected symbol as argument to enumeration validator"
			     (syntax ?arg)))

		   ((_ ?arg)
		    (not (memq (syntax->datum (syntax ?arg)) universe-of-symbols))
		    (%synner "expected symbol in enumeration as argument to enumeration validator"
			     (syntax ?arg)))

		   ((_ ?arg)
		    (syntax (quote ?arg)))

		   (_
		    (%synner "invalid enumeration validator form" #f)))))

	     (define-syntax ,maker
	       ;;Given  any  finite sequence  of  the  symbols in  the
	       ;;universe, possibly  with duplicates, expands  into an
	       ;;expression that  evaluates to the  enumeration set of
	       ;;those symbols.
	       ;;
	       ;;Check  at macro-expansion  time  whether every  input
	       ;;symbol is in the universe associated with NAME; it is
	       ;;a syntax violation if one or more is not.
	       ;;
	       (lambda (x)
		 (define universe-of-symbols ',name*)
		 (define (%synner message subform-stx)
		   (syntax-violation ',maker message
				     (syntax->datum x) (syntax->datum subform-stx)))
		 (syntax-case x ()
		   ((_ . ?list-of-symbols)
		    ;;Check the input  symbols one by one partitioning
		    ;;the ones in the universe from the one not in the
		    ;;universe.
		    ;;
		    ;;If  an input element  is not  a symbol:  raise a
		    ;;syntax violation.
		    ;;
		    ;;After   all   the   input  symbols   have   been
		    ;;partitioned,  if the  list of  collected INvalid
		    ;;ones is not null:  raise a syntax violation with
		    ;;that list as  subform, else return syntax object
		    ;;expression   building  a  new   enumeration  set
		    ;;holding the list of valid symbols.
		    ;;
		    (let loop ((valid-symbols-stx	'())
			       (invalid-symbols-stx	'())
			       (input-symbols-stx	(syntax ?list-of-symbols)))
		      (syntax-case input-symbols-stx ()

			;;No more symbols to collect and non-null list
			;;of collected INvalid symbols.
			(()
			 (not (null? invalid-symbols-stx))
			 (%synner "expected symbols in enumeration as arguments \
                                     to enumeration constructor syntax"
				  (reverse invalid-symbols-stx)))

			;;No more symbols to  collect and null list of
			;;collected INvalid symbols.
			(()
			 (quasisyntax
			  (,the-constructor '(unsyntax (reverse valid-symbols-stx)))))

			;;Error if element is not a symbol.
			((?symbol0 . ?rest)
			 (not (identifier? (syntax ?symbol0)))
			 (%synner "expected symbols as arguments to enumeration constructor syntax"
				  (syntax ?symbol0)))

			;;Collect a symbol in the set.
			((?symbol0 . ?rest)
			 (memq (syntax->datum (syntax ?symbol0)) universe-of-symbols)
			 (loop (cons (syntax ?symbol0) valid-symbols-stx)
			       invalid-symbols-stx (syntax ?rest)))

			;;Collect a symbol not in the set.
			((?symbol0 . ?rest)
			 (loop valid-symbols-stx
			       (cons (syntax ?symbol0) invalid-symbols-stx)
			       (syntax ?rest)))

			))))))
	     )))))
    ))


;;;; module non-core-macro-transformer: DO

(define do-macro
  (lambda (stx)
    (define bind
      (lambda (x)
	(syntax-match x ()
	  ((x init)      `(,x ,init ,x))
	  ((x init step) `(,x ,init ,step))
	  (_  (stx-error stx "invalid binding")))))
    (syntax-match stx ()
      ((_ (binding* ...)
	  (test expr* ...)
	  command* ...)
       (syntax-match (map bind binding*) ()
	 (((x* init* step*) ...)
	  (if (valid-bound-ids? x*)
	      (bless
	       `(letrec ((loop
			  (lambda ,x*
			    (if ,test
				(begin (if #f #f) ,@expr*)
			      (begin
				,@command*
				(loop ,@step*))))))
		  (loop ,@init*)))
	    (stx-error stx "invalid bindings"))))))))


;;;; module non-core-macro-transformer: RETURN, CONTINUE, BREAK, WHILE, UNTIL, FOR

(define (return-macro expr-stx)
  (syntax-match expr-stx ()
    ((_)
     (bless
      (lambda (stx)
	(syntax-error 'return "syntax \"return\" out of context"))))))

(define (continue-macro expr-stx)
  (syntax-match expr-stx ()
    ((_)
     (bless
      (lambda (stx)
	(syntax-error 'continue "syntax \"continue\" out of any loop"))))))

(define (break-macro expr-stx)
  (syntax-match expr-stx ()
    ((_)
     (bless
      (lambda (stx)
	(syntax-error 'break "syntax \"continue\" out of any loop"))))))

(define (while-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?test ?body* ...)
     (bless
      `(call/cc
	   (lambda (escape)
	     (let loop ()
	       (fluid-let-syntax ((break    (syntax-rules ()
					      ((_ . ?args)
					       (escape . ?args))))
				  (continue (lambda (stx) #'(loop))))
		 (if ,?test
		     (begin ,@?body* (loop))
		   (escape))))))))
    ))

(define (until-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?test ?body* ...)
     (bless
      `(call/cc
	   (lambda (escape)
	     (let loop ()
	       (fluid-let-syntax ((break    (syntax-rules ()
					      ((_ . ?args)
					       (escape . ?args))))
				  (continue (lambda (stx) #'(loop))))
		 (if ,?test
		     (escape)
		   (begin ,@?body* (loop)))))))))
    ))

(define (for-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ (?init ?test ?incr) ?body* ...)
     (bless
      `(call/cc
	   (lambda (escape)
	     ,?init
	     (let loop ()
	       (fluid-let-syntax ((break    (syntax-rules ()
					      ((_ . ?args)
					       (escape . ?args))))
				  (continue (lambda (stx) #'(loop))))
		 (if ,?test
		     (begin
		       ,@?body* ,?incr
		       (loop))
		   (escape))))))))
    ))


;;;; module non-core-macro-transformer: DEFINE-RETURNABLE, LAMBDA-RETURNABLE

(define (define-returnable-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ (?name . ?formals) ?body0 ?body* ...)
     (bless
      `(define (,?name . ,?formals)
	 (call/cc
	     (lambda (escape)
	       (fluid-let-syntax ((return (syntax-rules ()
					    ((_ . ?args)
					     (escape . ?args)))))
		 ,?body0 ,@?body*))))))
    ))

(define (lambda-returnable-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?formals ?body0 ?body* ...)
     (bless
      `(lambda ,?formals
	 (call/cc
	     (lambda (escape)
	       (fluid-let-syntax ((return (syntax-rules ()
					    ((_ . ?args)
					     (escape . ?args)))))
		 ,?body0 ,@?body*))))))
    ))

(define (begin-returnable-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?body0 ?body* ...)
     (bless
      `(call/cc
	   (lambda (escape)
	     (fluid-let-syntax ((return (syntax-rules ()
					  ((_ . ?args)
					   (escape . ?args)))))
	       ,?body0 ,@?body*)))))
    ))


;;;; module non-core-macro-transformer: OR, AND

(define or-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_) #f)
      ((_ e e* ...)
       (bless
	(let f ((e e) (e* e*))
	  (cond
	   ((null? e*) `(begin #f ,e))
	   (else
	    `(let ((t ,e))
	       (if t t ,(f (car e*) (cdr e*))))))))))))

(define and-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_) #t)
      ((_ e e* ...)
       (bless
	(let f ((e e) (e* e*))
	  (cond
	   ((null? e*) `(begin #f ,e))
	   (else `(if ,e ,(f (car e*) (cdr e*)) #f)))))))))


;;;; module non-core-macro-transformer: COND

(define cond-macro
  (lambda (stx)
    (syntax-match stx ()
      ((_ cls cls* ...)
       (bless
	(let f ((cls cls) (cls* cls*))
	  (cond
	   ((null? cls*)
	    (syntax-match cls (else =>)
	      ((else e e* ...) `(let () #f ,e . ,e*))
	      ((e => p) `(let ((t ,e)) (if t (,p t))))
	      ((e) `(or ,e (if #f #f)))
	      ((e e* ...) `(if ,e (begin . ,e*)))
	      (_ (stx-error stx "invalid last clause"))))
	   (else
	    (syntax-match cls (else =>)
	      ((else e e* ...) (stx-error stx "incorrect position of keyword else"))
	      ((e => p) `(let ((t ,e)) (if t (,p t) ,(f (car cls*) (cdr cls*)))))
	      ((e) `(or ,e ,(f (car cls*) (cdr cls*))))
	      ((e e* ...) `(if ,e (begin . ,e*) ,(f (car cls*) (cdr cls*))))
	      (_ (stx-error stx "invalid last clause")))))))))))


;;;; module non-core-macro-transformer: QUASIQUOTE

(define quasiquote-macro
  (let ()
    (define (datum x)
      (list (scheme-stx 'quote) (mkstx x top-mark* '() '())))
    (define-syntax app
      (syntax-rules (quote)
	((_ 'x arg* ...)
	 (list (scheme-stx 'x) arg* ...))))
    (define-syntax app*
      (syntax-rules (quote)
	((_ 'x arg* ... last)
	 (cons* (scheme-stx 'x) arg* ... last))))
    (define quasicons*
      (lambda (x y)
	(let f ((x x))
	  (if (null? x) y (quasicons (car x) (f (cdr x)))))))
    (define quasicons
      (lambda (x y)
	(syntax-match y (quote list)
	  ((quote dy)
	   (syntax-match x (quote)
	     ((quote dx) (app 'quote (cons dx dy)))
	     (_
	      (syntax-match dy ()
		(() (app 'list x))
		(_  (app 'cons x y))))))
	  ((list stuff ...)
	   (app* 'list x stuff))
	  (_ (app 'cons x y)))))
    (define quasiappend
      (lambda (x y)
	(let ((ls (let f ((x x))
		    (if (null? x)
			(syntax-match y (quote)
			  ((quote ()) '())
			  (_ (list y)))
		      (syntax-match (car x) (quote)
			((quote ()) (f (cdr x)))
			(_ (cons (car x) (f (cdr x)))))))))
	  (cond
	   ((null? ls) (app 'quote '()))
	   ((null? (cdr ls)) (car ls))
	   (else (app* 'append ls))))))
    (define quasivector
      (lambda (x)
	(let ((pat-x x))
	  (syntax-match pat-x (quote)
	    ((quote (x* ...)) (app 'quote (list->vector x*)))
	    (_ (let f ((x x) (k (lambda (ls) (app* 'vector ls))))
		 (syntax-match x (quote list cons)
		   ((quote (x* ...))
		    (k (map (lambda (x) (app 'quote x)) x*)))
		   ((list x* ...)
		    (k x*))
		   ((cons x y)
		    (f y (lambda (ls) (k (cons x ls)))))
		   (_ (app 'list->vector pat-x)))))))))
    (define vquasi
      (lambda (p lev)
	(syntax-match p ()
	  ((p . q)
	   (syntax-match p (unquote unquote-splicing)
	     ((unquote p ...)
	      (if (= lev 0)
		  (quasicons* p (vquasi q lev))
		(quasicons
		 (quasicons (datum 'unquote)
			    (quasi p (- lev 1)))
		 (vquasi q lev))))
	     ((unquote-splicing p ...)
	      (if (= lev 0)
		  (quasiappend p (vquasi q lev))
		(quasicons
		 (quasicons
		  (datum 'unquote-splicing)
		  (quasi p (- lev 1)))
		 (vquasi q lev))))
	     (p (quasicons (quasi p lev) (vquasi q lev)))))
	  (() (app 'quote '())))))
    (define quasi
      (lambda (p lev)
	(syntax-match p (unquote unquote-splicing quasiquote)
	  ((unquote p)
	   (if (= lev 0)
	       p
	     (quasicons (datum 'unquote) (quasi (list p) (- lev 1)))))
	  (((unquote p ...) . q)
	   (if (= lev 0)
	       (quasicons* p (quasi q lev))
	     (quasicons
	      (quasicons (datum 'unquote)
			 (quasi p (- lev 1)))
	      (quasi q lev))))
	  (((unquote-splicing p ...) . q)
	   (if (= lev 0)
	       (quasiappend p (quasi q lev))
	     (quasicons
	      (quasicons (datum 'unquote-splicing)
			 (quasi p (- lev 1)))
	      (quasi q lev))))
	  ((quasiquote p)
	   (quasicons (datum 'quasiquote)
		      (quasi (list p) (+ lev 1))))
	  ((p . q) (quasicons (quasi p lev) (quasi q lev)))
	  (#(x ...) (not (<stx>? x)) (quasivector (vquasi x lev)))
	  (p (app 'quote p)))))
    (lambda (x)
      (syntax-match x ()
	((_ e) (quasi e 0))))))


;;;; module non-core-macro-transformer: QUASISYNTAX

(define quasisyntax-macro
  (let () ;;; FIXME: not really correct
    (define quasi
      (lambda (p lev)
	(syntax-match p (unsyntax unsyntax-splicing quasisyntax)
	  ((unsyntax p)
	   (if (= lev 0)
	       (let ((g (gensym)))
		 (values (list g) (list p) g))
	     (let-values (((lhs* rhs* p) (quasi p (- lev 1))))
	       (values lhs* rhs* (list 'unsyntax p)))))
	  (unsyntax
	   (= lev 0)
	   (stx-error p "incorrect use of unsyntax"))
	  (((unsyntax p* ...) . q)
	   (let-values (((lhs* rhs* q) (quasi q lev)))
	     (if (= lev 0)
		 (let ((g* (map (lambda (x) (gensym)) p*)))
		   (values
		    (append g* lhs*)
		    (append p* rhs*)
		    (append g* q)))
	       (let-values (((lhs2* rhs2* p*) (quasi p* (- lev 1))))
		 (values
		  (append lhs2* lhs*)
		  (append rhs2* rhs*)
		  `((unsyntax . ,p*) . ,q))))))
	  (((unsyntax-splicing p* ...) . q)
	   (let-values (((lhs* rhs* q) (quasi q lev)))
	     (if (= lev 0)
		 (let ((g* (map (lambda (x) (gensym)) p*)))
		   (values
		    (append
		     (map (lambda (g) `(,g ...)) g*)
		     lhs*)
		    (append p* rhs*)
		    (append
		     (apply append
			    (map (lambda (g) `(,g ...)) g*))
		     q)))
	       (let-values (((lhs2* rhs2* p*) (quasi p* (- lev 1))))
		 (values
		  (append lhs2* lhs*)
		  (append rhs2* rhs*)
		  `((unsyntax-splicing . ,p*) . ,q))))))
	  (unsyntax-splicing (= lev 0)
			     (stx-error p "incorrect use of unsyntax-splicing"))
	  ((quasisyntax p)
	   (let-values (((lhs* rhs* p) (quasi p (+ lev 1))))
	     (values lhs* rhs* `(quasisyntax ,p))))
	  ((p . q)
	   (let-values (((lhs* rhs* p) (quasi p lev))
			((lhs2* rhs2* q) (quasi q lev)))
	     (values (append lhs2* lhs*)
		     (append rhs2* rhs*)
		     (cons p q))))
	  (#(x* ...)
	   (let-values (((lhs* rhs* x*) (quasi x* lev)))
	     (values lhs* rhs* (list->vector x*))))
	  (_ (values '() '() p)))))
    (lambda (x)
      (syntax-match x ()
	((_ e)
	 (let-values (((lhs* rhs* v) (quasi e 0)))
	   (bless
	    `(syntax-case (list ,@rhs*) ()
	       (,lhs* (syntax ,v))))))))))


;;;; module non-core-macro-transformer: DEFINE-VALUES, DEFINE-CONSTANT-VALUES

(define (define-values-macro expr-stx)
  ;;Transformer function  used to  expand Vicare's  DEFINE-VALUES macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ (?var* ... ?var0) ?form* ... ?form0)
     (let ((TMP* (generate-temporaries ?var*)))
       (bless
	`(begin
	   ;;We must make sure that the ?FORMs do not capture the ?VARs.
	   (define (return-multiple-values)
	     ,@?form* ,?form0)
	   ,@(map (lambda (var)
		    `(define ,var #f))
	       ?var*)
	   (define ,?var0
	     (call-with-values
		 return-multiple-values
	       (lambda (,@TMP* T0)
		 ,@(map (lambda (var TMP)
			  `(set! ,var ,TMP))
		     ?var* TMP*)
		 T0)))
	   ))))
    ))

(define (define-constant-values-macro expr-stx)
  ;;Transformer function used  to expand Vicare's DEFINE-CONSTANT-VALUES
  ;;macros from the top-level built in environment.  Expand the contents
  ;;of EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ (?var* ... ?var0) ?form* ... ?form0)
     (let ((SHADOW* (generate-temporaries ?var*))
	   (TMP*    (generate-temporaries ?var*)))
       (bless
	`(begin
	   (define (return-multiple-values)
	     ,@?form* ,?form0)
	   ,@(map (lambda (SHADOW)
		    `(define ,SHADOW #f))
	       SHADOW*)
	   (define SHADOW0
	     (call-with-values
		 return-multiple-values
	       (lambda (,@TMP* T0)
		 ,@(map (lambda (SHADOW TMP)
			  `(set! ,SHADOW ,TMP))
		     SHADOW* TMP*)
		 T0)))
	   ,@(map (lambda (var SHADOW)
		    `(define-syntax ,var
		       (identifier-syntax ,SHADOW)))
	       ?var* SHADOW*)
	   (define-syntax ,?var0
	     (identifier-syntax SHADOW0))
	   ))))
    ))


;;;; module non-core-macro-transformer: RECEIVE, RECEIVE-AND-RETURN, BEGIN0, XOR

(define (receive-macro expr-stx)
  ;;Transformer function used to expand Vicare's RECEIVE macros from the
  ;;top-level built  in environment.   Expand the contents  of EXPR-STX.
  ;;Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?formals ?producer-expression ?form0 ?form* ...)
     (bless
      `(call-with-values
	   (lambda () ,?producer-expression)
	 (lambda ,?formals ,?form0 ,@?form*))))
    ))

(define (receive-and-return-macro expr-stx)
  ;;Transformer  function  used  to expand  Vicare's  RECEIVE-AND-RETURN
  ;;macros from the top-level built in environment.  Expand the contents
  ;;of EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ (?retval* ...) ?producer-expression ?body0 ?body* ...)
     (bless
      `(call-with-values
	   (lambda () ,?producer-expression)
	 (lambda ,?retval*
	   ,?body0 ,@?body*
	   (values ,@?retval*)))))
    ))

(define (begin0-macro expr-stx)
  ;;Transformer function used to expand  Vicare's BEGIN0 macros from the
  ;;top-level built  in environment.   Expand the contents  of EXPR-STX.
  ;;Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?form0 ?form* ...)
     (bless
      `(call-with-values
	   (lambda () ,?form0)
	 (lambda args
	   ,@?form*
	   (apply values args)))))
    ))

(module (xor-macro)

  (define (xor-macro expr-stx)
    (syntax-match expr-stx ()
      ((_ ?expr* ...)
       (bless (%xor-aux #f ?expr*)))
      ))

  (define (%xor-aux bool/var expr*)
    (cond ((null? expr*)
	   bool/var)
	  ((null? (cdr expr*))
	   `(let ((x ,(car expr*)))
	      (if ,bool/var
		  (and (not x) ,bool/var)
		x)))
	  (else
	   `(let ((x ,(car expr*)))
	      (and (or (not ,bool/var)
		       (not x))
		   (let ((n (or ,bool/var x)))
		     ,(%xor-aux 'n (cdr expr*))))))))

  #| end of module: XOR-MACRO |# )


;;;; module non-core-macro-transformer: DEFINE-INLINE, DEFINE-CONSTANT

(define (define-constant-macro expr-stx)
  (syntax-match expr-stx ()
    ((_ ?name ?expr)
     (bless
      `(begin
	 (define ghost ,?expr)
	 (define-syntax ,?name
	   (identifier-syntax ghost)))))
    ))

(define (define-inline-constant-macro expr-stx)
  ;;Transformer function used  to expand Vicare's DEFINE-INLINE-CONSTANT
  ;;macros from the top-level built in environment.  Expand the contents
  ;;of EXPR-STX.  Return a sexp in the core language.
  ;;
  ;;We want to allow a generic expression to generate the constant value
  ;;at expand time.
  ;;
  (syntax-match expr-stx ()
    ((_ ?name ?expr)
     (bless
      `(define-syntax ,?name
	 (let ((const ,?expr))
	   (lambda (stx)
	     (syntax-case stx ()
	       (?id
		(identifier? #'?id)
		#`(quote #,const))))))))
    ))

(define (define-inline-macro expr-stx)
  ;;Transformer function  used to  expand Vicare's  DEFINE-INLINE macros
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ (?name ?arg* ... . ?rest) ?form0 ?form* ...)
     (and (identifier? ?name)
	  (for-all identifier? ?arg*)
	  (or (null? (syntax->datum ?rest))
	      (identifier? ?rest)))
     (let ((TMP* (generate-temporaries ?arg*)))
       (bless
	`(define-fluid-syntax ,?name
	   (syntax-rules ()
	     ((_ ,@TMP* . rest)
	      (fluid-let-syntax
		  ((,?name (lambda (stx)
			     (syntax-violation (quote ,?name)
			       "cannot recursively expand inline expression"
			       stx))))
		(let ,(append (map list ?arg* TMP*)
			      (if (null? (syntax->datum ?rest))
				  '()
				`((,?rest (list . rest)))))
		  ,?form0 ,@?form*))))))))
    ))


;;;; module non-core-macro-transformer: INCLUDE

(module (include-macro)
  ;;Transformer function used to expand Vicare's INCLUDE macros from the
  ;;top-level built  in environment.   Expand the contents  of EXPR-STX.
  ;;Return a sexp in the core language.
  ;;
  (define-constant __who__ 'include)

  (define (include-macro expr-stx)
    (define (%synner message subform)
      (syntax-violation __who__ message expr-stx subform))
    (syntax-match expr-stx ()
      ((?context ?filename)
       (%include-file ?filename ?context #f %synner))
      ((?context ?filename #t)
       (%include-file ?filename ?context #t %synner))
      ))

  (define (%include-file filename-stx context-id verbose? synner)
    (when verbose?
      (display (string-append "Vicare: searching include file: "
			      (syntax->datum filename-stx) "\n")
	       (current-error-port)))
    (let ((pathname (%filename-stx->pathname filename-stx synner)))
      (when verbose?
	(display (string-append "Vicare: including file: " pathname "\n")
		 (current-error-port)))
      (bless
       `(stale-when (let ()
		      (import (only (vicare $posix)
				    file-modification-time))
		      (or (not (file-exists? ,pathname))
			  (> (file-modification-time ,pathname)
			     ,(file-modification-time pathname))))
	  ,@(%read-content context-id pathname)))))

  (define (%filename-stx->pathname filename-stx synner)
    ;;Convert  the  string  FILENAME  into the  string  pathname  of  an
    ;;existing file; return the pathname.
    ;;
    (define filename
      (syntax->datum filename-stx))
    (unless (and (string? filename)
		 (not (fxzero? (string-length filename))))
      (synner "file name must be a nonempty string" filename-stx))
    (if (char=? (string-ref filename 0) #\/)
	;;It is an absolute pathname.
	(real-pathname filename)
      ;;It is a relative pathname.  Search the file in the library path.
      (let loop ((ls (library-path)))
	(if (null? ls)
	    (synner "file does not exist in library path" filename-stx)
	  (let ((ptn (string-append (car ls) "/" filename)))
	    (if (file-exists? ptn)
		(real-pathname ptn)
	      (loop (cdr ls))))))))

  (define (%read-content context-id pathname)
    ;;Open the  file PATHNAME, read all  the datums and convert  them to
    ;;syntax object  in the  lexical context  of CONTEXT-ID;  return the
    ;;resulting syntax object.
    ;;
    (with-exception-handler
	(lambda (E)
	  (raise-continuable (condition (make-who-condition __who__) E)))
      (lambda ()
	(with-input-from-file pathname
	  (lambda ()
	    (let recur ()
	      (let ((datum (get-annotated-datum (current-input-port))))
		(if (eof-object? datum)
		    '()
		  (cons (datum->syntax context-id datum)
			(recur))))))))))

  #| end of module: INCLUDE-MACRO |# )


;;;; module non-core-macro-transformer: DEFINE-INTEGRABLE

(define (define-integrable-macro expr-stx)
  ;;The original  syntax was  posted by "leppie"  on the  Ikarus mailing
  ;;list; subject "Macro Challenge of Last Year [Difficulty: *****]", 20
  ;;Oct 2009.
  ;;
  (syntax-match expr-stx (lambda)
    ((_ (?name . ?formals) ?form0 ?form* ...)
     (identifier? ?name)
     (bless
      `(define-integrable ,?name (lambda ,?formals ,?form0 ,@?form*))))

    ((_ ?name (lambda ?formals ?form0 ?form* ...))
     (identifier? ?name)
     (bless
      `(begin
	 (define-fluid-syntax ,?name
	   (lambda (x)
	     (syntax-case x ()
	       (_
		(identifier? x)
		#'xname)

	       ((_ arg ...)
		#'((fluid-let-syntax
		       ((,?name (identifier-syntax xname)))
		     (lambda ,?formals ,?form0 ,@?form*))
		   arg ...)))))
	 (define xname
	   (fluid-let-syntax ((,?name (identifier-syntax xname)))
	     (lambda ,?formals ,?form0 ,@?form*)))
	 )))
    ))


;;;; module non-core-macro-transformer: miscellanea

(define (time-macro stx)
  (syntax-match stx ()
    ((_ expr)
     (let ((str (receive (port getter)
		    (open-string-output-port)
		  (write (syntax->datum expr) port)
		  (getter))))
       (bless `(time-it ,str (lambda () ,expr)))))))

(define (delay-macro stx)
  (syntax-match stx ()
    ((_ expr)
     (bless
      `(make-promise (lambda () ,expr))))))

(define (assert-macro stx)
  ;;Defined by R6RS.  An ASSERT  form is evaluated by evaluating EXPR.
  ;;If  EXPR returns a  true value,  that value  is returned  from the
  ;;ASSERT  expression.   If EXPR  returns  false,  an exception  with
  ;;condition  types  "&assertion"  and  "&message"  is  raised.   The
  ;;message  provided  in   the  condition  object  is  implementation
  ;;dependent.
  ;;
  ;;NOTE  Implementations should  exploit the  fact that  ASSERT  is a
  ;;syntax  to  provide as  much  information  as  possible about  the
  ;;location of the assertion failure.
  ;;
  (syntax-match stx ()
    ((_ expr)
     (let ((pos (or (expression-position stx)
		    (expression-position expr))))
       (bless
	(if (source-position-condition? pos)
	    `(or ,expr
		 (assertion-error
		  ',expr ,(source-position-port-id pos)
		  ,(source-position-byte pos) ,(source-position-character pos)
		  ,(source-position-line pos) ,(source-position-column    pos)))
	  `(or ,expr
	       (assertion-error ',expr "unknown source" #f #f #f #f))))))))

(define (file-options-macro expr-stx)
  ;;Transformer for  the FILE-OPTIONS macro.  File  options selection is
  ;;implemented   as   an   enumeration  type   whose   constructor   is
  ;;MAKE-FILE-OPTIONS from the boot environment.
  ;;
  (define (valid-option? opt-stx)
    (and (identifier? opt-stx)
	 (memq (identifier->symbol opt-stx) '(no-fail no-create no-truncate))))
  (syntax-match expr-stx ()
    ((_ ?opt* ...)
     (for-all valid-option? ?opt*)
     (bless `(make-file-options ',?opt*)))))

(define (endianness-macro expr-stx)
  ;;Transformer of  ENDIANNESS.  Support  the symbols:  "big", "little",
  ;;"network", "native"; convert "network" to "big".
  ;;
  (syntax-match expr-stx ()
    ((_ ?name)
     (and (identifier? ?name)
	  (memq (identifier->symbol ?name) '(big little network native)))
     (case (identifier->symbol ?name)
       ((network)
	(bless '(quote big)))
       ((native)
	(bless '(native-endianness)))
       ((big little)
	(bless `(quote ,?name)))))))

(define (%allowed-symbol-macro expr-stx allowed-symbol-set)
  ;;Helper  function used  to  implement the  transformer of:  EOL-STYLE
  ;;ERROR-HANDLING-MODE, BUFFER-MODE,  ENDIANNESS.  All of  these macros
  ;;should expand to a quoted symbol among a list of allowed ones.
  ;;
  (syntax-match expr-stx ()
    ((_ ?name)
     (and (identifier? ?name)
	  (memq (identifier->symbol ?name) allowed-symbol-set))
     (bless `(quote ,?name)))))


;;; end of module: NON-CORE-MACRO-TRANSFORMER

)


(module (core-macro-transformer
	 splice-first-envelope?
	 splice-first-envelope-form)
  ;;We distinguish between "non-core macros" and "core macros".
  ;;
  ;;Core macros  are part of the  core language: they cannot  be further
  ;;expanded to a  composition of other more basic  macros.  Core macros
  ;;*do*  introduce bindings,  so their  transformer functions  take the
  ;;lexical environments as arguments.
  ;;
  ;;Non-core macros are  *not* part of the core language:  they *can* be
  ;;expanded to  a composition of  core macros.  Non-core macros  do not
  ;;introduce bindings, so their transformer functions do *not* take the
  ;;lexical environments as arguments.
  ;;
  ;;The function  CORE-MACRO-TRANSFORMER maps symbols  representing core
  ;;macros to  their macro transformers.   The expression returned  by a
  ;;core transformer is expressed in the core language and does not need
  ;;to be further processed.
  ;;
  ;;NOTE This  module is very  long, so it  is split into  multiple code
  ;;pages.  (Marco Maggi; Sat Apr 27, 2013)
  ;;
  (define* (core-macro-transformer name)
    (case name
      ((quote)				quote-transformer)
      ((lambda)				lambda-transformer)
      ((case-lambda)			case-lambda-transformer)
      ((letrec)				letrec-transformer)
      ((letrec*)			letrec*-transformer)
      ((if)				if-transformer)
      ((foreign-call)			foreign-call-transformer)
      ((syntax-case)			syntax-case-transformer)
      ((syntax)				syntax-transformer)
      ((type-descriptor)		type-descriptor-transformer)
      ((record-type-descriptor)		record-type-descriptor-transformer)
      ((record-constructor-descriptor)	record-constructor-descriptor-transformer)
      ((record-type-field-set!)		record-type-field-set!-transformer)
      ((record-type-field-ref)		record-type-field-ref-transformer)
      (($record-type-field-set!)	$record-type-field-set!-transformer)
      (($record-type-field-ref)		$record-type-field-ref-transformer)
      ((splice-first-expand)		splice-first-expand-transformer)
      ((fluid-let-syntax)		fluid-let-syntax-transformer)
      (else
       (assertion-violation __who__
	 "Vicare: internal error: cannot find transformer" name))))


;;;; module core-macro-transformer: LETREC and LETREC*

(module (letrec-transformer letrec*-transformer)

  (define (letrec-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer  function  used to  expand  LETREC  syntaxes from  the
    ;;top-level built  in environment.  Expand the  contents of EXPR-STX
    ;;in  the  context  of   the  lexical  environments  LEXENV.RUN  and
    ;;LEXENV.EXPAND; return a sexp  representing EXPR-STX fully expanded
    ;;to the core language.
    ;;
    (%letrec-helper expr-stx lexenv.run lexenv.expand build-letrec))

  (define (letrec*-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer  function used  to  expand LETREC*  syntaxes from  the
    ;;top-level built  in environment.  Expand the  contents of EXPR-STX
    ;;in  the  context  of   the  lexical  environments  LEXENV.RUN  and
    ;;LEXENV.EXPAND; return a sexp  representing EXPR-STX fully expanded
    ;;to the core language.
    ;;
    (%letrec-helper expr-stx lexenv.run lexenv.expand build-letrec*))

  (define (%letrec-helper expr-stx lexenv.run lexenv.expand core-lang-builder)
    (syntax-match expr-stx ()
      ((_ ((?lhs* ?rhs*) ...) ?body ?body* ...)
       ;;Check  that  the  binding  names are  identifiers  and  without
       ;;duplicates.
       (if (not (valid-bound-ids? ?lhs*))
	   (%error-invalid-formals-syntax expr-stx ?lhs*)
	 ;;Generate  unique variable  names  and labels  for the  LETREC
	 ;;bindings.
	 (let ((lex* (map gensym-for-lexical-var ?lhs*))
	       (lab* (map gensym-for-label       ?lhs*)))
	   ;;Generate  what is  needed to  create a  lexical contour:  a
	   ;;<RIB>  and  an extended  lexical  environment  in which  to
	   ;;evaluate both the right-hand sides and the body.
	   ;;
	   ;;Notice that the region of  all the LETREC bindings includes
	   ;;all the right-hand sides.
	   (let ((rib        (make-full-rib ?lhs* lab*))
		 (lexenv.run (add-lexical-bindings lab* lex* lexenv.run)))
	     ;;Create  the   lexical  contour  then  process   body  and
	     ;;right-hand sides of bindings.
	     (let ((body (chi-internal-body (push-lexical-contour rib (cons ?body ?body*))
					    lexenv.run lexenv.expand))
		   (rhs* (chi-expr*    (map (lambda (rhs)
					      (push-lexical-contour rib rhs))
					 ?rhs*)
				       lexenv.run lexenv.expand)))
	       ;;Build  the LETREC  or  LETREC* expression  in the  core
	       ;;language.
	       (core-lang-builder no-source lex* rhs* body))))))))

  #| end of module |# )


;;;; module core-macro-transformer: FLUID-LET-SYNTAX

(define (fluid-let-syntax-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer function  used to expand FLUID-LET-SYNTAX  syntaxes from
  ;;the top-level built in environment.  Expand the contents of EXPR-STX
  ;;in  the   context  of   the  lexical  environments   LEXENV.RUN  and
  ;;LEXENV.EXPAND; return a sexp representing EXPR-STX fully expanded to
  ;;the core language.
  ;;
  (define (transformer expr-stx)
    (syntax-match expr-stx ()
      ((_ ((?lhs* ?rhs*) ...) ?body ?body* ...)
       ;;Check that the ?LHS* are all identifiers with no duplicates.
       (if (not (valid-bound-ids? ?lhs*))
	   (%error-invalid-formals-syntax expr-stx ?lhs*)
	 (let ((label*       (map %lookup-binding-in-run-lexenv ?lhs*))
	       (rhs-binding* (map (lambda (rhs)
				    (%eval-macro-transformer
				     (%expand-macro-transformer rhs lexenv.expand)))
			       ?rhs*)))
	   (chi-internal-body (cons ?body ?body*)
			      (append (map cons label* rhs-binding*) lexenv.run)
			      (append (map cons label* rhs-binding*) lexenv.expand)))))))

  (define (%lookup-binding-in-run-lexenv lhs)
    ;;Search  the  binding of  the  identifier  LHS in  LEXENV.RUN,  the
    ;;environment for run;  if present and of type  fluid syntax: return
    ;;the associated label.
    ;;
    (let* ((label    (or (id->label lhs)
			 (%synner "unbound identifier" lhs)))
	   (binding  (label->syntactic-binding/no-fluids label lexenv.run)))
      (cond ((fluid-syntax-binding? binding)
	     (syntactic-binding-value binding))
	    (else
	     (%synner "not a fluid identifier" lhs)))))

  (define (%synner message subform)
    (stx-error subform message))

  (transformer expr-stx))


;;;; module core-macro-transformer: TYPE-DESCRIPTOR

(define (type-descriptor-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer  function   used  to  expand   Vicare's  TYPE-DESCRIPTOR
  ;;syntaxes  from  the  top-level  built in  environment.   Expand  the
  ;;contents  of EXPR-STX  in the  context of  the lexical  environments
  ;;LEXENV.RUN and LEXENV.EXPAND, the result must be a single identifier
  ;;representing a Vicare struct type.   Return a sexp evaluating to the
  ;;struct type descriptor.
  ;;
  ;;The binding in the lexical  environment representing the struct type
  ;;descriptor looks as follows:
  ;;
  ;;   ($rtd . #<type-descriptor-struct>)
  ;;    |..| binding-type
  ;;           |.......................|  binding-value
  ;;   |................................| binding
  ;;
  ;;where "$rtd" is the symbol "$rtd".
  ;;
  (define-constant __who__ 'type-descriptor)
  (define (%struct-type-descriptor-binding? binding)
    (and (eq? '$rtd (syntactic-binding-type binding))
	 (not (list? (syntactic-binding-value binding)))))
  (syntax-match expr-stx ()
    ((_ ?identifier)
     (identifier? ?identifier)
     (let ((label (id->label ?identifier)))
       (unless label
	 (%raise-unbound-error __who__ expr-stx ?identifier))
       (let ((binding (label->syntactic-binding label lexenv.run)))
	 (unless (%struct-type-descriptor-binding? binding)
	   (syntax-violation __who__ "not a struct type" expr-stx ?identifier))
	 (build-data no-source (syntactic-binding-value binding)))))))


;;;; module core-macro-transformer: RECORD-{TYPE,CONSTRUCTOR}-DESCRIPTOR-TRANSFORMER

(module (record-type-descriptor-transformer
	 record-constructor-descriptor-transformer
	 record-type-field-set!-transformer
	 record-type-field-ref-transformer
	 $record-type-field-set!-transformer
	 $record-type-field-ref-transformer)
  ;;The entry  in the lexical  environment representing the  record type
  ;;and constructor descriptors looks as follows:
  ;;
  ;;   ($rtd . (?rtd-id ?rcd-id))
  ;;    |..| binding-type
  ;;           |...............| binding-value
  ;;   |.......................| binding
  ;;
  ;;where  "$rtd" is  the symbol  "$rtd", ?RTD-ID  is the  identifier to
  ;;which the record type descriptor is bound, ?RCD-ID is the identifier
  ;;to which the default record constructor descriptor is bound.
  ;;
  ;;Optionally 2 or 4 additional fields are present:
  ;;
  ;;   ($rtd . (?rtd-id ?rcd-id
  ;;            ?safe-accessors-alist ?safe-mutators-alist))
  ;;
  ;;   ($rtd . (?rtd-id ?rcd-id
  ;;            ?safe-accessors-alist ?safe-mutators-alist
  ;;            ?unsafe-accessors-alist ?unsafe-mutators-alist))
  ;;
  ;;in which:
  ;;
  ;;*  ?SAFE-ACCESSORS-ALIST   is  an  alist  whose   keys  are  symbols
  ;;representing  all  the   field  names  and  whose   values  are  the
  ;;identifiers bound to the corresponding safe field accessors.
  ;;
  ;;*  ?SAFE-FIELD-MUTATORS   is  an   alist  whose  keys   are  symbols
  ;;representing  the   mutable  field   names  and  whose   values  are
  ;;identifiers bound to the corresponding safe field mutators.
  ;;
  ;;*  ?UNSAFE-ACCESSORS-ALIST  is  an  alist  whose  keys  are  symbols
  ;;representing  all  the   field  names  and  whose   values  are  the
  ;;identifiers bound to the corresponding safe unfield accessors.
  ;;
  ;;*  ?UNSAFE-FIELD-MUTATORS  is  an   alist  whose  keys  are  symbols
  ;;representing  the   mutable  field   names  and  whose   values  are
  ;;identifiers bound to the corresponding unsafe field mutators.
  ;;
  (define (%record-type-descriptor-binding? binding)
    (and (eq? '$rtd (syntactic-binding-type binding))
	 (list? (syntactic-binding-value binding))))

  (define (record-type-descriptor-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer function used  to expand R6RS's RECORD-TYPE-DESCRIPTOR
    ;;syntax uses from  the top-level built in  environment.  Expand the
    ;;contents of  EXPR-STX in the  context of the  lexical environments
    ;;LEXENV.RUN  and  LEXENV.EXPAND,  the   result  must  be  a  single
    ;;identifier  representing a  R6RS record  type.  Return  a symbolic
    ;;expression evaluating to the record type descriptor.
    ;;
    (define-constant __who__ 'record-type-descriptor)
    (syntax-match expr-stx ()
      ((_ ?identifier)
       (identifier? ?identifier)
       (let ((label (id->label ?identifier)))
	 (unless label
	   (%raise-unbound-error __who__ expr-stx ?identifier))
	 (let ((binding (label->syntactic-binding label lexenv.run)))
	   (unless (%record-type-descriptor-binding? binding)
	     (syntax-violation __who__ "not a record type" expr-stx ?identifier))
	   (chi-expr (car (syntactic-binding-value binding))
		     lexenv.run lexenv.expand))))))

  (define (record-constructor-descriptor-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer      function      used     to      expand      R6RS's
    ;;RECORD-CONSTRUCTOR-DESCRIPTOR syntax uses from the top-level built
    ;;in environment.  Expand the contents of EXPR-STX in the context of
    ;;the lexical environments LEXENV.RUN  and LEXENV.EXPAND, the result
    ;;must  be a  single  identifier representing  a  R6RS record  type.
    ;;Return a sexp evaluating to the record destructor descriptor.
    ;;
    (define-constant __who__ 'record-constructor-descriptor-transformer)
    (syntax-match expr-stx ()
      ((_ ?identifier)
       (identifier? ?identifier)
       (let ((label (id->label ?identifier)))
	 (unless label
	   (%raise-unbound-error __who__ expr-stx ?identifier))
	 (let ((binding (label->syntactic-binding label lexenv.run)))
	   (unless (%record-type-descriptor-binding? binding)
	     (syntax-error __who__ "invalid type" expr-stx ?identifier))
	   (chi-expr (cadr (syntactic-binding-value binding))
		     lexenv.run lexenv.expand))))))

;;; --------------------------------------------------------------------

  (define (record-type-field-ref-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer function  used to expand  R6RS's RECORD-TYPE-FIELD-REF
    ;;syntax uses from  the top-level built in  environment.  Expand the
    ;;contents of  EXPR-STX in the  context of the  lexical environments
    ;;LEXENV.RUN and  LEXENV.EXPAND.  Return  a core language  sexp that
    ;;accesses the value of a field from an R6RS record.
    ;;
    (define-constant __who__ 'record-type-field-ref)
    (syntax-match expr-stx ()
      ((_ ?type-name ?field-name ?record)
       (and (identifier? ?type-name)
	    (identifier? ?field-name))
       (let ((label (id->label ?type-name)))
	 (unless label
	   (%raise-unbound-error __who__ expr-stx ?type-name))
	 (let ((binding (label->syntactic-binding label lexenv.run)))
	   (unless (%record-type-descriptor-binding? binding)
	     (syntax-violation __who__ "not a record type" expr-stx ?type-name))
	   (let* ((table    (%get-alist-of-safe-field-accessors __who__ binding))
		  (accessor (assq (syntax->datum ?field-name) table)))
	     (unless accessor
	       (syntax-violation __who__ "unknown record field name" expr-stx ?field-name))
	     (chi-expr (bless `(,(cdr accessor) ,?record))
		       lexenv.run lexenv.expand)))))))

  (define (record-type-field-set!-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer function used  to expand R6RS's RECORD-TYPE-FIELD-SET!
    ;;syntax uses from  the top-level built in  environment.  Expand the
    ;;contents of  EXPR-STX in the  context of the  lexical environments
    ;;LEXENV.RUN  and LEXENV.EXPAND.   Return  core  language sexp  that
    ;;mutates the value of a field in an R6RS record.
    ;;
    (define-constant __who__ 'record-type-field-set!)
    (syntax-match expr-stx ()
      ((_ ?type-name ?field-name ?record ?new-value)
       (and (identifier? ?type-name)
	    (identifier? ?field-name))
       (let ((label (id->label ?type-name)))
	 (unless label
	   (%raise-unbound-error __who__ expr-stx ?type-name))
	 (let ((binding (label->syntactic-binding label lexenv.run)))
	   (unless (%record-type-descriptor-binding? binding)
	     (syntax-violation __who__ "not a record type" expr-stx ?type-name))
	   (let* ((table   (%get-alist-of-safe-field-mutators __who__ binding))
		  (mutator (assq (syntax->datum ?field-name) table)))
	     (unless mutator
	       (syntax-violation __who__ "unknown record field name or immutable field" expr-stx ?field-name))
	     (chi-expr (bless `(,(cdr mutator) ,?record ,?new-value))
		       lexenv.run lexenv.expand)))))))

  (define ($record-type-field-ref-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer function used  to expand R6RS's $RECORD-TYPE-FIELD-REF
    ;;syntax uses from  the top-level built in  environment.  Expand the
    ;;contents of  EXPR-STX in the  context of the  lexical environments
    ;;LEXENV.RUN and  LEXENV.EXPAND.  Return  a core language  sexp that
    ;;accesses the value of a field from an R6RS record using the unsafe
    ;;accessor.
    ;;
    (define-constant __who__ '$record-type-field-ref)
    (syntax-match expr-stx ()
      ((_ ?type-name ?field-name ?record)
       (and (identifier? ?type-name)
	    (identifier? ?field-name))
       (let ((label (id->label ?type-name)))
	 (unless label
	   (%raise-unbound-error __who__ expr-stx ?type-name))
	 (let ((binding (label->syntactic-binding label lexenv.run)))
	   (unless (%record-type-descriptor-binding? binding)
	     (syntax-violation __who__ "not a record type" expr-stx ?type-name))
	   (let* ((table    (%get-alist-of-unsafe-field-accessors __who__ binding))
		  (accessor (assq (syntax->datum ?field-name) table)))
	     (unless accessor
	       (syntax-violation __who__ "unknown record field name" expr-stx ?field-name))
	     (chi-expr (bless `(,(cdr accessor) ,?record))
		       lexenv.run lexenv.expand)))))))

  (define ($record-type-field-set!-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer function used to expand R6RS's $RECORD-TYPE-FIELD-SET!
    ;;syntax uses from  the top-level built in  environment.  Expand the
    ;;contents of  EXPR-STX in the  context of the  lexical environments
    ;;LEXENV.RUN and  LEXENV.EXPAND.  Return  a core language  sexp that
    ;;mutates the  value of a field  in an R6RS record  using the unsafe
    ;;mutator.
    ;;
    (define-constant __who__ '$record-type-field-set!)
    (syntax-match expr-stx ()
      ((_ ?type-name ?field-name ?record ?new-value)
       (and (identifier? ?type-name)
	    (identifier? ?field-name))
       (let ((label (id->label ?type-name)))
	 (unless label
	   (%raise-unbound-error __who__ expr-stx ?type-name))
	 (let ((binding (label->syntactic-binding label lexenv.run)))
	   (unless (%record-type-descriptor-binding? binding)
	     (syntax-violation __who__ "not a record type" expr-stx ?type-name))
	   (let* ((table   (%get-alist-of-unsafe-field-mutators __who__ binding))
		  (mutator (assq (syntax->datum ?field-name) table)))
	     (unless mutator
	       (syntax-violation __who__ "unknown record field name or immutable field" expr-stx ?field-name))
	     (chi-expr (bless `(,(cdr mutator) ,?record ,?new-value))
		       lexenv.run lexenv.expand)))))))

  (define (%get-alist-of-safe-field-accessors who binding)
    ;;Inspect a lexical  environment binding with key  "$rtd" and return
    ;;the alist  of safe R6RS record  field accessors.  If the  alist is
    ;;not present: raise a syntax violation.
    ;;
    (let ((val (syntactic-binding-value binding)))
      (if (<= 4 (length val))
	  (list-ref val 2)
	(syntax-violation who
	  "request for safe accessors of R6RS record for which they are not defined"
	  binding))))

  (define (%get-alist-of-safe-field-mutators who binding)
    ;;Inspect a lexical  environment binding with key  "$rtd" and return
    ;;the alist of safe R6RS record field mutators.  If the alist is not
    ;;present: raise a syntax violation.
    ;;
    (let ((val (syntactic-binding-value binding)))
      (if (<= 4 (length val))
	  (list-ref val 3)
	(syntax-violation who
	  "request for safe mutators of R6RS record for which they are not defined"
	  binding))))

  (define (%get-alist-of-unsafe-field-accessors who binding)
    ;;Inspect a lexical  environment binding with key  "$rtd" and return
    ;;the alist of unsafe R6RS record  field accessors.  If the alist is
    ;;not present: raise a syntax violation.
    ;;
    (let ((val (syntactic-binding-value binding)))
      (if (<= 6 (length val))
	  (list-ref val 4)
	(syntax-violation who
	  "request for unsafe accessors of R6RS record for which they are not defined"
	  binding))))

  (define (%get-alist-of-unsafe-field-mutators who binding)
    ;;Inspect a lexical  environment binding with key  "$rtd" and return
    ;;the alist of  unsafe R6RS record field mutators.  If  the alist is
    ;;not present: raise a syntax violation.
    ;;
    (let ((val (syntactic-binding-value binding)))
      (if (<= 6 (length val))
	  (list-ref val 5)
	(syntax-violation who
	  "request for unsafe mutators of R6RS record for which they are not defined"
	  binding))))

  #| end of module |# )


;;;; module core-macro-transformer: IF

(define (if-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  R6RS's IF  syntaxes from  the
  ;;top-level built in environment.  Expand  the contents of EXPR-STX in
  ;;the   context   of   the   lexical   environments   LEXENV.RUN   and
  ;;LEXENV.EXPAND.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?test ?consequent ?alternate)
     (build-conditional no-source
			(chi-expr ?test       lexenv.run lexenv.expand)
			(chi-expr ?consequent lexenv.run lexenv.expand)
			(chi-expr ?alternate  lexenv.run lexenv.expand)))
    ((_ ?test ?consequent)
     (build-conditional no-source
			(chi-expr ?test       lexenv.run lexenv.expand)
			(chi-expr ?consequent lexenv.run lexenv.expand)
			(build-void)))))


;;;; module core-macro-transformer: QUOTE

(define (quote-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer function used  to expand R6RS's QUOTE  syntaxes from the
  ;;top-level built in environment.  Expand  the contents of EXPR-STX in
  ;;the   context   of   the   lexical   environments   LEXENV.RUN   and
  ;;LEXENV.EXPAND.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?datum)
     (build-data no-source (syntax->datum ?datum)))))


;;;; module core-macro-transformer: LAMBDA and CASE-LAMBDA

(define (case-lambda-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand R6RS's CASE-LAMBDA syntaxes from
  ;;the top-level built in environment.  Expand the contents of EXPR-STX
  ;;in  the   context  of   the  lexical  environments   LEXENV.RUN  and
  ;;LEXENV.EXPAND.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ (?formals* ?body* ?body** ...) ...)
     (receive (formals* body*)
	 (chi-lambda-clause* expr-stx ?formals*
			     (map cons ?body* ?body**) lexenv.run lexenv.expand)
       (build-case-lambda (syntax-annotation expr-stx) formals* body*)))))

(define (lambda-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand  R6RS's LAMBDA syntaxes from the
  ;;top-level built in environment.  Expand  the contents of EXPR-STX in
  ;;the   context   of   the   lexical   environments   LEXENV.RUN   and
  ;;LEXENV.EXPAND.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?formals ?body ?body* ...)
     (receive (formals body)
	 (chi-lambda-clause expr-stx ?formals
			    (cons ?body ?body*) lexenv.run lexenv.expand)
       (build-lambda (syntax-annotation expr-stx) formals body)))))


;;;; module core-macro-transformer: FOREIGN-CALL

(define (foreign-call-transformer expr-stx lexenv.run lexenv.expand)
  ;;Transformer function  used to expand Vicare's  FOREIGN-CALL syntaxes
  ;;from the  top-level built  in environment.   Expand the  contents of
  ;;EXPR-STX in the  context of the lexical  environments LEXENV.RUN and
  ;;LEXENV.EXPAND.  Return a sexp in the core language.
  ;;
  (syntax-match expr-stx ()
    ((_ ?name ?arg* ...)
     (build-foreign-call no-source
       (chi-expr  ?name lexenv.run lexenv.expand)
       (chi-expr* ?arg* lexenv.run lexenv.expand)))))


;;;; module core-macro-transformer: SYNTAX

(module (syntax-transformer)
  ;;Transformer function used to expand  R6RS's SYNTAX syntaxes from the
  ;;top-level built in environment.  Process  the contents of USE-STX in
  ;;the   context   of   the   lexical   environments   LEXENV.RUN   and
  ;;LEXENV.EXPAND.
  ;;
  ;;According to R6RS, the use of the SYNTAX macro must have the format:
  ;;
  ;;  (syntax ?template)
  ;;
  ;;where ?TEMPLATE is one among:
  ;;
  ;;  ?datum
  ;;  ?pattern-variable
  ;;  ?id
  ;;  (?subtemplate ...)
  ;;  (?subtemplate ... . ?template)
  ;;  #(?subtemplate ...)
  ;;
  ;;in  which:  ?DATUM  is  a literal  datum,  ?PATTERN-VARIABLE  is  an
  ;;identifier referencing  a pattern  variable created  by SYNTAX-CASE,
  ;;?ID   is  an   identifier  not   referencing  a   pattern  variable,
  ;;?SUBTEMPLATE  is  a  template  followed by  zero  or  more  ellipsis
  ;;identifiers.
  ;;
  ;;Return a sexp representing  code in the core language
  ;;which, when evaluated, returns a  wrapped or unwrapped syntax object
  ;;containing an expression in which:
  ;;
  ;;* All the template identifiers being references to pattern variables
  ;;  are substituted with the corresponding syntax objects.
  ;;
  ;;     (syntax-case #'123 (?obj (syntax ?obj)))
  ;;     => #<syntax expr=123>
  ;;
  ;;     (syntax-case #'(1 2) ((?a ?b) (syntax #(?a ?b))))
  ;;     => #(#<syntax expr=1> #<syntax expr=1>)
  ;;
  ;;* All the identifiers not  being references to pattern variables are
  ;;  left  alone to  be captured  by the lexical  context at  the level
  ;;  below the current,  in the context of the SYNTAX  macro use or the
  ;;  context of the output form.
  ;;
  ;;     (syntax-case #'(1) ((?a) (syntax (display ?b))))
  ;;     => (#<syntax expr=display>
  ;;         #<syntax expr=1> . #<syntax expr=()>)
  ;;
  ;;* All the sub-templates followed by ellipsis are replicated to match
  ;;  the input pattern.
  ;;
  ;;     (syntax-case #'(1 2 3) ((?a ...) (syntax #(?a ...))))
  ;;     => #(1 2 3)
  ;;
  ;;About pattern variables:  they are present in  a lexical environment
  ;;as entries with format:
  ;;
  ;;   (?label . (syntax . (?name . ?level)))
  ;;
  ;;where:  ?LABEL  is the  label  in  the identifier's  syntax  object,
  ;;"syntax" is  the symbol "syntax",  ?NAME is the  symbol representing
  ;;the  name  of the  pattern  variable,  ?LEVEL  is an  exact  integer
  ;;representing the  nesting ellipsis level.  The  SYNTAX-CASE patterns
  ;;below will generate the given entries:
  ;;
  ;;   ?a			->  (syntax . (?a . 0))
  ;;   (?a)			->  (syntax . (?a . 0))
  ;;   (((?a)))			->  (syntax . (?a . 0))
  ;;   (?a ...)			->  (syntax . (?a . 1))
  ;;   ((?a) ...)		->  (syntax . (?a . 1))
  ;;   ((((?a))) ...)		->  (syntax . (?a . 1))
  ;;   ((?a ...) ...)		->  (syntax . (?a . 2))
  ;;   (((?a ...) ...) ...)	->  (syntax . (?a . 3))
  ;;
  ;;The  input template  is  first visited  in  post-order, building  an
  ;;intermediate  symbolic  representation  of  it;  then  the  symbolic
  ;;representation is visited in post-order, building core language code
  ;;that  evaluates  to  the   resulting  syntax  object.   Examples  of
  ;;intermediate  representation  (-->)  and  expansion  (==>)  follows,
  ;;assuming identifiers starting with "?"  are pattern variables:
  #|
      (syntax display)
      --> (quote #<syntax expr=display>)
      ==> (quote #<syntax expr=display>)

      (syntax (display 123))
      --> (quote #<syntax expr=(display 123)>)
      ==> (quote #<syntax expr=(display 123)>)

      (syntax ?a)
      --> (ref ?a)
      ==> ?a

      (syntax (?a))
      --> (cons (ref ?a) (quote #<syntax expr=()>))
      ==> ((primitive cons) ?a (quote #<syntax expr=()>))

      (syntax (?a 1))
      --> (cons (ref ?a) (quote #<syntax expr=(1)>))
      ==> ((primitive cons) ?a (quote #<syntax expr=(1)>))

      (syntax (1 ?a 2))
      --> (cons (quote #<syntax expr=1>)
                (cons (ref ?a) (quote #<syntax expr=(2)>)))
      ==> ((primitive cons)
	   (quote #<syntax expr=1>)
	   ((primitive cons) ?a (quote #<syntax expr=(2)>)))

      (syntax (display ?a))
      ==> (cons
	   (quote #<syntax expr=display>)
	   (cons (ref ?a) (quote #<syntax expr=()>)))
      ==> ((primitive cons)
	   (quote #<syntax expr=display>)
	   ((primitive cons) ?a (quote #<syntax expr=()>)))

      (syntax #(?a))
      --> (vector (ref ?a))
      ==> ((primitive vector) ?a)

      (syntax (?a ...))
      --> (ref ?a)
      ==> ?a

      (syntax ((?a ...) ...))
      --> (ref ?a)
      ==> ?a

      (syntax ((?a ?b ...) ...))
      -- (map (primitive cons) (ref ?a) (ref ?b))
      ==> ((primitive ellipsis-map) (primitive cons) ?a ?b)

      (syntax (((?a ?b ...) ...) ...))
      --> (map (lambda (tmp2 tmp1)
                 (map (primitive cons) tmp1 tmp2))
	    (ref ?b) (ref ?a))
      ==> ((primitive ellipsis-map)
	   (case-lambda
	    ((tmp2 tmp1)
	     ((primitive ellipsis-map) (primitive cons) tmp1 tmp2)))
           ?b ?a)

      (syntax ((?a (?a ...)) ...))
      --> (map (lambda (tmp)
                 (cons (ref tmp)
		       (cons (ref ?a)
			     (quote #<syntax expr=()>))))
            (ref ?a))
      ==> ((primitive ellipsis-map)
           (case-lambda
            ((tmp)
             ((primitive cons) tmp
	                       ((primitive cons) ?a
                                        	 (quote #<syntax expr=()>)))))
           ?a)
  |#
  (define (syntax-transformer use-stx lexenv.run lexenv.expand)
    (syntax-match use-stx ()
      ((_ ?template)
       (receive (intermediate-sexp maps)
	   (%gen-syntax use-stx ?template lexenv.run '() ellipsis? #f)
	 (let ((code (%generate-output-code intermediate-sexp)))
	   #;(debug-print 'syntax (syntax->datum ?template) intermediate-sexp code)
	   code)))))

  (define (%gen-syntax use-stx template-stx lexenv maps ellipsis? vec?)
    ;;Recursive function.  Expand the contents of a SYNTAX use.
    ;;
    ;;USE-STX must be  the syntax object containing  the original SYNTAX
    ;;macro use; it is used for descriptive error reporting.
    ;;
    ;;TEMPLATE-STX must be the template from the SYNTAX macro use.
    ;;
    ;;LEXENV is  the lexical  environment in  which the  expansion takes
    ;;place;  it must  contain  the pattern  variables  visible by  this
    ;;SYNTAX use.
    ;;
    ;;MAPS is  a list  of alists,  one alist  for each  ellipsis nesting
    ;;level.  If the template has 3 nested ellipsis patterns:
    ;;
    ;;   (((?a ...) ...) ...)
    ;;
    ;;while  we are  processing the  inner "(?a  ...)"  MAPS  contains 3
    ;;alists.  The  alists are  used when processing  ellipsis templates
    ;;that recursively reference the same pattern variable, for example:
    ;;
    ;;   ((?a (?a ...)) ...)
    ;;
    ;;the inner  ?A is mapped  to a gensym which  is used to  generate a
    ;;binding in the output code.
    ;;
    ;;ELLIPSIS? must be a predicate function returning true when applied
    ;;to the  ellipsis identifier from  the built in  environment.  Such
    ;;function  is made  an argument,  so that  it can  be changed  to a
    ;;predicate  returning   always  false   when  we   are  recursively
    ;;processing a quoted template:
    ;;
    ;;   (... ?sub-template)
    ;;
    ;;in which the ellipses in ?SUB-TEMPLATE are to be handled as normal
    ;;identifiers.
    ;;
    ;;VEC? is a boolean: true when this function is processing the items
    ;;of a vector.
    ;;
    (syntax-match template-stx ()

      ;;Standalone ellipses are not allowed.
      ;;
      (?dots
       (ellipsis? ?dots)
       (stx-error use-stx "misplaced ellipsis in syntax form"))

      ;;Match  a standalone  identifier.   ?ID can  be:  a reference  to
      ;;pattern variable created by SYNTAX-CASE; an identifier that will
      ;;be captured by  some binding; an identifier that  will result to
      ;;be free,  in which  case an "unbound  identifier" error  will be
      ;;raised later.
      ;;
      (?id
       (identifier? ?id)
       (let ((binding (label->syntactic-binding (id->label ?id) lexenv)))
	 (if (eq? (syntactic-binding-type binding) 'syntax)
	     ;;It is a reference to pattern variable.
	     (receive (var maps)
		 (let* ((name.level  (syntactic-binding-value binding))
			(name        (car name.level))
			(level       (cdr name.level)))
		   (%gen-ref use-stx name level maps))
	       (values (list 'ref var) maps))
	   ;;It is some other identifier.
	   (values (list 'quote ?id) maps))))

      ;;Ellipses starting a vector template are not allowed:
      ;;
      ;;   #(... 1 2 3)   ==> ERROR
      ;;
      ;;but ellipses  starting a list  template are allowed,  they quote
      ;;the subsequent sub-template:
      ;;
      ;;   (... ...)		==> quoted ellipsis
      ;;   (... ?sub-template)	==> quoted ?SUB-TEMPLATE
      ;;
      ;;so that the ellipses in  the ?SUB-TEMPLATE are treated as normal
      ;;identifiers.  We change the  ELLIPSIS? argument for recursion to
      ;;a predicate that always returns false.
      ;;
      ((?dots ?sub-template)
       (ellipsis? ?dots)
       (if vec?
	   (stx-error use-stx "misplaced ellipsis in syntax form")
	 (%gen-syntax use-stx ?sub-template lexenv maps (lambda (x) #f) #f)))

      ;;Match a template followed by ellipsis.
      ;;
      ((?template ?dots . ?rest)
       (ellipsis? ?dots)
       (let loop
	   ((rest.stx ?rest)
	    (kont     (lambda (maps)
			(receive (template^ maps)
			    (%gen-syntax use-stx ?template lexenv (cons '() maps) ellipsis? #f)
			  (if (null? (car maps))
			      (stx-error use-stx "extra ellipsis in syntax form")
			    (values (%gen-map template^ (car maps))
				    (cdr maps)))))))
	 (syntax-match rest.stx ()
	   (()
	    (kont maps))

	   ((?dots . ?tail)
	    (ellipsis? ?dots)
	    (loop ?tail (lambda (maps)
			  (receive (template^ maps)
			      (kont (cons '() maps))
			    (if (null? (car maps))
				(stx-error use-stx "extra ellipsis in syntax form")
			      (values (%gen-mappend template^ (car maps))
				      (cdr maps)))))))

	   (_
	    (receive (rest^ maps)
		(%gen-syntax use-stx rest.stx lexenv maps ellipsis? vec?)
	      (receive (template^ maps)
		  (kont maps)
		(values (%gen-append template^ rest^) maps))))
	   )))

      ;;Process pair templates.
      ;;
      ((?car . ?cdr)
       (receive (car.new maps)
	   (%gen-syntax use-stx ?car lexenv maps ellipsis? #f)
	 (receive (cdr.new maps)
	     (%gen-syntax use-stx ?cdr lexenv maps ellipsis? vec?)
	   (values (%gen-cons template-stx ?car ?cdr car.new cdr.new)
		   maps))))

      ;;Process a vector template.  We set to true the VEC? argument for
      ;;recursion.
      ;;
      (#(?item* ...)
       (receive (item*.new maps)
	   (%gen-syntax use-stx ?item* lexenv maps ellipsis? #t)
	 (values (%gen-vector template-stx ?item* item*.new)
		 maps)))

      ;;Everything else is just quoted in the output.  This includes all
      ;;the literal datums.
      ;;
      (_
       (values `(quote ,template-stx) maps))
      ))

  (define (%gen-ref use-stx var level maps)
    ;;Recursive function.
    ;;
    #;(debug-print 'gen-ref maps)
    (if (zero? level)
	(values var maps)
      (if (null? maps)
	  (stx-error use-stx "missing ellipsis in syntax form")
	(receive (outer-var outer-maps)
	    (%gen-ref use-stx var (- level 1) (cdr maps))
	  (cond ((assq outer-var (car maps))
		 => (lambda (b)
		      (values (cdr b) maps)))
		(else
		 (let ((inner-var (gensym-for-lexical-var 'tmp)))
		   (values inner-var
			   (cons (cons (cons outer-var inner-var)
				       (car maps))
				 outer-maps)))))))))

  (define (%gen-append x y)
    (if (equal? y '(quote ()))
	x
      `(append ,x ,y)))

  (define (%gen-mappend e map-env)
    `(apply (primitive append) ,(%gen-map e map-env)))

  (define (%gen-map e map-env)
    (let ((formals (map cdr map-env))
	  (actuals (map (lambda (x) `(ref ,(car x))) map-env)))
      (cond
       ;; identity map equivalence:
       ;; (map (lambda (x) x) y) == y
       ((eq? (car e) 'ref)
	(car actuals))
       ;; eta map equivalence:
       ;; (map (lambda (x ...) (f x ...)) y ...) == (map f y ...)
       ((for-all
	    (lambda (x) (and (eq? (car x) 'ref) (memq (cadr x) formals)))
	  (cdr e))
	(let ((args (map (let ((r (map cons formals actuals)))
			   (lambda (x) (cdr (assq (cadr x) r))))
		      (cdr e))))
	  `(map (primitive ,(car e)) . ,args)))
       (else
	(cons* 'map (list 'lambda formals e) actuals)))))

  (define (%gen-cons e x y x.new y.new)
    (case (car y.new)
      ((quote)
       (cond ((eq? (car x.new) 'quote)
	      (let ((x.new (cadr x.new))
		    (y.new (cadr y.new)))
		(if (and (eq? x.new x)
			 (eq? y.new y))
		    `(quote ,e)
		  `(quote ,(cons x.new y.new)))))
	     ((null? (cadr y.new))
	      `(list ,x.new))
	     (else
	      `(cons ,x.new ,y.new))))
      ((list)
       `(list ,x.new . ,(cdr y.new)))
      (else
       `(cons ,x.new ,y.new))))

  (define (%gen-vector e ls lsnew)
    (cond ((eq? (car lsnew) 'quote)
	   (if (eq? (cadr lsnew) ls)
	       `(quote ,e)
	     `(quote #(,@(cadr lsnew)))))

	  ((eq? (car lsnew) 'list)
	   `(vector . ,(cdr lsnew)))

	  (else
	   `(list->vector ,lsnew))))

  (define (%generate-output-code x)
    ;;Recursive function.
    ;;
    (case (car x)
      ((ref)
       (build-lexical-reference no-source (cadr x)))
      ((primitive)
       (build-primref no-source (cadr x)))
      ((quote)
       (build-data no-source (cadr x)))
      ((lambda)
       (build-lambda no-source (cadr x) (%generate-output-code (caddr x))))
      ((map)
       (let ((ls (map %generate-output-code (cdr x))))
	 (build-application no-source
			    (build-primref no-source 'ellipsis-map)
			    ls)))
      (else
       (build-application no-source
			  (build-primref no-source (car x))
			  (map %generate-output-code (cdr x))))))

  #| end of module: syntax-transformer |# )


;;;; module core-macro-transformer: SYNTAX-CASE

(module (syntax-case-transformer)
  ;;Transformer function used to expand R6RS's SYNTAX-CASE syntaxes from
  ;;the top-level built in environment.  Process the contents of USE-STX
  ;;in  the   context  of   the  lexical  environments   LEXENV.RUN  and
  ;;LEXENV.EXPAND.
  ;;
  ;;Notice  that   the  parsing   of  the   patterns  is   performed  by
  ;;CONVERT-PATTERN at  expand time and  the actual pattern  matching is
  ;;performed by SYNTAX-DISPATCH at run time.
  ;;
  (define (syntax-case-transformer use-stx lexenv.run lexenv.expand)
    (syntax-match use-stx ()
      ((_ ?expr (?literal* ...) ?clauses* ...)
       (%verify-literals ?literal* use-stx)
       (let* ( ;;The identifier to  which the result of evaluating the
	      ;;?EXPR is bound.
	      (expr.id    (gensym-for-lexical-var 'tmp))
	      ;;The full SYNTAX-CASE  pattern matching code, generated
	      ;;and transformed to core language.
	      (body.core  (%gen-syntax-case expr.id ?literal* ?clauses*
					    lexenv.run lexenv.expand))
	      ;;The ?EXPR transformed to core language.
	      (expr.core  (chi-expr ?expr lexenv.run lexenv.expand)))
	 ;;Return a form like:
	 ;;
	 ;;   ((lambda (expr.id) body.core) expr.core)
	 ;;
	 (build-application no-source
	   (build-lambda no-source (list expr.id) body.core)
	   (list expr.core))))
      ))

  (define (%gen-syntax-case expr.id literals clauses lexenv.run lexenv.expand)
    ;;Recursive function.  Generate and return the full pattern matching
    ;;code in the core language to match the given CLAUSES.
    ;;
    (syntax-match clauses ()
      ;;No pattern matched the input  expression: return code to raise a
      ;;syntax error.
      ;;
      (()
       (build-application no-source
	 (build-primref no-source 'syntax-error)
	 (list (build-lexical-reference no-source expr.id))))

      ;;The pattern  is a standalone  identifier, neither a  literal nor
      ;;the ellipsis,  and it  has no  fender.  A  standalone identifier
      ;;with no fender matches everything,  so it is useless to generate
      ;;the code  for the next clauses:  the code generated here  is the
      ;;last one.
      ;;
      (((?pattern ?output-expr) . ?unused-clauses)
       (and (identifier? ?pattern)
	    (not (bound-id-member? ?pattern literals))
	    (not (ellipsis? ?pattern)))
       (if (free-id=? ?pattern (scheme-stx '_))
	   ;;The clause is:
	   ;;
	   ;;   (_ ?output-expr)
	   ;;
	   ;;the underscore  identifier matches everything and  binds no
	   ;;pattern variables.
	   (chi-expr ?output-expr lexenv.run lexenv.expand)
	 ;;The clause is:
	 ;;
	 ;;   (?id ?output-expr)
	 ;;
	 ;;a standalone identifier matches everything  and binds it to a
	 ;;pattern variable whose name is ?ID.
	 (let ((label (gensym-for-label ?pattern))
	       (lex   (gensym-for-lexical-var ?pattern)))
	   ;;The expression  must be  expanded in a  lexical environment
	   ;;augmented with the pattern variable.
	   (define output-expr^
	     (push-lexical-contour (make-full-rib (list ?pattern) (list label))
				   ?output-expr))
	   (define lexenv.run^
	     ;;Push a pattern variable entry to the lexical environment.
	     ;;The ellipsis nesting level is 0.
	     (cons (cons label (make-binding 'syntax (cons lex 0)))
		   lexenv.run))
	   (define output-expr.core
	     (chi-expr output-expr^ lexenv.run^ lexenv.expand))
	   (build-application no-source
	     (build-lambda no-source
	       (list lex)
	       output-expr.core)
	     (list (build-lexical-reference no-source expr.id))))))

      ;;The  pattern is  neither  a standalone  pattern  variable nor  a
      ;;standalone underscore.  It has no fender, which is equivalent to
      ;;having a "#t" as fender.
      ;;
      (((?pattern ?output-expr) . ?next-clauses)
       (%gen-clause expr.id literals
		    ?pattern #t #;fender
		    ?output-expr
		    lexenv.run lexenv.expand
		    ?next-clauses))

      ;;The pattern has a fender.
      ;;
      (((?pattern ?fender ?output-expr) . ?next-clauses)
       (%gen-clause expr.id literals
		    ?pattern ?fender ?output-expr
		    lexenv.run lexenv.expand
		    ?next-clauses))
      ))

  (define (%gen-clause expr.id literals
		       pattern.stx fender.stx output-expr.stx
		       lexenv.run lexenv.expand
		       next-clauses)
    ;;Generate  the  code needed  to  match  the clause  represented  by
    ;;PATTERN.STX, FENDER.STX and  OUTPUT-EXPR.STX; recursively generate
    ;;the code to match the other clauses in NEXT-CLAUSES.
    ;;
    ;;When there is a fender, we build the output form (pseudo-code):
    ;;
    ;;  ((lambda (y)
    ;;      (if (if y
    ;;              (fender-matches?)
    ;;            #f)
    ;;          (output-expr)
    ;;        (match-next-clauses))
    ;;   (syntax-dispatch expr.id pattern))
    ;;
    ;;when there is no fender, build the output form (pseudo-code):
    ;;
    ;;  ((lambda (tmp)
    ;;      (if tmp
    ;;          (output-expr)
    ;;        (match-next-clauses))
    ;;   (syntax-dispatch expr.id pattern))
    ;;
    ;;notice that the  return value of SYNTAX-DISPATCH is:  false if the
    ;;pattern did not match, otherwise the list of values to be bound to
    ;;the pattern variables.
    ;;
    (receive (pattern.dispatch pvars.levels)
	;;CONVERT-PATTERN  return 2  values: the  pattern in  the format
	;;accepted by SYNTAX-DISPATCH, an alist representing the pattern
	;;variables:
	;;
	;;* The keys of the alist are identifiers representing the names
	;;  of the pattern variables.
	;;
	;;*  The values  of the  alist are  non-negative exact  integers
	;;  representing the ellipsis nesting level of the corresponding
	;;  pattern variable.  See SYNTAX-TRANSFORMER for details.
	;;
	(convert-pattern pattern.stx literals)
      (let ((pvars (map car pvars.levels)))
	(unless (distinct-bound-ids? pvars)
	  (%invalid-ids-error pvars pattern.stx "pattern variable")))
      (unless (for-all (lambda (x)
			 (not (ellipsis? (car x))))
		pvars.levels)
	(stx-error pattern.stx "misplaced ellipsis in syntax-case pattern"))
      (let* ((tmp-sym      (gensym-for-lexical-var 'tmp))
	     (fender-cond  (%build-fender-conditional expr.id literals tmp-sym pvars.levels
						      fender.stx output-expr.stx
						      lexenv.run lexenv.expand
						      next-clauses)))
	(build-application no-source
	  (build-lambda no-source
	    (list tmp-sym)
	    fender-cond)
	  (list
	   (build-application no-source
	     (build-primref no-source 'syntax-dispatch)
	     (list (build-lexical-reference no-source expr.id)
		   (build-data no-source pattern.dispatch))))))))

  (define (%build-fender-conditional expr.id literals tmp-sym pvars.levels
				     fender.stx output-expr.stx
				     lexenv.run lexenv.expand
				     next-clauses)
    ;;Generate the  code that tests  the fender: if the  fender succeeds
    ;;run the output expression, else try to match the next clauses.
    ;;
    ;;When there is a fender, we build the output form (pseudo-code):
    ;;
    ;;   (if (if y
    ;;           (fender-matches?)
    ;;         #f)
    ;;       (output-expr)
    ;;     (match-next-clauses))
    ;;
    ;;when there is no fender, build the output form (pseudo-code):
    ;;
    ;;   (if tmp
    ;;       (output-expr)
    ;;     (match-next-clauses))
    ;;
    (define-inline (%build-call expr.stx)
      (%build-dispatch-call pvars.levels expr.stx tmp-sym lexenv.run lexenv.expand))
    (let ((test     (if (eq? fender.stx #t)
			;;There is no fender.
			tmp-sym
		      ;;There is a fender.
		      (build-conditional no-source
			(build-lexical-reference no-source tmp-sym)
			(%build-call fender.stx)
			(build-data no-source #f))))
	  (conseq    (%build-call output-expr.stx))
	  (altern    (%gen-syntax-case expr.id literals next-clauses lexenv.run lexenv.expand)))
      (build-conditional no-source
	test conseq altern)))

  (define (%build-dispatch-call pvars.levels expr.stx tmp-sym lexenv.run lexenv.expand)
    ;;Generate  code to  evaluate EXPR.STX  in an  environment augmented
    ;;with the pattern variables defined by PVARS.LEVELS.  Return a core
    ;;language expression representing the following pseudo-code:
    ;;
    ;;   (apply (lambda (pattern-var ...) expr) tmp)
    ;;
    (define ids
      ;;For each pattern variable: the identifier representing its name.
      (map car pvars.levels))
    (define labels
      ;;For each pattern variable: a gensym used as label in the lexical
      ;;environment.
      (map gensym-for-label ids))
    (define names
      ;;For each pattern variable: a gensym used as unique variable name
      ;;in the lexical environment.
      (map gensym-for-lexical-var ids))
    (define levels
      ;;For  each pattern  variable: an  exact integer  representing the
      ;;ellipsis nesting level.  See SYNTAX-TRANSFORMER for details.
      (map cdr pvars.levels))
    (define bindings
      ;;For each pattern variable: a binding to be pushed on the lexical
      ;;environment.
      (map (lambda (label name level)
	     (cons label (make-binding 'syntax (cons name level))))
	labels names levels))
    (define expr.core
      ;;Expand the  expression in  a lexical environment  augmented with
      ;;the pattern variables.
      ;;
      ;;NOTE We could have created a syntax object:
      ;;
      ;;  #`(lambda (pvar ...) #,expr.stx)
      ;;
      ;;and then  expanded it:  EXPR.STX would have  been expanded  in a
      ;;lexical environment augmented with the PVAR bindings.
      ;;
      ;;Instead we have chosen to push  the PVAR bindings on the lexical
      ;;environment "by hand", then to  expand EXPR.STX in the augmented
      ;;environment,  finally   to  put  the  resulting   core  language
      ;;expression in a core language LAMBDA syntax.
      ;;
      ;;The two methods are fully equivalent;  the one we have chosen is
      ;;a bit faster.
      ;;
      (chi-expr (push-lexical-contour (make-full-rib ids labels) expr.stx)
		(append bindings lexenv.run)
		lexenv.expand))
    (build-application no-source
      (build-primref no-source 'apply)
      (list (build-lambda no-source names expr.core)
	    (build-lexical-reference no-source tmp-sym))))

  (define (%invalid-ids-error id* e class)
    (let find ((id* id*)
	       (ok* '()))
      (if (null? id*)
	  (stx-error e) ; shouldn't happen
	(if (identifier? (car id*))
	    (if (bound-id-member? (car id*) ok*)
		(syntax-error (car id*) "duplicate " class)
	      (find (cdr id*) (cons (car id*) ok*)))
	  (syntax-error (car id*) "invalid " class)))))

  #| end of module: SYNTAX-CASE-TRANSFORMER |# )


;;;; module core-macro-transformer: SPLICE-FIRST-EXPAND

(module (splice-first-expand-transformer
	 splice-first-envelope?
	 splice-first-envelope-form)

  (define-record splice-first-envelope
    (form))

  (define (splice-first-expand-transformer expr-stx lexenv.run lexenv.expand)
    ;;Transformer function  used to expand  Vicare's SPLICE-FIRST-EXPAND
    ;;syntaxes  from the  top-level built  in environment.   Rather than
    ;;expanding    the   input    form:    return    an   instance    of
    ;;SPLICE-FIRST-ENVELOPE holding the non-expanded form.
    ;;
    (syntax-match expr-stx ()
      ((_ ?form)
       (begin
	 #;(debug-print 'splice-first-envelope-for (syntax->datum ?form))
	 (make-splice-first-envelope ?form)))
      ))

  #| end of module |# )


;;;; module core-macro-transformer

#| end of module |# )


;;;; macro transformers helpers

(define (%expand-macro-transformer rhs-expr-stx lexenv.expand)
  ;;Given a syntax  object representing the right-hand side  of a syntax
  ;;definition      (DEFINE-SYNTAX,      LET-SYNTAX,      LETREC-SYNTAX,
  ;;DEFINE-FLUID-SYNTAX,   FLUID-LET-SYNTAX):    expand   it,   invoking
  ;;libraries as needed, and return  a core language sexp
  ;;representing transformer expression.
  ;;
  ;;Usually   the  return   value  of   this  function   is  handed   to
  ;;%EVAL-MACRO-TRANSFORMER.
  ;;
  ;;For:
  ;;
  ;;   (define-syntax ?lhs ?rhs)
  ;;
  ;;this function is called as:
  ;;
  ;;   (%expand-macro-transformer #'?rhs lexenv.expand)
  ;;
  ;;For:
  ;;
  ;;   (let-syntax ((?lhs ?rhs)) ?body0 ?body ...)
  ;;
  ;;this function is called as:
  ;;
  ;;   (%expand-macro-transformer #'?rhs lexenv.expand)
  ;;
  (let* ((rtc           (make-collector))
	 (expanded-rhs  (parametrise ((inv-collector rtc)
				      (vis-collector (lambda (x) (values))))
			  (chi-expr rhs-expr-stx lexenv.expand lexenv.expand))))
    ;;We  invoke all  the libraries  needed to  evaluate the  right-hand
    ;;side.
    (for-each
	(let ((register-visited-library (vis-collector)))
	  (lambda (lib)
	    ;;LIB is  a record  of type "library".   Here we  invoke the
	    ;;library, which means we  evaluate its run-time code.  Then
	    ;;we mark the library as visited.
	    (invoke-library lib)
	    (register-visited-library lib)))
      (rtc))
    expanded-rhs))

(define (%eval-macro-transformer expanded-expr)
  ;;Given a  core language sexp  representing the expression of  a macro
  ;;transformer: evaluate it  and return a proper  syntactic binding for
  ;;the resulting object.
  ;;
  ;;Usually  this   function  is   applied  to   the  return   value  of
  ;;%EXPAND-MACRO-TRANSFORMER.
  ;;
  ;;When  the RHS  of a  syntax  definition is  evaluated, the  returned
  ;;object   should  be   either  a   procedure,  an   identifier-syntax
  ;;transformer, a Vicare struct type  descriptor or an R6RS record type
  ;;descriptor.  If  the return value is  not of such type:  we raise an
  ;;assertion violation.
  ;;
  (let ((rv (eval-core (expanded->core expanded-expr))))
    (cond ((procedure? rv)
	   (make-local-macro-binding rv expanded-expr))
	  ((variable-transformer? rv)
	   (make-local-identifier-macro-binding (variable-transformer-procedure rv) expanded-expr))
	  ((struct-or-record-type-descriptor-binding? rv)
	   rv)
	  ((compile-time-value? rv)
	   (make-local-compile-time-value-binding (compile-time-value-object rv) expanded-expr))
	  (else
	   (assertion-violation 'expand
	     "invalid return value from syntax transformer expression"
	     rv)))))


;;;; formals syntax validation

(define (%verify-formals-syntax formals-stx stx)
  ;;Verify  that  FORMALS-STX  is  a syntax  object  representing  valid
  ;;formals for  LAMBDA and WITH-SYNTAX syntaxes.   If successful return
  ;;unspecified values, else raise a syntax violation.
  ;;
  (syntax-match formals-stx ()
    ((id* ...)
     (unless (valid-bound-ids? id*)
       (%error-invalid-formals-syntax stx formals-stx)))

    ((id* ... . last-id)
     (unless (valid-bound-ids? (cons last-id id*))
       (%error-invalid-formals-syntax stx formals-stx)))

    (_
     (stx-error stx "invalid syntax"))))

(define (%error-invalid-formals-syntax stx formals-stx)
  ;;Raise an error  for invalid formals of LAMBDA,  CASE-LAMBDA, LET and
  ;;similar.
  ;;
  ;;If no  invalid formals  are found:  return unspecified  values, else
  ;;raise a syntax violation.  This function  is called when it has been
  ;;already determined that the formals have something wrong.
  ;;
  ;;For a LAMBDA syntax:
  ;;
  ;;   (lambda ?formals . ?body)
  ;;
  ;;it is called as:
  ;;
  ;;   (%error-invalid-formals-syntax
  ;;      #'(lambda ?formals . ?body)
  ;;      #'?formals)
  ;;
  ;;For a LET syntax:
  ;;
  ;;   (let ((?lhs* ?rhs*) ...) . ?body)
  ;;
  ;;it is called as:
  ;;
  ;;   (%error-invalid-formals-syntax
  ;;      #'(let ((?lhs* ?rhs*) ...) . ?body)
  ;;      #'?lhs*)
  ;;
  ;;NOTE  Invalid LET-VALUES  and LET*-VALUES  formals are  processed by
  ;;this function  indirectly; LET-VALUES  and LET*-VALUES  syntaxes are
  ;;first  transformed into  CALL-WITH-VALUES syntaxes,  then it  is the
  ;;LAMBDA syntax that takes care of formals validation.
  ;;
  (define (%synner message subform)
    (syntax-violation #f message stx subform))
  (syntax-match formals-stx ()
    ((?id* ... . ?last)
     (let recur ((?id* (cond ((identifier? ?last)
			      (cons ?last ?id*))
			     ((syntax-null? ?last)
			      ?id*)
			     (else
			      (%synner "not an identifier" ?last)))))
       (cond ((null? ?id*)
	      (values))
	     ((not (identifier? (car ?id*)))
	      (%synner "not an identifier" (car ?id*)))
	     (else
	      (recur (cdr ?id*))
	      (when (bound-id-member? (car ?id*)
				      (cdr ?id*))
		(%synner "duplicate binding" (car ?id*)))))))

    (_
     (%synner "malformed binding form" formals-stx))
    ))


;;;; pattern matching helpers

(define (convert-pattern pattern-stx literals)
  ;;This function is used both by  the transformer of the non-core macro
  ;;WITH-SYNTAX and  by the transformer  of the core  macro SYNTAX-CASE.
  ;;Transform the syntax object  PATTERN-STX, representing a SYNTAX-CASE
  ;;pattern, into a pattern in the format recognised by SYNTAX-DISPATCH.
  ;;
  ;;LITERALS is null or a  list of identifiers representing the literals
  ;;from a SYNTAX-CASE use.  Notice that the ellipsis and the underscore
  ;;identifiers cannot be literals.
  ;;
  ;;Return  2   values:  the  pattern  for   SYNTAX-DISPATCH,  an  alist
  ;;representing the pattern variables:
  ;;
  ;;* The  keys of the alist  are identifiers representing the  names of
  ;;  the pattern variables.
  ;;
  ;;*  The  values   of  the  alist  are   non-negative  exact  integers
  ;;   representing  the ellipsis  nesting  level  of the  corresponding
  ;;  pattern variable.  See SYNTAX-TRANSFORMER for details.
  ;;
  ;;The returned  pattern for  SYNTAX-DISPATCH is a  sexp
  ;;with the following format:
  ;;
  ;; P in pattern:                    |  matches:
  ;;----------------------------------+---------------------------
  ;;  ()                              |  empty list
  ;;  _                               |  anything (no binding created)
  ;;  any                             |  anything
  ;;  (p1 . p2)                       |  pair
  ;;  #(free-id <key>)                |  <key> with free-identifier=?
  ;;  each-any                        |  any proper list
  ;;  #(each p)                       |  (p*)
  ;;  #(each+ p1 (p2_1 ... p2_n) p3)  |   (p1* (p2_n ... p2_1) . p3)
  ;;  #(vector p)                     |  #(x ...) if p matches (x ...)
  ;;  #(atom <object>)                |  <object> with "equal?"
  ;;
  (define (%convert* pattern* ellipsis-nesting-level pvars.levels)
    (if (null? pattern*)
	(values '() pvars.levels)
      (receive (y pvars.levels)
	  (%convert* (cdr pattern*) ellipsis-nesting-level pvars.levels)
	(receive (x pvars.levels)
	    (%convert (car pattern*) ellipsis-nesting-level pvars.levels)
	  (values (cons x y) pvars.levels)))))

  (define (%convert p ellipsis-nesting-level pvars.levels)
    (syntax-match p ()
      (?id
       (identifier? ?id)
       (cond ((bound-id-member? ?id literals)
	      (values `#(free-id ,?id) pvars.levels))
	     ((free-id=? ?id (scheme-stx '_))
	      (values '_ pvars.levels))
	     (else
	      ;;It is a pattern variable.
	      (values 'any (cons (cons ?id ellipsis-nesting-level)
				 pvars.levels)))))

      ((p dots)
       (ellipsis? dots)
       (receive (p pvars.levels)
	   (%convert p (+ ellipsis-nesting-level 1) pvars.levels)
	 (values (if (eq? p 'any)
		     'each-any
		   `#(each ,p))
		 pvars.levels)))

      ((x dots ys ... . z)
       (ellipsis? dots)
       (receive (z pvars.levels)
	   (%convert z ellipsis-nesting-level pvars.levels)
	 (receive (ys pvars.levels)
	     (%convert* ys ellipsis-nesting-level pvars.levels)
	   (receive (x pvars.levels)
	       (%convert x (+ ellipsis-nesting-level 1) pvars.levels)
	     (values `#(each+ ,x ,(reverse ys) ,z)
		     pvars.levels)))))

      ((x . y)
       (receive (y pvars.levels)
	   (%convert y ellipsis-nesting-level pvars.levels)
	 (receive (x pvars.levels)
	     (%convert x ellipsis-nesting-level pvars.levels)
	   (values (cons x y) pvars.levels))))

      (()
       (values '() pvars.levels))

      (#(?item* ...)
       (not (<stx>? ?item*))
       (receive (item* pvars.levels)
	   (%convert ?item* ellipsis-nesting-level pvars.levels)
	 (values `#(vector ,item*) pvars.levels)))

      (?datum
       (values `#(atom ,(syntax->datum ?datum))
	       pvars.levels))))

  (%convert pattern-stx 0 '()))

(module (ellipsis? underscore?)

  (define (ellipsis? x)
    (%free-identifier-and-symbol? x '...))

  (define (underscore? x)
    (%free-identifier-and-symbol? x '_))

  (define (%free-identifier-and-symbol? x sym)
    (and (identifier? x)
	 (free-id=? x (scheme-stx sym))))

  #| end of module |# )

(define (%verify-literals literals use-stx)
  ;;Verify that  identifiers selected as literals  are: identifiers, not
  ;;ellipsisi, not usderscore.  If successful: return true, else raise a
  ;;syntax violation
  ;;
  ;;LITERALS is  a list  of literals  from SYNTAX-CASE  or SYNTAX-RULES.
  ;;USE-STX  is a  syntax  object  representing the  full  macro use  of
  ;;SYNTAX-CASE or SYNTAX-RULES:  it is used here  for descriptive error
  ;;reporting.
  ;;
  (for-each (lambda (x)
	      (when (or (not (identifier? x))
			(ellipsis? x)
			(underscore? x))
		(syntax-violation #f "invalid literal" use-stx x)))
    literals)
  #t)

(define (ellipsis-map proc ls . ls*)
  ;;This function  is used at  expand time  to generate the  portions of
  ;;macro  output  form  generated  by  templates  with  ellipsis.   See
  ;;SYNTAX-TRANSFORMER for details.
  ;;
  ;;For a syntax template:
  ;;
  ;;   (syntax ((?a ?b ...) ...))
  ;;
  ;;this function is called in the core language as:
  ;;
  ;;   ((primitive ellipsis-map) (primitive cons) ?a ?b)
  ;;
  (define-constant __who__ '...)
  (unless (list? ls)
    (assertion-violation __who__ "not a list" ls))
  ;;LS* must be a list of  sublists, each sublist having the same length
  ;;of LS.
  (unless (null? ls*)
    (let ((n (length ls)))
      (for-each
          (lambda (x)
            (unless (list? x)
              (assertion-violation __who__ "not a list" x))
            (unless (= (length x) n)
              (assertion-violation __who__ "length mismatch" ls x)))
	ls*)))
  (apply map proc ls ls*))

(module (syntax-transpose)
  ;;Mh... what  does this do?   Take BASE-ID  and NEW-ID, which  must be
  ;;FREE-IDENTIFIER=?, compute the difference  between their marks, push
  ;;such difference  on top of the  marks of OBJECT, return  the result.
  ;;What for?  (Marco Maggi; Sun May 5, 2013)
  ;;
  (define-constant __who__ 'syntax-transpose)

  (define (syntax-transpose object base-id new-id)
    (unless (identifier? base-id)
      (%synner "not an identifier" base-id))
    (unless (identifier? new-id)
      (%synner "not an identifier" new-id))
    (unless (free-identifier=? base-id new-id)
      (%synner "not the same identifier" base-id new-id))
    (receive (mark* subst* annotated-expr*)
	(diff (car ($<stx>-mark* base-id))
	      ($<stx>-mark*   new-id)
	      ($<stx>-subst*  new-id)
	      ($<stx>-ae*     new-id)
	      (lambda ()
		(%synner "unmatched identifiers" base-id new-id)))
      (if (and (null? mark*)
	       (null? subst*))
	  object
	(mkstx object mark* subst* annotated-expr*))))

  (define (diff base.mark new.mark* new.subst* new.annotated-expr* error)
    (if (null? new.mark*)
	(error)
      (let ((new.mark1 (car new.mark*)))
	(if (eq? base.mark new.mark1)
	    (values '() (final new.subst*) '())
	  (receive (subst1* subst2*)
	      (split new.subst*)
	    (receive (nm* ns* nae*)
		(diff base.mark (cdr new.mark*) subst2* (cdr new.annotated-expr*) error)
	      (values (cons new.mark1 nm*)
		      (append subst1* ns*)
		      (cons (car new.annotated-expr*) nae*))))))))

  (define (split subst*)
    ;;Non-tail recursive  function.  Split  SUBST* and return  2 values:
    ;;the prefix  of SUBST*  up to  and including  the first  shift, the
    ;;suffix of SUBST* from the first shift excluded to the end.
    ;;
    (if (eq? (car subst*) 'shift)
	(values (list 'shift)
		(cdr subst*))
      (receive (subst1* subst2*)
	  (split (cdr subst*))
	(values (cons (car subst*) subst1*)
		subst2*))))

  (define (final subst*)
    ;;Non-tail recursive  function.  Return the  prefix of SUBST*  up to
    ;;and not including  the first shift.  The returned prefix  is a new
    ;;list spine sharing the cars with SUBST*.
    ;;
    (if (or (null? subst*)
	    (eq? (car subst*) 'shift))
	'()
      (cons (car subst*)
	    (final (cdr subst*)))))

  (define-syntax-rule (%synner ?message ?irritant ...)
    (assertion-violation __who__ ?message ?irritant ...))

  #| end of module: SYNTAX-TRANSPOSE |# )


;;;; pattern matching

(module (syntax-dispatch)
  ;;Perform  the actual  matching between  an input  symbolic expression
  ;;being a  (wrapped, unwrapped  or partially unwrapped)  syntax object
  ;;and a  pattern symbolic expression.   If the expression  matches the
  ;;pattern return null or  a list of syntax objects to  be bound to the
  ;;pattern variables; else return false.
  ;;
  ;;The order of  syntax objects in the returned list  is established by
  ;;the pattern and it is the  same order in which the pattern variables
  ;;appear in the alist returned by CONVERT-PATTERN.
  ;;
  ;;The pattern  for SYNTAX-DISPATCH is  a symbolic expression  with the
  ;;following format:
  ;;
  ;; P in pattern:                    |  matches:
  ;;----------------------------------+---------------------------
  ;;  ()                              |  empty list
  ;;  _                               |  anything (no binding created)
  ;;  any                             |  anything
  ;;  (p1 . p2)                       |  pair
  ;;  #(free-id <key>)                |  <key> with free-identifier=?
  ;;  each-any                        |  any proper list
  ;;  #(each p)                       |  (p*)
  ;;  #(each+ p1 (p2_1 ... p2_n) p3)  |   (p1* (p2_n ... p2_1) . p3)
  ;;  #(vector p)                     |  #(x ...) if p matches (x ...)
  ;;  #(atom <object>)                |  <object> with "equal?"
  ;;
  (define (syntax-dispatch expr pattern)
    (%match expr pattern
	    '() #;mark*
	    '() #;subst*
	    '() #;annotated-expr*
	    '() #;pvar*
	    ))

  (define (%match expr pattern mark* subst* annotated-expr* pvar*)
    (cond ((not pvar*)
	   ;;No match.
	   #f)
	  ((eq? pattern '_)
	   ;;Match anything, bind nothing.
	   pvar*)
	  ((eq? pattern 'any)
	   ;;Match anything, bind a pattern variable.
	   (cons (%make-syntax-object expr mark* subst* annotated-expr*)
		 pvar*))
	  ((<stx>? expr)
	   ;;Visit the syntax object.
	   (and (not (top-marked? mark*))
		(receive (mark*^ subst*^ annotated-expr*^)
		    (join-wraps mark* subst* annotated-expr* expr)
		  (%match (<stx>-expr expr) pattern mark*^ subst*^ annotated-expr*^ pvar*))))
	  ((annotation? expr)
	   ;;Visit the ANNOTATION struct.
	   (%match (annotation-expression expr) pattern mark* subst* annotated-expr* pvar*))
	  (else
	   (%match* expr pattern mark* subst* annotated-expr* pvar*))))

  (define (%match* expr pattern mark* subst* annotated-expr* pvar*)
    (cond
     ;;End of list pattern: match the end of a list expression.
     ;;
     ((null? pattern)
      (and (null? expr)
	   pvar*))

     ;;Match a pair expression.
     ;;
     ((pair? pattern)
      (and (pair? expr)
	   (%match (car expr) (car pattern) mark* subst* annotated-expr*
		   (%match (cdr expr) (cdr pattern) mark* subst* annotated-expr* pvar*))))

     ;;Match any  proper list  expression and  bind a  pattern variable.
     ;;This happens when the original pattern symbolic expression is:
     ;;
     ;;   (?var ...)
     ;;
     ;;everything  in the  proper  list  must be  bound  to the  pattern
     ;;variable ?VAR.
     ;;
     ((eq? pattern 'each-any)
      (let ((l (%match-each-any expr mark* subst* annotated-expr*)))
	(and l (cons l pvar*))))

     (else
      ;;Here we expect the PATTERN to be a vector of the format:
      ;;
      ;;   #(?symbol ?stuff ...)
      ;;
      ;;where ?SYMBOL is a symbol.
      ;;
      (case (vector-ref pattern 0)

	;;The pattern is:
	;;
	;;   #(each ?sub-pattern)
	;;
	;;the expression  matches if it  is a  list in which  every item
	;;matches ?SUB-PATTERN.
	;;
	((each)
	 (if (null? expr)
	     (%match-empty (vector-ref pattern 1) pvar*)
	   (let ((pvar** (%match-each expr (vector-ref pattern 1)
				      mark* subst* annotated-expr*)))
	     (and pvar**
		  (%combine pvar** pvar*)))))

	;;The pattern is:
	;;
	;;   #(free-id ?literal)
	;;
	;;the  expression  matches  if  it is  an  identifier  equal  to
	;;?LITERAL according to FREE-IDENTIFIER=?.
	;;
	((free-id)
	 (and (symbol? expr)
	      (top-marked? mark*)
	      (free-id=? (%make-syntax-object expr mark* subst* annotated-expr*)
			 (vector-ref pattern 1))
	      pvar*))

	;;The pattern is:
	;;
	;;   #(scheme-id ?symbol)
	;;
	;;the  expression matches  if it  is an  identifier equal  to an
	;;identifier    having   ?SYMBOL    as    name   according    to
	;;FREE-IDENTIFIER=?.
	;;
	((scheme-id)
	 (and (symbol? expr)
	      (top-marked? mark*)
	      (free-id=? (%make-syntax-object expr mark* subst* annotated-expr*)
			 (scheme-stx (vector-ref pattern 1)))
	      pvar*))

	;;The pattern is:
	;;
	;;   #(each+ p1 (p2_1 ... p2_n) p3)
	;;
	;;which originally was:
	;;
	;;   (p1 ?ellipsis p2_1 ... p2_n . p3)
	;;
	;;the expression matches if ...
	;;
	((each+)
	 (receive (xr* y-pat pvar*)
	     (%match-each+ expr
			   (vector-ref pattern 1)
			   (vector-ref pattern 2)
			   (vector-ref pattern 3)
			   mark* subst* annotated-expr* pvar*)
	   (and pvar*
		(null? y-pat)
		(if (null? xr*)
		    (%match-empty (vector-ref pattern 1) pvar*)
		  (%combine xr* pvar*)))))

	;;The pattern is:
	;;
	;;  #(atom ?object)
	;;
	;;the  expression matches  if it  is  a single  object equal  to
	;;?OBJECT according to EQUAL?.
	;;
	((atom)
	 (and (equal? (vector-ref pattern 1)
		      (strip expr mark*))
	      pvar*))

	;;The pattern is:
	;;
	;;   #(vector ?sub-pattern)
	;;
	;;the expression matches if it is a vector whose items match the
	;;?SUB-PATTERN.
	;;
	((vector)
	 (and (vector? expr)
	      (%match (vector->list expr) (vector-ref pattern 1)
		      mark* subst* annotated-expr* pvar*)))

	(else
	 (assertion-violation 'syntax-dispatch "invalid pattern" pattern))))))

  (define (%match-each expr pattern mark* subst* annotated-expr*)
    ;;Recursive function.   The expression  matches if it  is a  list in
    ;;which  every item  matches  PATTERN.   Return null  or  a list  of
    ;;sublists, each sublist being a list of pattern variable values.
    ;;
    (cond ((pair? expr)
	   (let ((first (%match (car expr) pattern mark* subst* annotated-expr* '())))
	     (and first
		  (let ((rest (%match-each (cdr expr) pattern mark* subst* annotated-expr*)))
		    (and rest (cons first rest))))))
	  ((null? expr)
	   '())
	  ((<stx>? expr)
	   (and (not (top-marked? mark*))
		(receive (mark*^ subst*^ annotated-expr*^)
		    (join-wraps mark* subst* annotated-expr* expr)
		  (%match-each (<stx>-expr expr) pattern mark*^ subst*^ annotated-expr*^))))
	  ((annotation? expr)
	   (%match-each (annotation-expression expr) pattern mark* subst* annotated-expr*))
	  (else #f)))

  (define (%match-each+ e x-pat y-pat z-pat mark* subst* annotated-expr* pvar*)
    (let loop ((e e) (mark* mark*) (subst* subst*) (annotated-expr* annotated-expr*))
      (cond ((pair? e)
	     (receive (xr* y-pat pvar*)
		 (loop (cdr e) mark* subst* annotated-expr*)
	       (if pvar*
		   (if (null? y-pat)
		       (let ((xr (%match (car e) x-pat mark* subst* annotated-expr* '())))
			 (if xr
			     (values (cons xr xr*) y-pat pvar*)
			   (values #f #f #f)))
		     (values '()
			     (cdr y-pat)
			     (%match (car e) (car y-pat) mark* subst* annotated-expr* pvar*)))
		 (values #f #f #f))))
	    ((<stx>? e)
	     (if (top-marked? mark*)
		 (values '() y-pat (%match e z-pat mark* subst* annotated-expr* pvar*))
	       (receive (mark* subst* annotated-expr*)
		   (join-wraps mark* subst* annotated-expr* e)
		 (loop (<stx>-expr e) mark* subst* annotated-expr*))))
	    ((annotation? e)
	     (loop (annotation-expression e) mark* subst* annotated-expr*))
	    (else
	     (values '() y-pat (%match e z-pat mark* subst* annotated-expr* pvar*))))))

  (define (%match-each-any e mark* subst* annotated-expr*)
    (cond ((pair? e)
	   (let ((l (%match-each-any (cdr e) mark* subst* annotated-expr*)))
	     (and l (cons (%make-syntax-object (car e) mark* subst* annotated-expr*) l))))
	  ((null? e)
	   '())
	  ((<stx>? e)
	   (and (not (top-marked? mark*))
		(receive (mark* subst* annotated-expr*)
		    (join-wraps mark* subst* annotated-expr* e)
		  (%match-each-any (<stx>-expr e) mark* subst* annotated-expr*))))
	  ((annotation? e)
	   (%match-each-any (annotation-expression e) mark* subst* annotated-expr*))
	  (else #f)))

  (define (%match-empty p pvar*)
    (cond ((null? p)
	   pvar*)
	  ((eq? p '_)
	   pvar*)
	  ((eq? p 'any)
	   (cons '() pvar*))
	  ((pair? p)
	   (%match-empty (car p) (%match-empty (cdr p) pvar*)))
	  ((eq? p 'each-any)
	   (cons '() pvar*))
	  (else
	   (case (vector-ref p 0)
	     ((each)
	      (%match-empty (vector-ref p 1) pvar*))
	     ((each+)
	      (%match-empty (vector-ref p 1)
			    (%match-empty (reverse (vector-ref p 2))
					  (%match-empty (vector-ref p 3) pvar*))))
	     ((free-id atom)
	      pvar*)
	     ((scheme-id atom)
	      pvar*)
	     ((vector)
	      (%match-empty (vector-ref p 1) pvar*))
	     (else
	      (assertion-violation 'syntax-dispatch "invalid pattern" p))))))

  (define (%make-syntax-object stx mark* subst* annotated-expr*)
    (if (and (null? mark*)
	     (null? subst*)
	     (null? annotated-expr*))
	stx
      (mkstx stx mark* subst* annotated-expr*)))

  (define (%combine pvar** pvar*)
    (if (null? (car pvar**))
	pvar*
      (cons (map car pvar**)
	    (%combine (map cdr pvar**) pvar*))))

  #| end of module: SYNTAX-DISPATCH |# )


;;;; chi module
;;
;;The  "chi-*"  functions  are  the ones  visiting  syntax  objects  and
;;performing the expansion process.
;;
(module (chi-expr
	 chi-expr*
	 chi-body*
	 chi-internal-body
	 chi-rhs*
	 chi-defun
	 chi-lambda-clause
	 chi-lambda-clause*)


;;;; chi procedures: syntax object type inspection

(define (syntax-type expr-stx lexenv)
  ;;The type of an expression is determined by two things:
  ;;
  ;;- The shape of the expression (identifier, pair, or datum).
  ;;
  ;;- The binding of  the identifier (for id-stx) or the  type of car of
  ;;  the pair.
  ;;
  (cond ((identifier? expr-stx)
	 (let* ((id    expr-stx)
		(label (id->label/intern id)))
	   (unless label
	     (%raise-unbound-error #f id id))
	   (let* ((binding (label->syntactic-binding label lexenv))
		  (type    (syntactic-binding-type binding)))
	     (case type
	       ((lexical core-prim macro global local-macro
			 local-macro! global-macro global-macro!
			 displaced-lexical syntax import export $module
			 $core-rtd library mutable local-ctv global-ctv)
		(values type (syntactic-binding-value binding) id))
	       (else
		(values 'other #f #f))))))
	((syntax-pair? expr-stx)
	 (let ((id (syntax-car expr-stx)))
	   (if (identifier? id)
	       (let ((label (id->label/intern id)))
		 (unless label
		   (%raise-unbound-error #f id id))
		 (let* ((binding (label->syntactic-binding label lexenv))
			(type    (syntactic-binding-type binding)))
		   (case type
		     ((define define-syntax core-macro begin macro
			local-macro local-macro! global-macro
			global-macro! module library set! let-syntax
			letrec-syntax import export $core-rtd
			local-ctv global-ctv stale-when
			define-fluid-syntax)
		      (values type (syntactic-binding-value binding) id))
		     (else
		      (values 'call #f #f)))))
	     (values 'call #f #f))))
	(else
	 (let ((datum (syntax->datum expr-stx)))
	   (if (self-evaluating? datum)
	       (values 'constant datum #f)
	     (values 'other #f #f))))))




;;;; chi procedures: helpers for SPLICE-FIRST-EXPAND

;;Set to true  whenever we are expanding the first  suborm in a function
;;application.   This is  where the  syntax SPLICE-FIRST-EXPAND  must be
;;used; in every other place it must be discarded.
;;
(define expanding-application-first-subform?
  (make-parameter #f))

(define-syntax while-expanding-application-first-subform
  ;;Evaluate a body while the parameter is true.
  ;;
  (syntax-rules ()
    ((_ ?body0 ?body ...)
     (parametrise ((expanding-application-first-subform? #t))
       ?body0 ?body ...))))

(define-syntax while-not-expanding-application-first-subform
  ;;Evaluate a body while the parameter is false.
  ;;
  (syntax-rules ()
    ((_ ?body0 ?body ...)
     (parametrise ((expanding-application-first-subform? #f))
       ?body0 ?body ...))))

(define (chi-drop-splice-first-envelope-maybe expr lexenv.run lexenv.expand)
  ;;If we are expanding the first subform of an application: just return
  ;;EXPR;  otherwise if  EXPR is  a splice-first  envelope: extract  its
  ;;form, expand it and return the result.
  ;;
  (if (splice-first-envelope? expr)
      (if (expanding-application-first-subform?)
	  expr
	(chi-drop-splice-first-envelope-maybe (chi-expr (splice-first-envelope-form expr) lexenv.run lexenv.expand)
					      lexenv.run lexenv.expand))
    expr))


;;;; chi procedures: macro calls

(module (chi-non-core-macro
	 chi-local-macro
	 chi-global-macro)

  (define* (chi-non-core-macro (procname symbol?) input-form-expr lexenv.run rib)
    ;;Expand an expression representing the use of a non-core macro; the
    ;;transformer function is integrated in the expander.
    ;;
    ;;PROCNAME is a symbol representing  the name of the non-core macro;
    ;;we can map  from such symbol to the transformer  function with the
    ;;module of NON-CORE-MACRO-TRANSFORMER.
    ;;
    ;;INPUT-FORM-EXPR is  the syntax object representing  the expression
    ;;to be expanded.
    ;;
    ;;LEXENV.RUN  is  the  run-time  lexical environment  in  which  the
    ;;expression must be expanded.
    ;;
    ;;RIB is false or a struct of type "<rib>".
    ;;
    (import NON-CORE-MACRO-TRANSFORMER)
    (%do-macro-call (non-core-macro-transformer procname)
		    input-form-expr lexenv.run rib))

  (define (chi-local-macro bind-val input-form-expr lexenv.run rib)
    ;;This  function is  used  to  expand macro  uses  for macros  whose
    ;;transformer  is defined  by local  user code,  but not  identifier
    ;;syntaxes;  these are  the lexical  environment entries  with types
    ;;"local-macro" and "local-macro!".
    ;;
    ;;BIND-VAL is the binding value of  the global macro.  The format of
    ;;the bindings is:
    ;;
    ;;     (local-macro  . (?transformer . ?expanded-expr))
    ;;     (local-macro! . (?transformer . ?expanded-expr))
    ;;
    ;;and the argument BIND-VAL is:
    ;;
    ;;     (?transformer . ?expanded-expr)
    ;;
    ;;INPUT-FORM-EXPR is  the syntax object representing  the expression
    ;;to be expanded.
    ;;
    ;;LEXENV.RUN  is  the  run-time  lexical environment  in  which  the
    ;;expression must be expanded.
    ;;
    ;;RIB is false or a struct of type "<rib>".
    ;;
    (%do-macro-call (car bind-val) input-form-expr lexenv.run rib))

  (define (chi-global-macro bind-val input-form-expr lexenv.run rib)
    ;;This  function is  used  to  expand macro  uses  for macros  whose
    ;;transformer is defined  by user code in  imported libraries; these
    ;;are the lexical environment  entries with types "global-macro" and
    ;;"global-macro!".
    ;;
    ;;BIND-VAL is the binding value of  the global macro.  The format of
    ;;the bindings is:
    ;;
    ;;     (global-macro  . (?library . ?gensym))
    ;;     (global-macro! . (?library . ?gensym))
    ;;
    ;;and the argument BIND-VAL is:
    ;;
    ;;     (?library . ?gensym)
    ;;
    ;;INPUT-FORM-EXPR is  the syntax object representing  the expression
    ;;to be expanded.
    ;;
    ;;LEXENV.RUN  is  the  run-time  lexical environment  in  which  the
    ;;expression must be expanded.
    ;;
    ;;RIB is false or a struct of type "<rib>".
    ;;
    (let ((lib (car bind-val))
	  (loc (cdr bind-val)))
      ;;If this global binding use is  the first time a binding from LIB
      ;;is used: visit the library.
      (unless (eq? lib '*interaction*)
	(visit-library lib))
      (let ((x (symbol-value loc)))
	(let ((transformer (cond ((procedure? x)
				  x)
				 ((variable-transformer? x)
				  (cdr x))
				 (else
				  (assertion-violation 'chi-global-macro
				    "Vicare: internal error: not a procedure" x)))))
	  (%do-macro-call transformer input-form-expr lexenv.run rib)))))

;;; --------------------------------------------------------------------

  (define (%do-macro-call transformer input-form-expr lexenv.run rib)
    (define (main)
      (let ((output-form-expr (transformer
			       ;;Put the anti-mark on the input form.
			       (add-mark anti-mark #f input-form-expr #f))))
	;;If  the transformer  returns  a function:  we  must apply  the
	;;returned function  to a function acting  as compile-time value
	;;retriever.   Such  application  must   return  a  value  as  a
	;;transformer would do.
	(if (procedure? output-form-expr)
	    (%return (output-form-expr %ctv-retriever))
	  (%return output-form-expr))))

    (define (%return output-form-expr)
      ;;Check that there are no raw symbols in the value returned by the
      ;;macro transformer.
      (let recur ((x output-form-expr))
	;;Don't feed me cycles.
	(unless (<stx>? x)
	  (cond ((pair? x)
		 (recur (car x))
		 (recur (cdr x)))
		((vector? x)
		 (vector-for-each recur x))
		((symbol? x)
		 (syntax-violation #f
		   "raw symbol encountered in output of macro"
		   input-form-expr x)))))
      ;;Put a  new mark  on the  output form.   For all  the identifiers
      ;;already  present  in the  input  form:  this  new mark  will  be
      ;;annihilated  by  the  anti-mark  we put  before.   For  all  the
      ;;identifiers introduced  by the  transformer: this new  mark will
      ;;stay there.
      (add-mark (gen-mark) rib output-form-expr input-form-expr))

    (define (%ctv-retriever id)
      ;;This is  the compile-time  values retriever function.   Given an
      ;;identifier:  search an  entry in  the lexical  environment; when
      ;;found return its value, otherwise return false.
      ;;
      (unless (identifier? id)
	(assertion-violation 'rho "not an identifier" id))
      (let ((binding (label->syntactic-binding (id->label id) lexenv.run)))
	(case (syntactic-binding-type binding)
	  ;;The given identifier is bound to a local compile-time value.
	  ;;The actual object is stored in the binding itself.
	  ((local-ctv)
	   (local-compile-time-value-binding-object binding))

	  ;;The  given  identifier  is  bound to  a  compile-time  value
	  ;;imported from  a library or the  top-level environment.  The
	  ;;actual  object is  stored  in  the "value"  field  of a  loc
	  ;;gensym.
	  ((global-ctv)
	   (let ((lib (cadr binding))
		 (loc (cddr binding)))
	     ;;If this  global binding use  is the first time  a binding
	     ;;from LIB is used: visit the library.
	     (unless (eq? lib '*interaction*)
	       (visit-library lib))
	     ;;FIXME The following form should really be just:
	     ;;
	     ;;   (symbol-value loc)
	     ;;
	     ;;because   the  value   in  LOC   should  be   the  actual
	     ;;compile-time value  object.  Instead there is  at least a
	     ;;case in which  the value in LOC is  the full compile-time
	     ;;value:
	     ;;
	     ;;   (ctv . ?obj)
	     ;;
	     ;;It happens when the library:
	     ;;
	     ;;   (library (demo)
	     ;;     (export obj)
	     ;;     (import (vicare))
	     ;;     (define-syntax obj (make-compile-time-value 123)))
	     ;;
	     ;;is precompiled and then loaded by the program:
	     ;;
	     ;;   (import (vicare) (demo))
	     ;;   (define-syntax (doit stx)
	     ;;     (lambda (ctv-retriever) (ctv-retriever #'obj)))
	     ;;   (doit)
	     ;;
	     ;;the expansion of "(doit)" fails with an error because the
	     ;;value  returned by  the  transformer is  the CTV  special
	     ;;value.  We  circumvent this problem by  testing below the
	     ;;nature of  the value in LOC,  but it is just  a temporary
	     ;;workaround.  (Marco Maggi; Sun Jan 19, 2014)
	     ;;
	     (let ((ctv (symbol-value loc)))
	       (if (compile-time-value? ctv)
		   (compile-time-value-object ctv)
		 ctv))))

	  ;;The given identifier is not bound to a compile-time value.
	  (else #f))))

    (main))

  #| end of module |# )


;;;; chi procedures: expressions

(module (chi-expr)

  (define (chi-expr e lexenv.run lexenv.expand)
    ;;Expand a single expression form.
    ;;
    (chi-drop-splice-first-envelope-maybe
     (receive (type bind-val kwd)
	 (syntax-type e lexenv.run)
       (case type
	 ((core-macro)
	  (let ((transformer (core-macro-transformer bind-val)))
	    (transformer e lexenv.run lexenv.expand)))

	 ((global)
	  (let* ((lib (car bind-val))
		 (loc (cdr bind-val)))
	    ((inv-collector) lib)
	    (build-global-reference no-source loc)))

	 ((core-prim)
	  (let ((name bind-val))
	    (build-primref no-source name)))

	 ((call)
	  (chi-application e lexenv.run lexenv.expand))

	 ((lexical)
	  (let ((lex (lexical-var bind-val)))
	    (build-lexical-reference no-source lex)))

	 ((global-macro global-macro!)
	  (let ((exp-e (while-not-expanding-application-first-subform
			(chi-global-macro bind-val e lexenv.run #f))))
	    (chi-expr exp-e lexenv.run lexenv.expand)))

	 ((local-macro local-macro!)
	  ;;Here  we expand  uses  of macros  that are  local  in a  non
	  ;;top-level region.
	  ;;
	  (let ((exp-e (while-not-expanding-application-first-subform
			(chi-local-macro bind-val e lexenv.run #f))))
	    (chi-expr exp-e lexenv.run lexenv.expand)))

	 ((macro)
	  ;;Here we expand the use of a non-core macro.  Such macros are
	  ;;integrated in the expander.
	  ;;
	  (let ((exp-e (while-not-expanding-application-first-subform
			(chi-non-core-macro bind-val e lexenv.run #f))))
	    (chi-expr exp-e lexenv.run lexenv.expand)))

	 ((constant)
	  (let ((datum bind-val))
	    (build-data no-source datum)))

	 ((set!)
	  (chi-set! e lexenv.run lexenv.expand))

	 ((begin)
	  (syntax-match e ()
	    ((_ x x* ...)
	     (build-sequence no-source
	       (while-not-expanding-application-first-subform
		(chi-expr* (cons x x*) lexenv.run lexenv.expand))))))

	 ((stale-when)
	  ;;STALE-WHEN  acts  like  BEGIN,  but  in  addition  causes  an
	  ;;expression  to  be  registered   in  the  current  stale-when
	  ;;collector.   When such  expression  evaluates  to false:  the
	  ;;compiled library is  stale with respect to  some source file.
	  ;;See for example the INCLUDE syntax.
	  (syntax-match e ()
	    ((_ ?guard ?x ?x* ...)
	     (begin
	       (handle-stale-when ?guard lexenv.expand)
	       (build-sequence no-source
		 (while-not-expanding-application-first-subform
		  (chi-expr* (cons ?x ?x*) lexenv.run lexenv.expand)))))))

	 ((let-syntax letrec-syntax)
	  (syntax-match e ()
	    ((_ ((xlhs* xrhs*) ...) xbody xbody* ...)
	     (unless (valid-bound-ids? xlhs*)
	       (stx-error e "invalid identifiers"))
	     (let* ((xlab* (map gensym-for-label xlhs*))
		    (xrib  (make-full-rib xlhs* xlab*))
		    (xb*   (map (lambda (x)
				  (%eval-macro-transformer
				   (%expand-macro-transformer (if (eq? type 'let-syntax)
								  x
								(push-lexical-contour xrib x))
							      lexenv.expand)))
			     xrhs*)))
	       (build-sequence no-source
		 (while-not-expanding-application-first-subform
		  (chi-expr* (map (lambda (x)
				    (push-lexical-contour xrib x))
			       (cons xbody xbody*))
			     (append (map cons xlab* xb*) lexenv.run)
			     (append (map cons xlab* xb*) lexenv.expand))))))))

	 ((displaced-lexical)
	  (stx-error e "identifier out of context"))

	 ((syntax)
	  (stx-error e "reference to pattern variable outside a syntax form"))

	 ((define define-syntax define-fluid-syntax module import library)
	  (stx-error e (string-append
			(case type
			  ((define)              "a definition")
			  ((define-syntax)       "a define-syntax")
			  ((define-fluid-syntax) "a define-fluid-syntax")
			  ((module)              "a module definition")
			  ((library)             "a library definition")
			  ((import)              "an import declaration")
			  ((export)              "an export declaration")
			  (else                  "a non-expression"))
			" was found where an expression was expected")))

	 ((mutable)
	  (if (and (pair? bind-val)
		   (let ((lib (car bind-val)))
		     (eq? lib '*interaction*)))
	      (let ((loc (cdr bind-val)))
		(build-global-reference no-source loc))
	    (stx-error e "attempt to reference an unexportable variable")))

	 (else
	  ;;(assertion-violation 'chi-expr "invalid type " type (strip e '()))
	  (stx-error e "invalid expression"))))
     lexenv.run lexenv.expand))

  (define (chi-application expr lexenv.run lexenv.expand)
    ;;Expand a function application form.   This is called when EXPR has
    ;;the format:
    ;;
    ;;   (?rator ?rand ...)
    ;;
    ;;and ?RATOR is a pair or a non-macro identifier.  For example it is
    ;;called when EXPR is:
    ;;
    ;;   (((?rator ?rand1 ...) ?rand2 ...) ?rand3 ...)
    ;;
    (define (%build-core-expression rator rands)
      (build-application (syntax-annotation expr)
	rator
	(while-not-expanding-application-first-subform
	 (chi-expr* rands lexenv.run lexenv.expand))))
    (syntax-match expr ()
      ((?rator ?rands* ...)
       (if (not (syntax-pair? ?rator))
       	   ;;This  is a  common function  application: ?RATOR  is not  a
       	   ;;syntax  keyword.  Let's  make  sure that  we expand  ?RATOR
       	   ;;first.
       	   (let ((rator (chi-expr ?rator lexenv.run lexenv.expand)))
	     (%build-core-expression rator ?rands*))
	 ;;This is a function application with the format:
	 ;;
	 ;;   ((?int-rator ?int-rand ...) ?rand ...)
	 ;;
	 ;;we  expand  it considering  the  case  of the  first  subform
	 ;;expanding to a SPLICE-FIRST-EXPAND form.
	 (let ((exp-rator (while-expanding-application-first-subform
			   (chi-expr ?rator lexenv.run lexenv.expand))))
	   (if (splice-first-envelope? exp-rator)
	       (syntax-match (splice-first-envelope-form exp-rator) ()
		 ((?int-rator ?int-rands* ...)
		  (chi-expr (cons ?int-rator (append ?int-rands* ?rands*))
			    lexenv.run lexenv.expand))
		 (_
		  (stx-error exp-rator
			     "expected list as argument of splice-first-expand"
			     'splice-first-expand)))
	     (%build-core-expression exp-rator ?rands*)))))
      ))

  (define (chi-set! e lexenv.run lexenv.expand)
    (syntax-match e ()
      ((_ x v)
       (identifier? x)
       (receive (type bind-val kwd)
	   (syntax-type x lexenv.run)
	 (case type
	   ((lexical)
	    (set-lexical-mutable! bind-val)
	    (build-lexical-assignment no-source
	      (lexical-var bind-val)
	      (chi-expr v lexenv.run lexenv.expand)))
	   ((core-prim)
	    (stx-error e "cannot modify imported core primitive"))

	   ((global)
	    (stx-error e "attempt to modify an immutable binding"))

	   ((global-macro!)
	    (chi-expr (chi-global-macro bind-val e lexenv.run #f) lexenv.run lexenv.expand))

	   ((local-macro!)
	    (chi-expr (chi-local-macro bind-val e lexenv.run #f) lexenv.run lexenv.expand))

	   ((mutable)
	    (if (and (pair? bind-val)
		     (let ((lib (car bind-val)))
		       (eq? lib '*interaction*)))
		(let ((loc (cdr bind-val)))
		  (build-global-assignment no-source
		    loc (chi-expr v lexenv.run lexenv.expand)))
	      (stx-error e "attempt to modify an unexportable variable")))

	   (else
	    (stx-error e)))))))

  #| end of module |# )

(define (chi-expr* expr* lexenv.run lexenv.expand)
  ;;Recursive function.  Expand the expressions in EXPR* left to right.
  ;;
  (if (null? expr*)
      '()
    ;;ORDER MATTERS!!!  Make sure  that first  we do  the car,  then the
    ;;rest.
    (let ((expr0 (chi-expr (car expr*) lexenv.run lexenv.expand)))
      (cons expr0
	    (chi-expr* (cdr expr*) lexenv.run lexenv.expand)))))


;;;; chi procedures: definitions and lambda clauses

(define (chi-lambda-clause stx fmls body* lexenv.run lexenv.expand)
  (while-not-expanding-application-first-subform
   (syntax-match fmls ()
     ((x* ...)
      (begin
	(%verify-formals-syntax fmls stx)
	(let ((lex* (map gensym-for-lexical-var x*))
	      (lab* (map gensym-for-label x*)))
	  (values lex*
		  (chi-internal-body (push-lexical-contour (make-full-rib x* lab*)
							   body*)
				     (add-lexical-bindings lab* lex* lexenv.run)
				     lexenv.expand)))))
     ((x* ... . x)
      (begin
	(%verify-formals-syntax fmls stx)
	(let ((lex* (map gensym-for-lexical-var x*))
	      (lab* (map gensym-for-label x*))
	      (lex  (gensym-for-lexical-var x))
	      (lab  (gensym-for-label x)))
	  (values (append lex* lex)
		  (chi-internal-body (push-lexical-contour (make-full-rib (cons x   x*)
									  (cons lab lab*))
							   body*)
				     (add-lexical-bindings (cons lab lab*) (cons lex lex*) lexenv.run)
				     lexenv.expand)))))
     (_
      (stx-error fmls "invalid syntax")))))

(define (chi-lambda-clause* stx fmls* body** lexenv.run lexenv.expand)
  (if (null? fmls*)
      (values '() '())
    (receive (a b)
	(chi-lambda-clause stx (car fmls*) (car body**) lexenv.run lexenv.expand)
      (receive (a* b*)
	  (chi-lambda-clause* stx (cdr fmls*) (cdr body**) lexenv.run lexenv.expand)
	(values (cons a a*) (cons b b*))))))

(define (chi-defun x lexenv.run lexenv.expand)
  (syntax-match x ()
    ((_ (ctxt . fmls) . body*)
     (receive (fmls body)
	 (chi-lambda-clause fmls fmls body* lexenv.run lexenv.expand)
       (build-lambda (syntax-annotation ctxt) fmls body)))))


;;;; chi procedures: bindings right-hand sides

(define (chi-rhs rhs lexenv.run lexenv.expand)
  (case (car rhs)
    ((defun)
     (chi-defun (cdr rhs) lexenv.run lexenv.expand))

    ((expr)
     (let ((expr (cdr rhs)))
       (chi-expr expr lexenv.run lexenv.expand)))

    ((top-expr)
     (let ((expr (cdr rhs)))
       (build-sequence no-source
	 (list (chi-expr expr lexenv.run lexenv.expand)
	       (build-void)))))

    (else
     (assertion-violation 'chi-rhs "BUG: invalid rhs" rhs))))

(define (chi-rhs* rhs* lexenv.run lexenv.expand)
  ;;Expand the right-hand side expressions in RHS*, left-to-right.
  ;;
  (let loop ((ls rhs*))
    ;; chi-rhs in order
    (if (null? ls)
	'()
      (let ((a (chi-rhs (car ls) lexenv.run lexenv.expand)))
	(cons a
	      (loop (cdr ls)))))))


;;;; chi procedures: internal body

(define (chi-internal-body expr* lexenv.run lexenv.expand)
  (while-not-expanding-application-first-subform
   (let ((rib (make-empty-rib)))
     (receive (expr*^ lexenv.run lexenv.expand lex* rhs* mod** kwd* _exp*)
	 (chi-body* (map (lambda (x)
			   (push-lexical-contour rib x))
		      (syntax->list expr*))
		    lexenv.run lexenv.expand
		    '() '() '() '() '() rib #f #t)
       (when (null? expr*^)
	 (stx-error expr*^ "no expression in body"))
       (let* ((init* (chi-expr* (append (apply append (reverse mod**))
					expr*^)
				lexenv.run lexenv.expand))
	      (rhs*  (chi-rhs* rhs* lexenv.run lexenv.expand)))
	 (build-letrec* no-source
	   (reverse lex*)
	   (reverse rhs*)
	   (build-sequence no-source init*)))))))


;;;; chi procedures: body

(module (chi-body*)
  ;;The recursive function CHI-BODY* expands  the forms of a body.  Here
  ;;is a description of the arguments.
  ;;
  ;;BODY-EXPR* must be null or a list of syntax objects representing the
  ;;forms.
  ;;
  ;;LEXENV.RUN and LEXENV.EXPAND must  be lists representing the current
  ;;lexical environment for run and expand times.
  ;;
  ;;LEX* must be  a list of gensyms  and RHS* must be a  list of special
  ;;objects representing  right-hand side expressions for  DEFINE syntax
  ;;uses;  they  are  meant  to  be processed  together  item  by  item.
  ;;Whenever the RHS  expressions are expanded: a  core language binding
  ;;will be  created with a  LEX gensym  associate to a  RHS expression.
  ;;The special values have the formats:
  ;;
  ;; (defun . ?full-form)
  ;;		Represents  a  DEFINE  form which  defines  a  function.
  ;;		?FULL-FORM is  the syntax  object representing  the full
  ;;		DEFINE form.
  ;;
  ;; (expr  . ?val)
  ;;		Represents a  DEFINE form  which defines  a non-function
  ;;		variable.   ?VAL is  a  syntax  object representing  the
  ;;		variable's value.
  ;;
  ;; (top-expr . ?body-expr)
  ;;		Represents   a  dummy   DEFINE   form  introduced   when
  ;;		processing an expression in a R6RS program.
  ;;
  ;;About the MOD** argument.  We  know that module definitions have the
  ;;syntax:
  ;;
  ;;   (module (?export-id ...) ?definition ... ?expression ...)
  ;;
  ;;and  the trailing  ?EXPRESSION  forms must  be  evaluated after  the
  ;;right-hand sides  of the DEFINE syntaxes  of the module but  also of
  ;;the  enclosing  lexical context.   So  when  expanding a  MODULE  we
  ;;accumulate such expression syntax objects in the MOD** argument as:
  ;;
  ;;   MOD** == ((?expression ...) ...)
  ;;
  ;;KWD* is a  list of identifiers representing the  syntaxes defined in
  ;;this body.  It is used to test for duplicate definitions.
  ;;
  ;;EXPORT-SPEC* is  null or a  list of syntax objects  representing the
  ;;export specifications from this body.  It is to be processed later.
  ;;
  ;;RIB is the current lexical environment's rib.
  ;;
  ;;MIX? is interpreted  as boolean.  When false:  the expansion process
  ;;visits all  the definition forms  and stops at the  first expression
  ;;form; the expression  forms are returned to the  caller.  When true:
  ;;the  expansion  process visits  all  the  definition and  expression
  ;;forms, accepting  a mixed  sequence of them;  an expression  form is
  ;;handled as a dummy definition form.
  ;;
  ;;When SD? is false this body  is allowed to redefine bindings created
  ;;by DEFINE;  this happens when expanding  for the Scheme REPL  in the
  ;;interaction environment.  When SD? is true: attempting to redefine a
  ;;DEFINE binding will raise an exception.
  ;;
  (define (chi-body* body-expr* lexenv.run lexenv.expand lex* rhs* mod** kwd* export-spec* rib mix? sd?)
    (while-not-expanding-application-first-subform
     (if (null? body-expr*)
	 (values body-expr* lexenv.run lexenv.expand lex* rhs* mod** kwd* export-spec*)
       (let ((body-expr (car body-expr*)))
	 (receive (type bind-val kwd)
	     (syntax-type body-expr lexenv.run)
	   (let ((kwd* (if (identifier? kwd)
			   (cons kwd kwd*)
			 kwd*)))
	     (case type

	       ((define)
		;;The body form is a core language DEFINE macro use.  We
		;;create a label and a lex gensym in which the result of
		;;evaluating  the right-hand  side  will  be stored;  we
		;;register the label in the  rib.  Finally we recurse on
		;;the rest of the body.
		;;
		(receive (id rhs)
		    (%parse-define body-expr)
		  (when (bound-id-member? id kwd*)
		    (stx-error body-expr "cannot redefine keyword"))
		  (receive (lab lex)
		      (gen-define-label+loc id rib sd?)
		    (extend-rib! rib id lab sd?)
		    (chi-body* (cdr body-expr*)
			       (add-lexical-binding lab lex lexenv.run) lexenv.expand
			       (cons lex lex*) (cons rhs rhs*)
			       mod** kwd* export-spec* rib mix? sd?))))

	       ((define-syntax)
		;;The body  form is a core  language DEFINE-SYNTAX macro
		;;use.    We  expand   and   evaluate  the   transformer
		;;expression, build a syntactic binding for it, register
		;;the label in the rib.   Finally we recurse on the rest
		;;of the body.
		;;
		(receive (id rhs)
		    (%parse-define-syntax body-expr)
		  (when (bound-id-member? id kwd*)
		    (stx-error body-expr "cannot redefine keyword"))
		  ;;We want order here!?!
		  (let* ((lab          (gen-define-label id rib sd?))
			 (expanded-rhs (%expand-macro-transformer rhs lexenv.expand)))
		    (extend-rib! rib id lab sd?)
		    (let ((entry (cons lab (%eval-macro-transformer expanded-rhs))))
		      (chi-body* (cdr body-expr*)
				 (cons entry lexenv.run)
				 (cons entry lexenv.expand)
				 lex* rhs* mod** kwd* export-spec* rib
				 mix? sd?)))))

	       ((define-fluid-syntax)
		;;The body  form is a core  language DEFINE-FLUID-SYNTAX
		;;macro  use.  We  expand and  evaluate the  transformer
		;;expression, build syntactic  bindings for it, register
		;;the label in the rib.   Finally we recurse on the rest
		;;of the body.
		;;
		(receive (id rhs)
		    (%parse-define-syntax body-expr)
		  (when (bound-id-member? id kwd*)
		    (stx-error body-expr "cannot redefine keyword"))
		  ;;We want order here!?!
		  (let* ((lab          (gen-define-label id rib sd?))
			 (flab         (gen-define-label id rib sd?))
			 (expanded-rhs (%expand-macro-transformer rhs lexenv.expand)))
		    (extend-rib! rib id lab sd?)
		    (let* ((binding  (%eval-macro-transformer expanded-rhs))
			   ;;This  lexical environment  entry represents
			   ;;the definition of the fluid syntax.
			   (entry1   (cons lab (make-fluid-syntax-binding flab)))
			   ;;This  lexical environment  entry represents
			   ;;the  current binding  of the  fluid syntax.
			   ;;Other entries  like this one can  be pushed
			   ;;to rebind the fluid syntax.
			   (entry2   (cons flab binding)))
		      (chi-body* (cdr body-expr*)
				 (cons* entry1 entry2 lexenv.run)
				 (cons* entry1 entry2 lexenv.expand)
				 lex* rhs* mod** kwd* export-spec* rib
				 mix? sd?)))))

	       ((let-syntax letrec-syntax)
		;;The  body  form  is  a  core  language  LET-SYNTAX  or
		;;LETREC-SYNTAX macro  use.  We expand and  evaluate the
		;;transformer expressions, build  syntactic bindings for
		;;them, register their labels in  a new rib because they
		;;are visible  only in the internal  body.  The internal
		;;forms are  spliced in the  external body but  with the
		;;rib added to them.
		;;
		(syntax-match body-expr ()
		  ((_ ((?xlhs* ?xrhs*) ...) ?xbody* ...)
		   (unless (valid-bound-ids? ?xlhs*)
		     (stx-error body-expr "invalid identifiers"))
		   (let* ((xlab*  (map gensym-for-label ?xlhs*))
			  (xrib   (make-full-rib ?xlhs* xlab*))
			  (xbind* (map (lambda (x)
					 (%eval-macro-transformer
					  (%expand-macro-transformer
					   (if (eq? type 'let-syntax)
					       x
					     (push-lexical-contour xrib x))
					   lexenv.expand)))
				    ?xrhs*)))
		     (chi-body*
		      ;;Splice the internal body forms but add a lexical
		      ;;contour to them.
		      (append (map (lambda (internal-body-form)
				     (push-lexical-contour xrib internal-body-form))
				?xbody*)
			      (cdr body-expr*))
		      ;;Push   on   the  lexical   environment   entries
		      ;;corresponding  to  the defined  syntaxes.   Such
		      ;;entries  will  stay  there even  after  we  have
		      ;;processed the internal body forms; this is not a
		      ;;problem because the labels cannot be seen by the
		      ;;rest of the body.
		      (append (map cons xlab* xbind*) lexenv.run)
		      (append (map cons xlab* xbind*) lexenv.expand)
		      lex* rhs* mod** kwd* export-spec* rib
		      mix? sd?)))))

	       ((begin)
		;;The body form is a  BEGIN syntax use.  Just splice the
		;;expressions and recurse on them.
		;;
		(syntax-match body-expr ()
		  ((_ ?expr* ...)
		   (chi-body* (append ?expr* (cdr body-expr*))
			      lexenv.run lexenv.expand
			      lex* rhs* mod** kwd* export-spec* rib mix? sd?))))

	       ((stale-when)
		;;The body form is a STALE-WHEN syntax use.  Process the
		;;stale-when  guard  expression,  then just  splice  the
		;;internal expressions as we do for BEGIN and recurse.
		;;
		(syntax-match body-expr ()
		  ((_ ?guard ?expr* ...)
		   (begin
		     (handle-stale-when ?guard lexenv.expand)
		     (chi-body* (append ?expr* (cdr body-expr*))
				lexenv.run lexenv.expand
				lex* rhs* mod** kwd* export-spec* rib mix? sd?)))))

	       ((global-macro global-macro!)
		;;The  body form  is a  macro  use, where  the macro  is
		;;imported  from  a  library.    We  perform  the  macro
		;;expansion,  then  recurse   on  the  resulting  syntax
		;;object.
		;;
		(let ((body-expr^ (chi-global-macro bind-val body-expr lexenv.run rib)))
		  (chi-body* (cons body-expr^ (cdr body-expr*))
			     lexenv.run lexenv.expand
			     lex* rhs* mod** kwd* export-spec* rib mix? sd?)))

	       ((local-macro local-macro!)
		;;The  body form  is a  macro  use, where  the macro  is
		;;locally defined.  We perform the macro expansion, then
		;;recurse on the resulting syntax object.
		;;
		(let ((body-expr^ (chi-local-macro bind-val body-expr lexenv.run rib)))
		  (chi-body* (cons body-expr^ (cdr body-expr*))
			     lexenv.run lexenv.expand
			     lex* rhs* mod** kwd* export-spec* rib mix? sd?)))

	       ((macro)
		;;The body  form is a  macro use,  where the macro  is a
		;;non-core macro integrated in the expander.  We perform
		;;the  macro expansion,  then recurse  on the  resulting
		;;syntax object.
		;;
		(let ((body-expr^ (chi-non-core-macro bind-val body-expr lexenv.run rib)))
		  (chi-body* (cons body-expr^ (cdr body-expr*))
			     lexenv.run lexenv.expand
			     lex* rhs* mod** kwd* export-spec* rib mix? sd?)))

	       ((module)
		;;The body  form is  an internal module  definition.  We
		;;process the  module, then recurse  on the rest  of the
		;;body.
		;;
		(receive (lex* rhs* m-exp-id* m-exp-lab* lexenv.run lexenv.expand mod** kwd*)
		    (chi-internal-module body-expr lexenv.run lexenv.expand lex* rhs* mod** kwd*)
		  ;;Extend the rib with  the syntactic bindings exported
		  ;;by the module.
		  (vector-for-each (lambda (id lab)
				     (extend-rib! rib id lab sd?))
		    m-exp-id* m-exp-lab*)
		  (chi-body* (cdr body-expr*) lexenv.run lexenv.expand
			     lex* rhs* mod** kwd* export-spec*
			     rib mix? sd?)))

	       ((library)
		;;The body form is a library definition.  We process the
		;;library, then recurse on the rest of the body.
		;;
		(expand-library (syntax->datum body-expr))
		(chi-body* (cdr body-expr*)
			   lexenv.run lexenv.expand
			   lex* rhs* mod** kwd* export-spec*
			   rib mix? sd?))

	       ((export)
		;;The body form  is an EXPORT form.   We just accumulate
		;;the export specifications, to  be processed later, and
		;;we recurse on the rest of the body.
		;;
		(syntax-match body-expr ()
		  ((_ ?export-spec* ...)
		   (chi-body* (cdr body-expr*)
			      lexenv.run lexenv.expand
			      lex* rhs* mod** kwd*
			      (append ?export-spec* export-spec*)
			      rib mix? sd?))))

	       ((import)
		;;The body form is an  IMPORT form.  We just process the
		;;form  which results  in  extending the  RIB with  more
		;;identifier-to-label associations.   Finally we recurse
		;;on the rest of the body.
		;;
		(%chi-import body-expr lexenv.run rib sd?)
		(chi-body* (cdr body-expr*) lexenv.run lexenv.expand
			   lex* rhs* mod** kwd* export-spec* rib mix? sd?))

	       (else
		(if mix?
		    (chi-body* (cdr body-expr*)
			       lexenv.run lexenv.expand
			       (cons (gensym-for-lexical-var 'dummy) lex*)
			       (cons (cons 'top-expr body-expr) rhs*)
			       mod** kwd* export-spec* rib #t sd?)
		  (values body-expr* lexenv.run lexenv.expand lex* rhs* mod** kwd* export-spec*))))))))))

;;; --------------------------------------------------------------------

  (define (%parse-define x)
    ;;Syntax parser for R6RS's DEFINE.
    ;;
    (syntax-match x ()
      ((_ (?id . ?fmls) ?b ?b* ...)
       (identifier? ?id)
       (begin
	 (%verify-formals-syntax ?fmls x)
	 (values ?id (cons 'defun x))))

      ((_ ?id ?val)
       (identifier? ?id)
       (values ?id (cons 'expr ?val)))

      ((_ ?id)
       (identifier? ?id)
       (values ?id (cons 'expr (bless '(void)))))
      ))

  (define (%parse-define-syntax stx)
    ;;Syntax  parser for  R6RS's DEFINE-SYNTAX,  extended with  Vicare's
    ;;syntax.  Accept both:
    ;;
    ;;  (define-syntax ?name ?transformer-expr)
    ;;  (define-syntax (?name ?arg) ?body0 ?body ...)
    ;;
    (syntax-match stx ()
      ((_ ?id)
       (identifier? ?id)
       (values ?id (bless '(syntax-rules ()))))
      ((_ ?id ?transformer-expr)
       (identifier? ?id)
       (values ?id ?transformer-expr))
      ((_ (?id ?arg) ?body0 ?body* ...)
       (and (identifier? ?id)
	    (identifier? ?arg))
       (values ?id (bless `(lambda (,?arg) ,?body0 ,@?body*))))
      ))

;;; --------------------------------------------------------------------

  (module (%chi-import)
    ;;Process an IMPORT form.  The purpose of such forms is to push some
    ;;new identifier-to-label association on the current RIB.
    ;;
    (define (%chi-import body-expr lexenv.run rib sd?)
      (receive (id* lab*)
	  (%any-import*-checked body-expr lexenv.run)
	(vector-for-each (lambda (id lab)
			   (extend-rib! rib id lab sd?))
	  id* lab*)))

    (define (%any-import*-checked import-form lexenv.run)
      (syntax-match import-form ()
	((?ctxt ?import-spec* ...)
	 (%any-import* ?ctxt ?import-spec* lexenv.run))
	(_
	 (stx-error import-form "invalid import form"))))

    (define (%any-import* ctxt import-spec* lexenv.run)
      (if (null? import-spec*)
	  (values '#() '#())
	(let-values
	    (((t1 t2) (%any-import  ctxt (car import-spec*) lexenv.run))
	     ((t3 t4) (%any-import* ctxt (cdr import-spec*) lexenv.run)))
	  (values (vector-append t1 t3)
		  (vector-append t2 t4)))))

    (define (%any-import ctxt import-spec lexenv.run)
      (if (identifier? import-spec)
	  (%module-import (list ctxt import-spec) lexenv.run)
	(%library-import (list ctxt import-spec))))

    (define (%module-import import-form lexenv.run)
      (syntax-match import-form ()
	((_ ?id)
	 (identifier? ?id)
	 (receive (type bind-val kwd)
	     (syntax-type ?id lexenv.run)
	   (case type
	     (($module)
	      (let ((iface bind-val))
		(values (module-interface-exp-id*     iface ?id)
			(module-interface-exp-lab-vec iface))))
	     (else
	      (stx-error import-form "invalid import")))))))

    (define (%library-import import-form)
      (syntax-match import-form ()
	((?ctxt ?imp* ...)
	 (receive (subst-names subst-labels)
	     (begin
	       (import PARSE-IMPORT-SPEC)
	       (parse-import-spec* (syntax->datum ?imp*)))
	   (values (vector-map (lambda (name)
				 (datum->stx ?ctxt name))
		     subst-names)
		   subst-labels)))
	(_
	 (stx-error import-form "invalid import form"))))

    #| end of module: %CHI-IMPORT |# )

  #| end of module: CHI-BODY* |# )


;;;; chi procedures: module processing

(module (chi-internal-module
	 module-interface-exp-id*
	 module-interface-exp-lab-vec)

  (define-record module-interface
    (first-mark
		;The first  mark in  the lexical  context of  the MODULE
		;form.
     exp-id-vec
		;A vector of identifiers exported by the module.
     exp-lab-vec
		;A  vector   of  gensyms   acting  as  labels   for  the
		;identifiers in the field EXP-ID-VEC.
     ))

  (define (chi-internal-module module-form-stx lexenv.run lexenv.expand lex* rhs* mod** kwd*)
    ;;Expand the  syntax object MODULE-FORM-STX which  represents a core
    ;;langauge MODULE syntax use.
    ;;
    ;;LEXENV.RUN  and  LEXENV.EXPAND  must  be  lists  representing  the
    ;;current lexical environment for run and expand times.
    ;;
    (receive (name export-id* internal-body-form*)
	(%parse-module module-form-stx)
      (let* ((module-rib               (make-empty-rib))
	     (internal-body-form*/rib  (map (lambda (x)
					      (push-lexical-contour module-rib x))
					 (syntax->list internal-body-form*))))
	(receive (leftover-body-expr* lexenv.run lexenv.expand lex* rhs* mod** kwd* _export-spec*)
	    ;;In a module: we do not want the trailing expressions to be
	    ;;converted to dummy definitions; rather  we want them to be
	    ;;accumulated in the MOD** argument, for later expansion and
	    ;;evaluation.  So we set MIX? to false.
	    (let ((empty-export-spec*	'())
		  (mix?			#f)
		  (sd?			#t))
	      (chi-body* internal-body-form*/rib
			 lexenv.run lexenv.expand
			 lex* rhs* mod** kwd* empty-export-spec*
			 module-rib mix? sd?))
	  ;;The list  of exported identifiers  is not only the  one from
	  ;;the MODULE  argument, but also  the one from all  the EXPORT
	  ;;forms in the MODULE's body.
	  (let* ((all-export-id*  (vector-append export-id* (list->vector _export-spec*)))
		 (all-export-lab* (vector-map
				      (lambda (id)
					;;For every  exported identifier
					;;there must be  a label already
					;;in the rib.
					(or (id->label (make-<stx> (identifier->symbol id)
								   (<stx>-mark* id)
								   (list module-rib)
								   '()))
					    (stx-error id "cannot find module export")))
				    all-export-id*))
		 (mod**           (cons leftover-body-expr* mod**)))
	    (if (not name)
		;;The module  has no name.  All  the exported identifier
		;;will go in the enclosing lexical environment.
		(values lex* rhs* all-export-id* all-export-lab* lexenv.run lexenv.expand mod** kwd*)
	      ;;The module has a name.  Only  the name itself will go in
	      ;;the enclosing lexical environment.
	      (let* ((name-label (gensym-for-label 'module))
		     (iface      (make-module-interface
				  (car (<stx>-mark* name))
				  (vector-map
				      (lambda (x)
					;;This   is   a  syntax   object
					;;holding an identifier.
					(make-<stx> (<stx>-expr x) ;expression
						    (<stx>-mark* x) ;list of marks
						    '() ;list of substs
						    '())) ;annotated expressions
				    all-export-id*)
				  all-export-lab*))
		     (binding    (make-module-binding iface))
		     (entry      (cons name-label binding)))
		(values lex* rhs*
			;;FIXME:  module   cannot  export   itself  yet.
			;;Abdulaziz Ghuloum.
			(vector name)
			(vector name-label)
			(cons entry lexenv.run)
			(cons entry lexenv.expand)
			mod** kwd*))))))))

  (define (%parse-module module-form-stx)
    ;;Parse a  syntax object representing  a core language  MODULE form.
    ;;Return 3  values: false or  an identifier representing  the module
    ;;name; a list  of identifiers selecting the  exported bindings from
    ;;the first MODULE  argument; a list of  syntax objects representing
    ;;the internal body forms.
    ;;
    (syntax-match module-form-stx ()
      ((_ (?export* ...) ?body* ...)
       (begin
	 (unless (for-all identifier? ?export*)
	   (stx-error module-form-stx "module exports must be identifiers"))
	 (values #f (list->vector ?export*) ?body*)))
      ((_ ?name (?export* ...) ?body* ...)
       (begin
	 (unless (identifier? ?name)
	   (stx-error module-form-stx "module name must be an identifier"))
	 (unless (for-all identifier? ?export*)
	   (stx-error module-form-stx "module exports must be identifiers"))
	 (values ?name (list->vector ?export*) ?body*)))
      ))

  (module (module-interface-exp-id*)

    (define (module-interface-exp-id* iface id-for-marks)
      (let ((diff   (%diff-marks (<stx>-mark* id-for-marks)
				 (module-interface-first-mark iface)))
	    (id-vec (module-interface-exp-id-vec iface)))
	(if (null? diff)
	    id-vec
	  (vector-map
	      (lambda (x)
		(make-<stx> (<stx>-expr x)		  ;expression
			    (append diff (<stx>-mark* x)) ;list of marks
			    '()	  ;list of substs
			    '())) ;annotated expressions
	    id-vec))))

    (define (%diff-marks mark* the-mark)
      ;;MARK* must be  a non-empty list of marks; THE-MARK  must be a mark
      ;;in MARK*.  Return  a list of the  elements of MARK* up  to and not
      ;;including THE-MARK.
      ;;
      (when (null? mark*)
	(error '%diff-marks "BUG: should not happen"))
      (let ((a (car mark*)))
	(if (eq? a the-mark)
	    '()
	  (cons a (%diff-marks (cdr mark*) the-mark)))))

    #| end of module: MODULE-INTERFACE-EXP-ID* |# )

  #| end of module |# )


;;;; chi procedures: stale-when handling

(define (handle-stale-when guard-expr lexenv.expand)
  (let* ((stc       (make-collector))
	 (core-expr (parametrise ((inv-collector stc))
		      (chi-expr guard-expr lexenv.expand lexenv.expand))))
    (cond ((stale-when-collector)
	   => (lambda (c)
		(c core-expr (stc)))))))


;;;; chi procedures: end of module

#| end of module |# )


;;;; errors

(define (assertion-error expr source-identifier
			 byte-offset character-offset
			 line-number column-number)
  ;;Invoked by the  expansion of the ASSERT macro to  raise an assertion
  ;;violation.
  ;;
  (raise
   (condition (make-assertion-violation)
	      (make-who-condition 'assert)
	      (make-message-condition "assertion failed")
	      (make-irritants-condition (list expr))
	      (make-source-position-condition source-identifier
					      byte-offset character-offset
					      line-number column-number))))

(define-syntax stx-error
  ;;Convenience wrapper for raising syntax violations.
  ;;
  (syntax-rules (quote)
    ((_ ?expr-stx)
     (syntax-violation #f "invalid syntax" ?expr-stx))
    ((_ ?expr-stx ?msg)
     (syntax-violation #f ?msg ?expr-stx))
    ((_ ?expr-stx ?msg ?who)
     (syntax-violation ?who ?msg ?expr-stx))
    ))

(module (syntax-error
	 syntax-violation
	 %raise-unbound-error)

  (define (syntax-error x . args)
    (unless (for-all string? args)
      (assertion-violation 'syntax-error "invalid argument" args))
    (raise
     (condition (make-message-condition (if (null? args)
					    "invalid syntax"
					  (apply string-append args)))
		(make-syntax-violation (syntax->datum x) #f)
		(%expression->source-position-condition x)
		(%extract-trace x))))

  (case-define syntax-violation
    ;;Defined  by R6RS.   WHO must  be false  or a  string or  a symbol.
    ;;MESSAGE must be a string.  FORM must be a syntax object or a datum
    ;;value.  SUBFORM must be a syntax object or a datum value.
    ;;
    ;;The SYNTAX-VIOLATION  procedure raises  an exception,  reporting a
    ;;syntax violation.  WHO should  describe the macro transformer that
    ;;detected the exception.  The  MESSAGE argument should describe the
    ;;violation.  FORM should be the erroneous source syntax object or a
    ;;datum value  representing a  form.  The optional  SUBFORM argument
    ;;should be a syntax object or  datum value representing a form that
    ;;more precisely locates the violation.
    ;;
    ;;If WHO is false, SYNTAX-VIOLATION attempts to infer an appropriate
    ;;value for the  condition object (see below) as  follows: when FORM
    ;;is  either  an  identifier  or  a  list-structured  syntax  object
    ;;containing an identifier  as its first element,  then the inferred
    ;;value is the identifier's symbol.   Otherwise, no value for WHO is
    ;;provided as part of the condition object.
    ;;
    ;;The condition object provided with the exception has the following
    ;;condition types:
    ;;
    ;;*  If WHO  is not  false  or can  be inferred,  the condition  has
    ;;condition type  "&who", with WHO  as the  value of its  field.  In
    ;;that  case,  WHO should  identify  the  procedure or  entity  that
    ;;detected the  exception.  If it  is false, the condition  does not
    ;;have condition type "&who".
    ;;
    ;;* The condition has condition type "&message", with MESSAGE as the
    ;;value of its field.
    ;;
    ;;* The condition has condition type "&syntax" with FORM and SUBFORM
    ;;as the value of its fields.  If SUBFORM is not provided, the value
    ;;of the subform field is false.
    ;;
    ((who msg form)
     (syntax-violation who msg form #f))
    ((who msg form subform)
     (%syntax-violation who msg form (make-syntax-violation form subform))))

  (define (%syntax-violation source-who msg form condition-object)
    (define-constant __who__ 'syntax-violation)
    (unless (string? msg)
      (assertion-violation __who__ "message is not a string" msg))
    (let ((source-who (cond ((or (string? source-who)
				 (symbol? source-who))
			     source-who)
			    ((not source-who)
			     (syntax-match form ()
			       (id
				(identifier? id)
				(syntax->datum id))
			       ((id . rest)
				(identifier? id)
				(syntax->datum id))
			       (_  #f)))
			    (else
			     (assertion-violation __who__ "invalid who argument" source-who)))))
      (raise
       (condition (if source-who
		      (make-who-condition source-who)
		    (condition))
		  (make-message-condition msg)
		  condition-object
		  (%expression->source-position-condition form)
		  (%extract-trace form)))))

  (define (%raise-unbound-error source-who form id)
    (raise
     (condition (if source-who
		    (make-who-condition source-who)
		  (condition))
		(make-message-condition "unbound identifier")
		(make-undefined-violation)
		(make-syntax-violation form id)
		(%expression->source-position-condition id)
		(%extract-trace id))))

  (define (%extract-trace x)
    (define-condition-type &trace &condition
      make-trace trace?
      (form trace-form))
    (let f ((x x))
      (cond ((<stx>? x)
	     (apply condition
		    (make-trace x)
		    (map f (<stx>-ae* x))))
	    ((annotation? x)
	     (make-trace (make-<stx> x '() '() '())))
	    (else
	     (condition)))))

  (define (%expression->source-position-condition x)
    (expression-position x))

  #| end of module |# )


;;;; R6RS programs and libraries helpers

(define (initial-visit! macro*)
  (for-each (lambda (x)
	      (let ((loc  (car  x))
		    (proc (cadr x)))
		(set-symbol-value! loc proc)))
    macro*))


;;;; done

;;Register the expander with the library manager.
(current-library-expander expand-library)

#| end of library |# )

;;; end of file
;;Local Variables:
;;eval: (put 'build-library-letrec*		'scheme-indent-function 1)
;;eval: (put 'build-application			'scheme-indent-function 1)
;;eval: (put 'build-conditional			'scheme-indent-function 1)
;;eval: (put 'build-lambda			'scheme-indent-function 1)
;;eval: (put 'build-foreign-call		'scheme-indent-function 1)
;;eval: (put 'build-sequence			'scheme-indent-function 1)
;;eval: (put 'build-global-assignment		'scheme-indent-function 1)
;;eval: (put 'build-lexical-assignment		'scheme-indent-function 1)
;;eval: (put 'build-letrec*			'scheme-indent-function 1)
;;eval: (put 'if-wants-descriptive-gensyms	'scheme-indent-function 1)
;;End:
