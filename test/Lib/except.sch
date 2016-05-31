;;; Lots of things ought to raise exceptions.
;;; We should check to make sure they do.
;;;
;;; FIXME: currently limited to R5RS procedures.

(define (run-exception-tests)
  (run-r5rs-exception-tests))

(define (arithmetic-exceptions name f)
  (allof name
   (mustfail name f 'a)
   (mustfail name f 'a 3)
   (mustfail name f 3 'a)
   (mustfail name f 'a 0)
   (mustfail name f 0 'a)
   (mustfail name f 'a 1)
   (mustfail name f 1 'a)
   (mustfail name f 'a 2 3)
   (mustfail name f 1 'b 3)
   (mustfail name f 1 2 'c)))

(define (arithmetic-exceptions-real-only name f)
  (allof name
   (arithmetic-exceptions name f)
   (mustfail name f 3+4i)
   (mustfail name f 3.0+4.0i)
   (mustfail name f 3 0+4i)
   (mustfail name f 0+4i 3)
   (mustfail name f 3.0 0.0+4.0i)
   (mustfail name f 0.0+4.0i 3.0)))

(define (char-exceptions name f)
  (allof name
   (mustfail name f 'a)
   (mustfail name f 'a #\b)
   (mustfail name f #\a 'b)
   (mustfail name f 'a #\b #\c)
   (mustfail name f #\a 'b #\c)
   (mustfail name f #\a #\b 'c)))

(define (string-exceptions name f)
  (allof name
   (mustfail name f 'a)
   (mustfail name f 'a "b")
   (mustfail name f "a" 'b)
   (mustfail name f 'a "b" "c")
   (mustfail name f "a" 'b "c")
   (mustfail name f "a" "b" 'c)))

;;; Exported by (scheme r5rs).

(define (run-r5rs-exception-tests)

  (allof "arithmetic exceptions"
   (arithmetic-exceptions "*" *)
   (arithmetic-exceptions "+" +)
   (arithmetic-exceptions "-" -)
   (arithmetic-exceptions "/" /)
   (mustfail "/" / 7 0)
   (arithmetic-exceptions-real-only "<"  <)
   (arithmetic-exceptions-real-only "<=" <=)
   (arithmetic-exceptions "="  =)
   (arithmetic-exceptions-real-only ">"  >)
   (arithmetic-exceptions-real-only ">=" >=)
   (arithmetic-exceptions-real-only "abs" abs)
   (arithmetic-exceptions "acos" acos)
   (arithmetic-exceptions "angle" angle)
   (arithmetic-exceptions "asin" asin)
   (arithmetic-exceptions "atan" atan)
   (arithmetic-exceptions-real-only "ceiling" ceiling)
   (arithmetic-exceptions "cos" cos)
   (arithmetic-exceptions-real-only "denominator" denominator)
   (arithmetic-exceptions-real-only "even?" even?)
   (arithmetic-exceptions "exact->inexact" exact->inexact)
   (arithmetic-exceptions "exact?" exact?)
   (arithmetic-exceptions "exp" exp)
   (arithmetic-exceptions "expt" expt)
   (arithmetic-exceptions-real-only "floor" floor)
   (arithmetic-exceptions-real-only "gcd" gcd)
   (arithmetic-exceptions "imag-part" imag-part)
   (arithmetic-exceptions "inexact->exact" inexact->exact)
   (arithmetic-exceptions "inexact?" inexact?)
   (arithmetic-exceptions-real-only "lcm" lcm)
   (arithmetic-exceptions "log" log)
   (arithmetic-exceptions "magnitude" magnitude)
   (arithmetic-exceptions-real-only "make-polar" make-polar)
   (arithmetic-exceptions-real-only "make-rectangular" make-rectangular)
   (arithmetic-exceptions-real-only "max" max)
   (arithmetic-exceptions-real-only "min" min)
   (arithmetic-exceptions-real-only "modulo" modulo)
   (arithmetic-exceptions-real-only "negative?" negative?)
   (arithmetic-exceptions-real-only "numerator" numerator)
   (arithmetic-exceptions-real-only "odd?" odd?)
   (arithmetic-exceptions-real-only "positive?" positive?)
   (arithmetic-exceptions "quotient" quotient)
   (arithmetic-exceptions "rationalize" rationalize)
   (arithmetic-exceptions "real-part" real-part)
   (arithmetic-exceptions-real-only "remainder" remainder)
   (arithmetic-exceptions-real-only "round" round)
   (arithmetic-exceptions "sin" sin)
   (arithmetic-exceptions "sqrt" sqrt)
   (arithmetic-exceptions "tan" tan)
   (arithmetic-exceptions-real-only "truncate" truncate)
   (arithmetic-exceptions "zero?" zero?))

  (allof "list exceptions"
   (mustfail "append" append 'a 'b)
   (mustfail "assoc" assoc 'a 'b)
   (mustfail "assoc" assoc 'a '(b c))
   (mustfail "assq" assq 'a 'b)
   (mustfail "assq" assq 'a '(b c))
   (mustfail "assv" assv 'a 'b)
   (mustfail "assv" assv 'a '(b c))
   (mustfail "caaaar" caaaar 'a)
   (mustfail "caaadr" caaadr 'a)
   (mustfail "caaar" caaar 'a)
   (mustfail "caadar" caadar 'a)
   (mustfail "caaddr" caaddr 'a)
   (mustfail "caadr" caadr 'a)
   (mustfail "caar" caar 'a)
   (mustfail "cadaar" cadaar 'a)
   (mustfail "cadadr" cadadr 'a)
   (mustfail "cadar" cadar 'a)
   (mustfail "caddar" caddar 'a)
   (mustfail "cadddr" cadddr 'a)
   (mustfail "caddr" caddr 'a)
   (mustfail "cadr" cadr 'a)
   (mustfail "car" car 'a)
   (mustfail "cdaaar" cdaaar 'a)
   (mustfail "cdaar" cdaar 'a)
   (mustfail "cdaddr" cdaddr 'a)
   (mustfail "cdar" cdar 'a)
   (mustfail "cddadr" cddadr 'a)
   (mustfail "cdddar" cdddar 'a)
   (mustfail "cdddr" cdddr 'a)
   (mustfail "cdr" cdr 'a)
   (mustfail "cdaadr" cdaadr 'a)
   (mustfail "cdadar" cdadar 'a)
   (mustfail "cdadr" cdadr 'a)
   (mustfail "cddaar" cddaar 'a)
   (mustfail "cddar" cddar 'a)
   (mustfail "cddddr" cddddr 'a)
   (mustfail "cddr" cddr 'a)
   (mustfail "cons" cons 'a)
   (mustfail "cons" cons 'a 'b 'c)
   (mustfail "length" length 'a)
   (mustfail "length" length '(a b . c))
;  (mustfail "length" length (let ((x (list 'a))) (set-cdr! x x) x)) ; FIXME
   (mustfail "list-ref" list-ref 'a 0)
   (mustfail "list-ref" list-ref '() 0)
   (mustfail "list-ref" list-ref '(a) 1)
   (mustfail "list-tail" list-tail 'a 1)
   (mustfail "list-tail" list-tail '() 1)
   (mustfail "list-tail" list-tail '(a) 2)
   (mustfail "member" member 'a 'b)
   (mustfail "member" member 'a '(b . c))
   (mustfail "memq" memq 'a 'b)
   (mustfail "memq" memq 'a '(b . c))
   (mustfail "memv" memv 'a 'b)
   (mustfail "memv" memv 'a '(b . c))
   (mustfail "reverse" reverse 'a)
   (mustfail "reverse" reverse '(a . b))
   (mustfail "set-car!" set-car! 'a 'b)
   (mustfail "set-cdr!" set-cdr! 'a 'b))

  (allof "procedural exceptions"
   (mustfail "for-each" for-each 'a 'b)
   (mustfail "for-each" for-each 'a '(b . c))
   (mustfail "map" map 'a 'b)
   (mustfail "map" map 'a '(b . c))
   (mustfail "apply" apply 'a 'b)
   (mustfail "apply" apply list 'b)
   (mustfail "call-with-current-continuation" call-with-current-continuation)
   (mustfail "call-with-current-continuation"
             call-with-current-continuation
             'a)
   (mustfail "call-with-current-continuation"
             call-with-current-continuation
             cons)
   (mustfail "call-with-values" call-with-values 'a 'b)
   (mustfail "call-with-values" call-with-values 'a list)
   (mustfail "call-with-values" call-with-values list 'a)
   (mustfail "dynamic-wind" dynamic-wind 'a 'b 'c)
   (mustfail "dynamic-wind" dynamic-wind 'a list list)
   (mustfail "dynamic-wind" dynamic-wind list 'b list)
   (mustfail "dynamic-wind" dynamic-wind list list 'c)
   (mustfail "dynamic-wind" dynamic-wind cons list list)
   (mustfail "dynamic-wind" dynamic-wind list cons list)
   (mustfail "dynamic-wind" dynamic-wind list list cons))

  (allof "basic input/output exceptions"
   (mustfail "open-input-file" open-input-file 'a)
   (mustfail "open-output-file" open-output-file 'a)
   (mustfail "call-with-input-file" call-with-input-file 'a list)
   (mustfail "call-with-input-file" call-with-input-file "/dev/null" 'a)
   (mustfail "call-with-output-file" call-with-output-file 'a list)
   (mustfail "call-with-output-file" call-with-output-file "/dev/null" 'a)
   (mustfail "close-input-port" close-input-port 'a)
   (mustfail "close-output-port" close-output-port 'a)
   (mustfail "with-input-from-file" with-input-from-file 'a list)
   (mustfail "with-input-from-file" with-input-from-file "/dev/null" cons)
   (mustfail "with-output-to-file" with-output-to-file 'a list)
   (mustfail "with-output-to-file" with-output-to-file "/dev/null" cons)
   (mustfail "display" display 'a 'b)
   (mustfail "display" display 'a (current-input-port))
   (mustfail "write" write 'a 'b)
   (mustfail "write" write 'a (current-input-port))
   (mustfail "write-char" write-char 'a)
   (mustfail "write-char" write-char #\a 'b)
   (mustfail "write-char" write-char #\a (current-input-port))
   (mustfail "newline" newline 'a)
   (mustfail "newline" newline (current-input-port))
   (mustfail "read" read 'a)
   (mustfail "read" read (current-output-port))
   (mustfail "char-ready?" char-ready? 'a)
   (mustfail "char-ready?" char-ready? (current-output-port))
   (mustfail "peek-char" peek-char 'a)
   (mustfail "peek-char" peek-char (current-output-port))
   (mustfail "read-char" read-char 'a)
   (mustfail "read-char" read-char (current-output-port))
   (mustfail "load" load 'a))

  (allof "char exceptions"
   (char-exceptions "char<=?" char<=?)
   (char-exceptions "char<?" char<?)
   (char-exceptions "char=?" char=?)
   (char-exceptions "char>=?" char>=?)
   (char-exceptions "char>?" char>?)
   (char-exceptions "char-ci<=?" char-ci<=?)
   (char-exceptions "char-ci<?" char-ci<?)
   (char-exceptions "char-ci=?" char-ci=?)
   (char-exceptions "char-ci>=?" char-ci>=?)
   (char-exceptions "char-ci>?" char-ci>?)
   (char-exceptions "char->integer" char->integer)
   (char-exceptions "char-alphabetic?" char-alphabetic?)
   (char-exceptions "char-downcase" char-downcase)
   (char-exceptions "char-lower-case?" char-lower-case?)
   (char-exceptions "char-numeric?" char-numeric?)
   (char-exceptions "char-upcase" char-upcase)
   (char-exceptions "char-upper-case?" char-upper-case?)
   (char-exceptions "char-whitespace?" char-whitespace?)
   (char-exceptions "char->integer" char->integer)
   (mustfail "integer->char" integer->char -1)
   (mustfail "integer->char" integer->char #xd800)
   (mustfail "integer->char" integer->char #xdfff)
   (mustfail "integer->char" integer->char #x110000))

  (allof "string exceptions"
   (string-exceptions "string<=?" string<=?)
   (string-exceptions "string<?" string<?)
   (string-exceptions "string=?" string=?)
   (string-exceptions "string>=?" string>=?)
   (string-exceptions "string>?" string>?)
   (string-exceptions "string-ci<=?" string-ci<=?)
   (string-exceptions "string-ci<?" string-ci<?)
   (string-exceptions "string-ci=?" string-ci=?)
   (string-exceptions "string-ci>=?" string-ci>=?)
   (string-exceptions "string-ci>?" string-ci>?)
   (mustfail "string->list" string->list 'a)
   (mustfail "list->string" list->string '(a b))
   (mustfail "make-string" make-string 0 'a)
   (mustfail "make-string" make-string 1 'a)
   (mustfail "make-string" make-string 'a #\b)
   (mustfail "make-string" make-string -1 #\b)
   (mustfail "string->number" string->number 'a)
   (mustfail "string->symbol" string->symbol 'a)
   (mustfail "string-append" string-append 'a)
   (mustfail "string-append" string-append 'a "b")
   (mustfail "string-append" string-append "a" 'b)
   (mustfail "string-copy" string-copy 'a)
   (mustfail "string-fill!" string-fill! 'a #\b)
   (mustfail "string-fill!" string-fill! (make-string 10 #\a) 'b)
   (mustfail "string-length" string-length 'a)
   (mustfail "string-ref" string-ref 'a 0)
   (mustfail "string-ref" string-ref "" 0)
   (mustfail "string-ref" string-ref "a" 1)
   (mustfail "string-set!" string-set! 'a 0 #\b)
   (mustfail "string-set!" string-set! (string) 0 #\b)
   (mustfail "string-set!" string-set! (string #\a) 0 'b)
   (mustfail "string-set!" string-set! (string #\a) 1 #\b)
   (mustfail "substring" substring "" -1 0)
   (mustfail "substring" substring "" 0 1)
   (mustfail "substring" substring "" 'a 0)
   (mustfail "substring" substring "" 0 'b)
   (mustfail "substring" substring "xyz" -1 0)
   (mustfail "substring" substring "xyz" 3 4)
   (mustfail "substring" substring "xyz" 'a 0)
   (mustfail "substring" substring "xyz" 0 'b)
   (mustfail "symbol->string" symbol->string "a"))

  (allof "vector exceptions"
   (mustfail "vector->list" vector->list 'a)
   (mustfail "list->vector" list->vector 'a)
   (mustfail "make-vector" make-vector 'a 'b)
   (mustfail "make-vector" make-vector -1 'b)
   (mustfail "vector-fill!" vector-fill! 'a 'b)
   (mustfail "vector-length" vector-length 'a)
   (mustfail "vector-ref" vector-ref 'a 0)
   (mustfail "vector-ref" vector-ref '#() 0)
   (mustfail "vector-ref" vector-ref '#(a) 1)
   (mustfail "vector-set!" vector-set! 'a 0 'b)
   (mustfail "vector-set!" vector-set! (vector) 0 'b)
   (mustfail "vector-set!" vector-set! (vector #\a) 1 'b))

  ;; FIXME: most of these tests raise an exception that isn't caught
  ;; by the exception handler set up by mustfail, and the test that
  ;; doesn't do that isn't even raising an exception.

  (allof "eval exceptions"
   (mustfail "eval" eval 17 'a)
;  (mustfail "eval" eval this-is-surely-undefined (interaction-environment))
;  (mustfail "eval" eval cons (null-environment 'a))
   (mustfail "eval" eval cons (null-environment 5))
#; (mustfail "eval" eval cons (scheme-report-environment 'a))))