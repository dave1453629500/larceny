; Larceny runtime library.
; Memory management support stuff in Scheme.
;
; $Id: memstats.sch,v 1.2 1992/06/13 08:08:53 lth Exp lth $
;
; Memory statistics is maintained by the parts of the system written in C,
; but the storage for the statistics is all in the Scheme heap. In order to
; get this right, there is a magic global (in that it is pointed to by a
; dedicated root, MEMSTATS_VECTOR_OFFSET) which holds a pointer to the 
; memstats vector; said vector is allocated and put into the global by 
; "install-memstats-vector", below. The run-time system must be able to 
; function even if the vector is absent, as it is put into the global only 
; after the initial phase of the initialization.
;
; 'Memstats-vector' is a global variable which contains a vector with 
; statistics about the memory allocation and garbage collection. It has
; the following entries:
;
;  0: ephemeral-collections (fixnum)
;  1: tenuring-collections (fixnum)
;  2: full-collections (fixnum)
;  3: words-collected-hi (fixnum)
;  4: words-collected-lo (fixnum)
;  5: words-allocated-hi (fixnum)
;  6: words-allocated-lo (fixnum)
;  7: words-copied-hi (fixnum)
;  8: words-copied-lo (fixnum)
;  9: time-spent-collecting-in-milliseconds (fixnum)
; 10: the number of used words in the ephemeral area after last collection (fn)
; 11: a boolean: must we tenure during the next ephemeral collection?
; 12: time-spent-in-last-collection-in-milliseconds (fixnum)
; 13: total-transactions-scanned (fixnum)
; 14: total-transactions-registered (fixnum) (#13 >= #14)
; 15: transactions-left-after-last (fixnum)
; 16: stackframes-flushed (fixnum)
; 17: words-of-heap-allocated-to-flushed-frames-hi (fixnum)
; 18: words-of-heap-allocated-to-flushed-frames-lo (fixnum)
;
; Some entries have a high and a low part so that the low levels of the system
; do not have to use bignums to keep the counts.

(define (install-memstats-vector)
  (set! memstats-vector (make-vector 19 0)))

; This procedure is the only reasonable way to access the memstats vector. 
; It coalesces the split values in the vector and returns a vector with
; counts of collections, counts of words, and time spent collecting.

(define memstats
  (let ((two^29 536870912))  ; (expt 2 29)
    (lambda ()
      (vector (vector-ref memstats-vector 0)
	      (vector-ref memstats-vector 1)
	      (vector-ref memstats-vector 2)
	      (+ (* (vector-ref memstats-vector 3) two^29)
		 (vector-ref memstats-vector 4))
	      (+ (* (vector-ref memstats-vector 5) two^29)
		 (vector-ref memstats-vector 6))
	      (+ (* (vector-ref memstats-vector 7) two^29)
		 (vector-ref memstats-vector 8))
	      (vector-ref memstats-vector 9)
	      (vector-ref memstats-vector 12)
	      (vector-ref memstats-vector 13)
	      (vector-ref memstats-vector 14)
	      (vector-ref memstats-vector 16)
	      (+ (* (vector-ref memstats-vector 17) two^29)
		 (vector-ref memstats-vector 18))))))


; "label-memstats" takes a vector as returned from "memstats" and returns
; a list of lists. Each sublist has a label and the correct value from the
; memstats vector.

(define (label-memstats v)
  (list (list 'ephemeral-collections (vector-ref v 0))
	(list 'tenuring-collections (vector-ref v 1))
	(list 'full-collections (vector-ref v 2))
	(list 'words-collected (vector-ref v 3))
	(list 'words-allocated (vector-ref v 4))
	(list 'words-copied (vector-ref v 5))
	(list 'time-collecting (vector-ref v 6))
	(list 'time-last-collection (vector-ref v 7))
	(list 'transactions-scanned (vector-ref v 8))
	(list 'transactions-registered (vector-ref v 9))
	(list 'frames-flushed (vector-ref v 10))
	(list 'words-allocated-to-flushed-frames (vector-ref v 11))))


;; Return resource parameters in a vector.
;; The vector currently has five elements:
;;
;;  0: User time (ms)
;;  1: System time (ms)
;;  2: Wall clock time (ms)
;;  3: Minor page faults
;;  4: Major page faults
;;
;; All quantities are fixnums. For long-running systems, the wall clock time
;; field may wrap around (after 149 hours, in fact). This could be fixed in a
;; way similar to what is done in the memstats vector.

(define (resource-usage)
  (let ((v (make-vector 5 0)))
    (sys$resource-usage! v)
    v))


;; For backward compatibility 

(define (getrusage)
  (vector-ref (resource-usage) 0))


; Takes a vector as returned from memstats and displays it with useful
; labels. 
;
; Arguably does not belong in this file.

(define (display-memstats v)
  (display "Ephemeral collections: ") (display (vector-ref v 0)) (newline)
  (display "Tenuring collections: ") (display (vector-ref v 1)) (newline)
  (display "Full collections: ") (display (vector-ref v 2)) (newline)
  (display "Words collected: ") (display (vector-ref v 3)) (newline)
  (display "Words allocated: ") (display (vector-ref v 4)) (newline)
  (display "Words copied: ") (display (vector-ref v 5)) (newline)
  (display "Time spent in collector: ") (display (vector-ref v 6)) 
  (display " ms") (newline)
  (display "Time spent in last collection: ") (display (vector-ref v 7))
  (display " ms") (newline)
  (display "Transactions scanned: ") (display (Vector-ref v 8)) (newline)
  (display "Transactions registered: ") (display (vector-ref v 9)) (newline)
  (display "Stack frames flushed: ") (display (vector-ref v 10)) (newline)
  (display "Heap words allocated to flushed frames: ") 
  (display (vector-ref v 11)) (newline)
  #t)

; Run a thunk and print out stats afterwards about how long it took and
; how much memory was used. This is accurate only if a collection is performed
; immediately prior to calling this procedure, and in fact a collection should
; be performed after the thunk returns as well to get a completely accurate
; picture. See comments in the code.
;
; Returns the result of the thunk.
;
; Arguably does not belong in this file.

(define (run-with-stats thunk)

  (define (munge-stats s1 s2)
    (vector (- (vector-ref s2 0) (vector-ref s1 0))
	    (- (vector-ref s2 1) (vector-ref s1 1))
	    (- (vector-ref s2 2) (vector-ref s1 2))
	    (- (vector-ref s2 3) (vector-ref s1 3))
	    (- (vector-ref s2 4) (vector-ref s1 4))
	    (- (vector-ref s2 5) (vector-ref s1 5))
	    (- (vector-ref s2 6) (vector-ref s1 6))
	    (vector-ref s2 7)
	    (- (vector-ref s2 8) (vector-ref s1 8))
	    (- (vector-ref s2 9) (vector-ref s1 9))
	    (- (vector-ref s2 10) (vector-ref s1 10))
	    (- (vector-ref s2 11) (vector-ref s1 11))))
  
  (let* ((s1 (memstats))   ; should be (begin (collect 'ephemeral) (memstats))
	 (t1 (getrusage))
	 (r  (thunk))
	 (t2 (getrusage))
	 (s2 (memstats)))  ; ditto
    (display "Time: ") (display (- t2 t1)) (display " ms") (newline)
    (display-memstats (munge-stats s1 s2))
    r))

; eof
