; Copyright 1991 William Clinger
;
; $Id$
;
; 13 April 1999.

; Procedure calls.

(define (cg-call output exp target regs frame env tail?)
  (let ((proc (call.proc exp)))
    (cond ((and (lambda? proc)
                (list? (lambda.args proc)))
           (cg-let output exp target regs frame env tail?))
          ((not (variable? proc))
           (cg-unknown-call output exp target regs frame env tail?))
          (else (let ((entry
                       (var-lookup (variable.name proc) regs frame env)))
                  (case (entry.kind entry)
                    ((global lexical frame register)
                     (cg-unknown-call output
                                      exp
                                      target regs frame env tail?))
                    ((integrable)
                     (cg-integrable-call output
                                         exp
                                         target regs frame env tail?))
                    ((procedure)
                     (cg-known-call output
                                    exp
                                    target regs frame env tail?))
                    (else (error "Bug in cg-call" exp))))))))

(define (cg-let output exp target regs frame env tail?)
  (let* ((proc (call.proc exp))
         (vars (lambda.args proc))
         (n (length vars)))
    (if (= n 1)
        (cg-let1 output exp target regs frame env tail?)
        (let* ((args (call.args exp))
               (free (lambda.F proc))
               (temps (newtemps n))
               (alist (map cons temps vars)))
          (for-each (lambda (arg t)
                      (let ((r (choose-register regs frame)))
                        (cg0 output arg r regs frame env #f)
                        (cgreg-bind! regs r t)
                        (gen-store! output frame r t)))
                    args
                    temps)
          (cgreg-rename! regs alist)
          (cgframe-rename! frame alist)
          (cg-let-body output proc target regs frame env tail?)))))

(define (cg-let1 output exp target regs frame env tail?)
  (let* ((proc (call.proc exp))
         (v (car (lambda.args proc)))
         (arg (car (call.args exp))))
    
    (define (evaluate-into-register r)
      (cg0 output arg r regs frame env #f)
      (cgreg-bind! regs r v)
      (gen-store! output frame r v))
    
    (define (evaluate-normally)
      (evaluate-into-register (choose-register regs frame))
      (cg-let-body output proc target regs frame env tail?))
    
    (cond ((assq v *regnames*)
           (evaluate-into-register (cdr (assq v *regnames*)))
           (cg-let-body output proc target regs frame env tail?))
          
          ((not (memq v (lambda.F proc)))
           (cg0 output arg #f regs frame env #f)
           (cg-let-body output proc target regs frame env tail?))
          
          (else
           (evaluate-into-register (choose-register regs frame))
           (cg-let-body output proc target regs frame env tail?)))))

(define (cg-let-body output L target regs frame env tail?)
  (let ((vars (lambda.args L))
        (free (lambda.F L)))
    ; FIXME:  The non-tail case is important also.
    ; The tail case is easy because there are no live temporaries,
    ; and there are no free variables in the context.
    (if tail?
        (let ((keepers (cons (cgreg-lookup-reg regs 0) free)))
          (cgreg-release-except! regs keepers)
          (cgframe-release-except! frame keepers)))
    (let ((r (cg-body output L target regs frame env tail?)))
      (for-each (lambda (v)
                  (let ((entry (cgreg-lookup regs v)))
                    (if entry
                        (cgreg-release! regs (entry.regnum entry)))
                    (cgframe-release! frame v)))
                vars)
      ; FIXME: generates suboptimal code for (let ((x (+ y 1))) x).
      (if (and (not target)
               (not (eq? r 'result))
               (not (cgreg-lookup-reg regs r)))
          (cg-move output frame regs r 'result)
          r))))

(define (cg-unknown-call output exp target regs frame env tail?)
  (let* ((proc (call.proc exp))
         (args (call.args exp))
         (n (length args))
         (L (make-label)))
    (cond ((>= (+ n 1) *lastreg*)
           (cg-big-call output exp target regs frame env tail?))
          (else
           (let ((r0 (cgreg-lookup-reg regs 0)))
             (if (variable? proc)
                 (let ((entry (cgreg-lookup regs (variable.name proc))))
                   (if (and entry
                            (<= (entry.regnum entry) n))
                       (begin (cg-arguments output
                                            (iota1 (+ n 1))
                                            (append args (list proc))
                                            regs frame env)
                              (gen! output $reg (+ n 1)))
                       (begin (cg-arguments output
                                            (iota1 n)
                                            args
                                            regs frame env)
                              (cg0 output proc 'result regs frame env #f)))
                   (if tail?
                       (gen-pop! output frame)
                       (begin (cgframe-used! frame)
                              (gen! output $setrtn L)))
                   (gen! output $invoke n))
                 (begin (cg-arguments output
                                      (iota1 (+ n 1))
                                      (append args (list proc))
                                      regs frame env)
                        (gen! output $reg (+ n 1))
                        (if tail?
                            (gen-pop! output frame)
                            (begin (cgframe-used! frame)
                                   (gen! output $setrtn L)))
                        (gen! output $invoke n)))
             (if tail?
                 'result
                 (begin (gen! output $.align 4)
                        (gen! output $.label L)
                        (gen! output $.cont)
                        (cgreg-clear! regs)
                        (cgreg-bind! regs 0 r0)
                        (gen-load! output frame 0 r0)
                        (cg-move output frame regs 'result target))))))))

(define (cg-known-call output exp target regs frame env tail?)
  (let* ((args (call.args exp))
         (n (length args))
         (L (make-label)))
    (cond ((>= (+ n 1) *lastreg*)
           (cg-big-call output exp target regs frame env tail?))
          (else
           (let ((r0 (cgreg-lookup-reg regs 0)))
             (cg-arguments output (iota1 n) args regs frame env)
             (if tail?
                 (gen-pop! output frame)
                 (begin (cgframe-used! frame)
                        (gen! output $setrtn L)))
             (let* ((entry (cgenv-lookup env (variable.name (call.proc exp))))
                    (label (entry.label entry))
                    (m (entry.rib entry)))
               (if (zero? m)
                   (gen! output $branch label n)
                   (gen! output $jump m label n)))
             (if tail?
                 'result
                 (begin (gen! output $.align 4)
                        (gen! output $.label L)
                        (gen! output $.cont)
                        (cgreg-clear! regs)
                        (cgreg-bind! regs 0 r0)
                        (gen-load! output frame 0 r0)
                        (cg-move output frame regs 'result target))))))))

; Any call can be compiled as follows, even if there are no free registers.
;
; Let T0, T1, ..., Tn be newly allocated stack temporaries.
;
;     <arg0>
;     setstk  T0
;     <arg1>             -|
;     setstk  T1          |
;     ...                 |- evaluate args into stack frame
;     <argn>              |
;     setstk  Tn         -|
;     const   ()
;     setreg  R-1
;     stack   Tn         -|
;     op2     cons,R-1    |
;     setreg  R-1         |
;     ...                 |- cons up overflow args
;     stack   T_{R-1}     |
;     op2     cons,R-1    |
;     setreg  R-1        -|
;     stack   T_{R-2}      -|
;     setreg  R-2           |
;     ...                   |- pop remaining args into registers
;     stack   T1            |
;     setreg  1            -|
;     stack   T0
;     invoke  n

(define (cg-big-call output exp target regs frame env tail?)
  (let* ((proc (call.proc exp))
         (args (call.args exp))
         (n (length args))
         (argslots (newtemps n))
         (procslot (newtemp))
         (r0 (cgreg-lookup-reg regs 0))
         (R-1 (- *nregs* 1))
         (entry (if (variable? proc)
                    (let ((entry
                           (var-lookup (variable.name proc)
                                       regs frame env)))
                      (if (eq? (entry.kind entry) 'procedure)
                          entry
                          #f))
                    #f))
         (L (make-label)))
    (if (not entry)
        (begin
         (cg0 output proc 'result regs frame env #f)
         (gen-setstk! output frame procslot)))
    (for-each (lambda (arg argslot)
                (cg0 output arg 'result regs frame env #f)
                (gen-setstk! output frame argslot))
              args
              argslots)
    (cgreg-clear! regs)
    (gen! output $const '())
    (gen! output $setreg R-1)
    (do ((i n (- i 1))
         (slots (reverse argslots) (cdr slots)))
        ((zero? i))
        (if (< i R-1)
            (gen-load! output frame i (car slots))
            (begin (gen-stack! output frame (car slots))
                   (gen! output $op2 $cons R-1)
                   (gen! output $setreg R-1))))
    (if (not entry)
        (gen-stack! output frame procslot))
    (if tail?
        (gen-pop! output frame)
        (begin (cgframe-used! frame)
               (gen! output $setrtn L)))
    (if entry
        (let ((label (entry.label entry))
              (m (entry.rib entry)))
          (if (zero? m)
              (gen! output $branch label n)
              (gen! output $jump m label n)))
        (gen! output $invoke n))
    (if tail?
        'result
        (begin (gen! output $.align 4)
               (gen! output $.label L)
               (gen! output $.cont)
               (cgreg-clear! regs) ; redundant, see above
               (cgreg-bind! regs 0 r0)
               (gen-load! output frame 0 r0)
               (cg-move output frame regs 'result target)))))

(define (cg-integrable-call output exp target regs frame env tail?)
  (let ((args (call.args exp))
        (entry (var-lookup (variable.name (call.proc exp)) regs frame env)))
    (if (= (entry.arity entry) (length args))
        (begin (case (entry.arity entry)
                 ((0) (gen! output $op1 (entry.op entry)))
                 ((1) (cg0 output (car args) 'result regs frame env #f)
                      (gen! output $op1 (entry.op entry)))
                 ((2) (cg-integrable-call2 output
                                           entry
                                           args
                                           regs frame env))
                 ((3) (cg-integrable-call3 output
                                           entry
                                           args
                                           regs frame env))
                 (else (error "Bug detected by cg-integrable-call"
                              (make-readable exp))))
               (if tail?
                   (begin (gen-pop! output frame)
                          (gen! output $return)
                          'result)
                   (cg-move output frame regs 'result target)))
        (error "Wrong number of arguments to integrable procedure"
               (make-readable exp)))))

(define (cg-integrable-call2 output entry args regs frame env)
  (let ((op (entry.op entry)))
    (if (and (entry.imm entry)
             (constant? (cadr args))
             ((entry.imm entry) (constant.value (cadr args))))
        (begin (cg0 output (car args) 'result regs frame env #f)
               (gen! output $op2imm
                            op
                            (constant.value (cadr args))))
        (let* ((reg2 (cg0 output (cadr args) #f regs frame env #f))
               (r2 (choose-register regs frame))
               (t2 (if (eq? reg2 'result)
                       (let ((t2 (newtemp)))
                         (gen! output $setreg r2)
                         (cgreg-bind! regs r2 t2)
                         (gen-store! output frame r2 t2)
                         t2)
                       (cgreg-lookup-reg regs reg2))))
          (cg0 output (car args) 'result regs frame env #f)
          (let* ((r2 (or (let ((entry (cgreg-lookup regs t2)))
                           (if entry
                               (entry.regnum entry)
                               #f))
                         (let ((r2 (choose-register regs frame)))
                           (cgreg-bind! regs r2 t2)
                           (gen-load! output frame r2 t2)
                           r2))))
            (gen! output $op2 (entry.op entry) r2)
            (if (eq? reg2 'result)
                (begin (cgreg-release! regs r2)
                       (cgframe-release! frame t2)))))))
  'result)

(define (cg-integrable-call3 output entry args regs frame env)
  (let* ((reg2 (cg0 output (cadr args) #f regs frame env #f))
         (r2 (choose-register regs frame))
         (t2 (if (eq? reg2 'result)
                 (let ((t2 (newtemp)))
                   (gen! output $setreg r2)
                   (cgreg-bind! regs r2 t2)
                   (gen-store! output frame r2 t2)
                   t2)
                 (cgreg-lookup-reg regs reg2)))
         (reg3 (cg0 output (caddr args) #f regs frame env #f))
         (spillregs (choose-registers regs frame 2))
         (t3 (if (eq? reg3 'result)
                 (let ((t3 (newtemp))
                       (r3 (if (eq? t2 (cgreg-lookup-reg
                                        regs (car spillregs)))
                               (cadr spillregs)
                               (car spillregs))))
                   (gen! output $setreg r3)
                   (cgreg-bind! regs r3 t3)
                   (gen-store! output frame r3 t3)
                   t3)
                 (cgreg-lookup-reg regs reg3))))
    (cg0 output (car args) 'result regs frame env #f)
    (let* ((spillregs (choose-registers regs frame 2))
           (r2 (or (let ((entry (cgreg-lookup regs t2)))
                           (if entry
                               (entry.regnum entry)
                               #f))
                   (let ((r2 (car spillregs)))
                     (cgreg-bind! regs r2 t2)
                     (gen-load! output frame r2 t2)
                     r2)))
           (r3 (or (let ((entry (cgreg-lookup regs t3)))
                           (if entry
                               (entry.regnum entry)
                               #f))
                   (let ((r3 (if (eq? r2 (car spillregs))
                                 (cadr spillregs)
                                 (car spillregs))))
                     (cgreg-bind! regs r3 t3)
                     (gen-load! output frame r3 t3)
                     r3))))
      (gen! output $op3 (entry.op entry) r2 r3)
      (if (eq? reg2 'result)
          (begin (cgreg-release! regs r2)
                 (cgframe-release! frame t2)))
      (if (eq? reg3 'result)
          (begin (cgreg-release! regs r3)
                 (cgframe-release! frame t3)))))
  'result)


; Parallel assignment.

; Given a list of target registers, a list of expressions, and a
; compile-time environment, generates code to evaluate the expressions
; into the registers.
;
; Argument evaluation proceeds as follows:
;
; 1.  Evaluate all but one of the complicated arguments.
; 2.  Evaluate remaining arguments.
; 3.  Load spilled arguments from stack.

(define (cg-arguments output targets args regs frame env)
  
  ; Sorts the args and their targets into complicated and
  ; uncomplicated args and targets.
  ; Then it calls evalargs.
  
  (define (sortargs targets args targets1 args1 targets2 args2)
    (if (null? args)
        (evalargs targets1 args1 targets2 args2)
        (let ((target (car targets))
              (arg (car args))
              (targets (cdr targets))
              (args (cdr args)))
          (if (complicated? arg env)
              (sortargs targets
                        args
                        (cons target targets1)
                        (cons arg args1)
                        targets2
                        args2)
              (sortargs targets
                        args
                        targets1
                        args1
                        (cons target targets2)
                        (cons arg args2))))))
  
  ; Given the complicated args1 and their targets1,
  ; and the uncomplicated args2 and their targets2,
  ; evaluates all the arguments into their target registers.
  
  (define (evalargs targets1 args1 targets2 args2)
    (let* ((temps1 (newtemps (length targets1)))
           (temps2 (newtemps (length targets2))))
      (if (not (null? args1))
          (for-each (lambda (arg temp)
                      (cg0 output arg 'result regs frame env #f)
                      (gen-setstk! output frame temp))
                    (cdr args1)
                    (cdr temps1)))
      (if (not (null? args1))
          (evalargs0 (cons (car targets1) targets2)
                     (cons (car args1) args2)
                     (cons (car temps1) temps2))
          (evalargs0 targets2 args2 temps2))
      (for-each (lambda (r t)
                  (let ((temp (cgreg-lookup-reg regs r)))
                    (if (not (eq? temp t))
                        (let ((entry (var-lookup t regs frame env)))
                          (case (entry.kind entry)
                            ((register)
                             (gen! output $movereg (entry.regnum entry) r))
                            ((frame)
                             (gen-load! output frame r t)))
                          (cgreg-bind! regs r t)))
                    (cgframe-release! frame t)))
                (append targets1 targets2)
                (append temps1 temps2))))
  
  (define (evalargs0 targets args temps)
    (if (not (null? targets))
        (let ((para (let* ((regvars (map (lambda (reg)
                                           (cgreg-lookup-reg regs reg))
                                         targets)))
                      (parallel-assignment targets
                                           (map cons regvars targets)
                                           args))))
          (if para
              (let ((targets para)
                    (args (cg-permute args targets para))
                    (temps (cg-permute temps targets para)))
                (for-each (lambda (arg r t)
                            (cg0 output arg r regs frame env #f)
                            (cgreg-bind! regs r t)
                            (gen-store! output frame r t))
                          args
                          para
                          temps))
              (let ((r (choose-register regs frame))
                    (t (car temps)))
                (cg0 output (car args) r regs frame env #f)
                (cgreg-bind! regs r t)
                (gen-store! output frame r t)
                (evalargs0 (cdr targets)
                           (cdr args)
                           (cdr temps)))))))
  
  (if (parallel-assignment-optimization)
      (sortargs (reverse targets) (reverse args) '() '() '() '())
      (cg-evalargs output targets args regs frame env)))

; Left-to-right evaluation of arguments directly into targets.

(define (cg-evalargs output targets args regs frame env)
  (let ((temps (newtemps (length targets))))
    (for-each (lambda (arg r t)
                (cg0 output arg r regs frame env #f)
                (cgreg-bind! regs r t)
                (gen-store! output frame r t))
              args
              targets
              temps)
    (for-each (lambda (r t)
                (let ((temp (cgreg-lookup-reg regs r)))
                  (if (not (eq? temp t))
                      (begin (gen-load! output frame r t)
                             (cgreg-bind! regs r t)))
                  (cgframe-release! frame t)))
              targets
              temps)))

; For heuristic use only.
; An expression is complicated unless it can probably be evaluated
; without saving and restoring any registers, even if it occurs in
; a non-tail position.

(define (complicated? exp env)
  (case (car exp)
    ((quote)    #f)
    ((lambda)   #t)
    ((set!)     (complicated? (assignment.rhs exp) env))
    ((if)       (or (complicated? (if.test exp) env)
                    (complicated? (if.then exp) env)
                    (complicated? (if.else exp) env)))
    ((begin)    (if (variable? exp)
                    #f
                    (some? (lambda (exp)
                             (complicated? exp env))
                           (begin.exprs exp))))
    (else       (let ((proc (call.proc exp)))
                  (if (and (variable? proc)
                           (let ((entry
                                  (cgenv-lookup env (variable.name proc))))
                             (eq? (entry.kind entry) 'integrable)))
                      (some? (lambda (exp)
                               (complicated? exp env))
                             (call.args exp))
                      #t)))))

; Returns a permutation of the src list, permuted the same way the
; key list was permuted to obtain newkey.

(define (cg-permute src key newkey)
  (let ((alist (map cons key (iota (length key)))))
    (do ((newkey newkey (cdr newkey))
         (dest '()
               (cons (list-ref src (cdr (assq (car newkey) alist)))
                     dest)))
        ((null? newkey) (reverse dest)))))

; Given a list of register numbers,
; an association list with entries of the form (name . regnum) giving
; the variable names by which those registers are known in code,
; and a list of expressions giving new values for those registers,
; returns an ordering of the register assignments that implements a
; parallel assignment if one can be found, otherwise returns #f.

(define parallel-assignment
 (lambda (regnums alist exps)
   (if (null? regnums)
       #t
       (let ((x (toposort (dependency-graph regnums alist exps))))
         (if x (reverse x) #f)))))

(define dependency-graph
 (lambda (regnums alist exps)
   (let ((names (map car alist)))
     (do ((regnums regnums (cdr regnums))
          (exps exps (cdr exps))
          (l '() (cons (cons (car regnums)
                             (map (lambda (var) (cdr (assq var alist)))
                                  (intersection (freevariables (car exps))
                                                names)))
                       l)))
         ((null? regnums) l)))))

; Given a nonempty graph represented as a list of the form
;     ((node1 . <list of nodes that node1 is less than or equal to>)
;      (node2 . <list of nodes that node2 is less than or equal to>)
;      ...)
; returns a topological sort of the nodes if one can be found,
; otherwise returns #f.

(define toposort
 (lambda (graph)
   (cond ((null? (cdr graph)) (list (caar graph)))
         (else (toposort2 graph '())))))

(define toposort2
 (lambda (totry tried)
   (cond ((null? totry) #f)
         ((or (null? (cdr (car totry)))
              (and (null? (cddr (car totry)))
                   (eq? (cadr (car totry))
                        (car (car totry)))))
          (if (and (null? (cdr totry)) (null? tried))
              (list (caar totry))
              (let* ((node (caar totry))
                     (x (toposort2 (map (lambda (y)
                                          (cons (car y) (remove node (cdr y))))
                                        (append (cdr totry) tried))
                                   '())))
                (if x
                    (cons node x)
                    #f))))
         (else (toposort2 (cdr totry) (cons (car totry) tried))))))

(define iota (lambda (n) (iota2 n '())))

(define iota1 (lambda (n) (cdr (iota2 (+ n 1) '()))))

(define iota2
 (lambda (n l)
   (if (zero? n)
       l
       (let ((n (- n 1)))
         (iota2 n (cons n l))))))

(define (freevariables exp)
  (freevars2 exp '()))

(define (freevars2 exp env)
  (cond ((symbol? exp)
         (if (memq exp env) '() (list exp)))
        ((not (pair? exp)) '())
        (else (let ((keyword (car exp)))
                (cond ((eq? keyword 'quote) '())
                      ((eq? keyword 'lambda)
                       (let ((env (append (make-null-terminated (cadr exp))
                                          env)))
                         (apply-union
                          (map (lambda (x) (freevars2 x env))
                               (cddr exp)))))
                      ((memq keyword '(if set! begin))
                       (apply-union
                        (map (lambda (x) (freevars2 x env))
                             (cdr exp))))
                      (else (apply-union
                             (map (lambda (x) (freevars2 x env))
                                  exp))))))))
