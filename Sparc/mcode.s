! -*- Fundamental -*-
! This is the file Sparc/mcode.s.
!
! Larceny run-time system (SPARC) -- miscellaneous primitives.
!
! History
!   June 27 - July 1, 1994 / lth (v0.20)
!     Moved procedures to this file from Sparc/glue.s.

#include "asmdefs.h"

	.seg	"text"

	.global _m_apply
	.global _m_varargs
	.global	_m_typetag
	.global	_m_typetag_set
	.global	_m_eqv
	.global _m_partial_list2vector
	.global	_m_break
	.global _m_singlestep
	.global	_m_timer_exception
	.global _m_exception

	
! _m_apply: millicode for the 'apply' instruction
!
! Call from: Scheme
! Inputs   : RESULT = procedure
!            ARGREG2 = list
!            ARGREG3 = fixnum: length of list in ARGREG2
! Outputs  : Unspecified.
! Destroys : RESULT, ARGREG2, ARGREG3, temporaries
!
! The caller must validate the arguments, compute the length of the
! list, decrement the timer, and fault if the timer is not 0. The
! following code simply executes an APPLY as fast as it can.
!
! Operation:
!  - Map the (head of the) list in REG1 onto registers REG1-REG30, put the
!    tail, if any, into REG31.
!  - Move RESULT to REG0, set RESULT to the length of the list, and invoke
!    the procedure in REG0.

_m_apply:
	mov	30, %TMP0				! counter -- 30 regs
	add	%GLOBALS, G_REG1, %TMP1			! register to store
Lapply3:
	cmp	%ARGREG2, NIL_CONST			! done yet?
	be	Lapply5					!   skip if so
	nop
	ld	[ %ARGREG2 - PAIR_TAG ], %TMP2		! t = (car l)
	st	%TMP2, [ %TMP1 ]			! set a register!
	inc	4, %TMP1				! bump ptr
	deccc	1, %TMP0				! one less reg
	bg	Lapply3					!  loop, if > 0
	ld	[ %ARGREG2 + 4 - PAIR_TAG ], %ARGREG2	! l = (cdr l)
	! store tail in R31
	st	%ARGREG2, [ %GLOBALS + G_REG31 ]	! store tail
Lapply5:
	st	%o7, [ %GLOBALS + G_RETADDR ]
	call	internal_restore_vm_regs
	nop
	ld	[ %GLOBALS + G_RETADDR ], %o7

	mov	%RESULT, %REG0
	ld	[ %REG0 + A_CODEVECTOR ], %TMP0
	jmp	%TMP0 + A_CODEOFFSET
	mov	%ARGREG3, %RESULT


! _m_varargs: The ARGS>= instruction.
!
! Call from: Scheme
! Input    : RESULT = fixnum: argument count supplied
!            ARGREG2 = fixnum: minimum argument count wanted
! Output   : Nothing
! Destroys : A VM register, temporaries
!
! Most of the operation has been punted to C code; see comments in that code
! for illumination.
!
! The 0-extra-args case ought to be handled here for efficiency, but
! it gets a little hairy. Perhaps we should handle the case where there
! are 0 extra arguments and less arguments than registers, that's
! easy enough.

_m_varargs:
	cmp	%RESULT, %ARGREG2
	bge	Lvararg2
	nop
	jmp	%MILLICODE + M_EXCEPTION
	mov	EX_VARGC, %TMP0
Lvararg2:
	set	_C_varargs, %TMP0
	b	callout_to_C
	nop
	

! _m_typetag: extract typetag from structured non-pair object.
!
! Call from: Scheme
! Input:     RESULT = object
! Output:    RESULT = fixnum: typetag
! Destroys:  Temporaries, RESULT.

_m_typetag:
	and	%RESULT, 7, %TMP0
	cmp	%TMP0, VEC_TAG
	be,a	Ltypetag1
	ld	[ %RESULT - VEC_TAG ], %TMP0
	cmp	%TMP0, BVEC_TAG
	be,a	Ltypetag1
	ld	[ %RESULT - BVEC_TAG ], %TMP0
	jmp	%MILLICODE + M_EXCEPTION
	mov	EX_TYPETAG, %TMP0
Ltypetag1:
	jmp	%o7+8
	and	%TMP0, TYPETAG_MASK, %RESULT


! _m_typetag_set: set typetag of structured non-pair object.
!
! Call from: Scheme
! Input:     RESULT = object
!            ARGREG2 = fixnum: typetag
! Output:    Nothing.
! Destroys:  Temporaries.
!
! The tag must be a fixnum in the range 0-8, appropriately shifted.

_m_typetag_set:
	and	%RESULT, 7, %TMP0
	cmp	%TMP0, VEC_TAG
	be,a	Ltypetagset1
	xor	%RESULT, VEC_TAG, %TMP0
	cmp	%TMP0, BVEC_TAG
	be,a	Ltypetagset1
	xor	%RESULT, BVEC_TAG, %TMP0
Ltypetagset0:
	jmp	%MILLICODE + M_EXCEPTION
	mov	EX_TYPETAGSET, %TMP0
Ltypetagset1:
	ld	[ %TMP0 ], %TMP1
	andncc	%ARGREG2, TYPETAG_MASK, %g0
	bne	Ltypetagset0
	nop
	andn	%TMP1, TYPETAG_MASK, %TMP1
	or	%TMP1, %ARGREG2, %TMP1
	jmp	%o7 + 8
	st	%TMP1, [ %TMP0 ]


! _m_eqv: the EQV? procedure
!
! Call from: Scheme
! Input:     RESULT = object
!            ARGREG2 = object
! Output:    #t or #f
! Destroys:  RESULT, Temporaries
!
! This procedure is entered only if the two arguments are not eq?.
! Note that fixnums and immediates are always eq? if they are eqv?, so we need
! only concern ourselves with larger structures here.

_m_eqv:
	! Do fixnums first to get them out of the way completely.
	! If operands are fixnums, then they are not eqv?.

	tsubcc	%RESULT, %ARGREG2, %g0
	bvs,a	Leqv_others
	xor	%RESULT, %ARGREG2, %TMP0	! => 0 if they are the same
	b	Leqv_done
	mov	FALSE_CONST, %RESULT

Leqv_others:
	andcc	%TMP0, TAGMASK, %g0		! get that common tag
	bne,a	Leqv_done
	mov	FALSE_CONST, %RESULT

	! Tags are equal, but addresses are not (they are not eq?). This
	! lets us get rid of all non-numeric types.

	and	%RESULT, TAGMASK, %TMP0
	cmp	%TMP0, PAIR_TAG
	be,a	Leqv_done
	mov	FALSE_CONST, %RESULT
	cmp	%TMP0, PROC_TAG
	be,a	Leqv_done
	mov	FALSE_CONST, %RESULT
	cmp	%TMP0, BVEC_TAG
	be	Leqv_bvec
	nop
	cmp	%TMP0, VEC_TAG
	be	Leqv_vec
	nop
	b	Leqv_done
	mov	FALSE_CONST, %RESULT

Leqv_bvec:
	! Bytevector-like

	ldub	[ %RESULT - BVEC_TAG + 3 ], %TMP0
	ldub	[ %ARGREG2 - BVEC_TAG + 3 ], %TMP1

	cmp	%TMP0, BIGNUM_HDR
	be,a	Leqv_bvec2
	mov	0, %TMP0
	cmp	%TMP0, FLONUM_HDR
	be,a	Leqv_bvec2
	mov	1, %TMP0
	cmp	%TMP0, COMPNUM_HDR
	be,a	Leqv_bvec2
	mov	1,%TMP0
	b	Leqv_done
	mov	FALSE_CONST, %RESULT
Leqv_bvec2:
	cmp	%TMP1, BIGNUM_HDR
	be,a	Leqv_number
	mov	0, %TMP1
	cmp	%TMP1, FLONUM_HDR
	be,a	Leqv_number
	mov	1, %TMP1
	cmp	%TMP1, COMPNUM_HDR
	be,a	Leqv_number
	mov	1, %TMP1
	b	Leqv_done
	mov	FALSE_CONST, %RESULT

Leqv_vec:
	! We know it has a vector tag here. The header tags must be the same,
	! and both must be either ratnum or rectnum.

	ldub	[ %RESULT - VEC_TAG + 3 ], %TMP0
	ldub	[ %ARGREG2 - VEC_TAG + 3 ], %TMP1

	cmp	%TMP0, %TMP1
	bne,a	Leqv_done
	mov	FALSE_CONST, %RESULT

	mov	0, %TMP1
	cmp	%TMP0, RATNUM_HDR
	be,a	Leqv_number
	mov	0, %TMP0
	cmp	%TMP0, RECTNUM_HDR
	be,a	Leqv_number
	mov	0, %TMP0
	b	Leqv_done
	mov	FALSE_CONST, %RESULT

Leqv_number:
	! Numbers. They are eqv if they are of the same exactness and they
	! test #t with `='. The exactness is encoded in TMP0 and TMP1: 0s
	! mean exact, 1s mean inexact.

	cmp	%TMP0, %TMP1
	bne,a	Leqv_done
	mov	FALSE_CONST, %RESULT

	! Same exactness. Test for equality.

	jmp	%MILLICODE + M_NUMEQ
	nop

Leqv_done:
	jmp	%o7+8
	nop


! _m_partial_list2vector: do the grunge for list->vector.
!
! Call from: Scheme
! Input    : RESULT = proper list
!            ARGREG2 = fixnum: length of list
! Output   : RESULT = vector
! Destroys : RESULT, ARGREG2, ARGREG3, temporaries
!
! list->vector is a partial primop because the Scheme implementation 
! (make the vector, bang the elements) causes a lot of unneccesary side
! effect checking in the generation-scavenging collector. It is not a full
! primop because of the harrowing details of dealing with non-lists etc.
! 
! The correctness of this code depends on the vector being allocated in
! the ephemeral space.

_m_partial_list2vector:
	st	%o7, [ %GLOBALS + G_RETADDR ]	! save return address
	mov	%RESULT, %ARGREG3		! save for later
	call	_mem_internal_alloc
	add	%ARGREG2, 4, %RESULT		! length of vector
	ld	[ %GLOBALS + G_RETADDR ], %o7	! restore retaddr

	sll	%ARGREG2, 8, %TMP0		! length field
	or	%TMP0, VEC_HDR, %TMP0           !   for header
	st	%TMP0, [ %RESULT ]		! store vector header
	add	%RESULT, 4, %TMP0		! TMP0 = destination pointer
	mov	%ARGREG3, %TMP1			! TMP1 = list pointer
	mov	%ARGREG2, %TMP2			! TMP2 = counter (fixnum)
	b	Ll2v_1
	tst	%TMP2				! done yet?
Ll2v_2:	
	st	%ARGREG3, [ %TMP0 ]		! store in vector
	add	%TMP0, 4, %TMP0			! next element
	ld	[ %TMP1 - PAIR_TAG + 4 ], %TMP1	! get cdr
	subcc	%TMP2, 4, %TMP2			! one less
Ll2v_1:
	bne,a	Ll2v_2				! loop if not done
	ld	[ %TMP1 - PAIR_TAG ], %ARGREG3	! get car

	jmp	%o7+8
	or	%RESULT, VEC_TAG, %RESULT


! _m_break: breakpoint handler.
!
! Call from: Scheme
! Input:     Nothing
! Output:    Nothing
! Destroys:  Temporaries

_m_break:
	ld	[ %GLOBALS + G_BREAKPT_ENABLE ], %TMP0
	cmp	%TMP0, TRUE_CONST
	be,a	Lbreak1
	nop
	jmp	%o7+8
	nop
Lbreak1:
	set	_C_break, %TMP0
	b	callout_to_C
	nop


! _m_singlestep: singlestep handler.
!
! Call from: Scheme
! Input:     ARGREG2 = fixnum: constant vector index
! Output:    Unspecified
! Destroys:  Temporaries
!
! The constant slot has to contain a string, and that string will usually
! be the printable representation of the MacScheme instruction to be executed 
! next.

_m_singlestep:
	ld	[ %GLOBALS + G_SINGLESTEP_ENABLE ], %TMP0
	cmp	%TMP0, TRUE_CONST
	be,a	Lsinglestep1
	nop
	jmp	%o7+8
	nop
Lsinglestep1:
	set	_C_singlestep, %TMP0
	b	callout_to_C
	mov	%ARGREG2, %TMP1


! _m_timer_exception: exception handler for timer expiration.
!
! Call from: Scheme
! Input:     Nothing
! Output:    Nothing
! Destroys:  Temporaries

_m_timer_exception:
	ld	[ %GLOBALS + G_TIMER_ENABLE ], %TMP0
	cmp	%TMP0, TRUE_CONST
	be,a	_m_exception
	mov	EX_TIMER, %TMP0
	jmp	%o7+8
	nop


! _m_exception: General exception handler.
!
! Call from: Scheme
! Input:     TMP0 = fixnum: exception code.
!            RESULT, ARGREG2, ARGREG3 = objects: operands to the primitive.
! Output:    Undefined
! Destroys:  Temporaries
!
! The return address must point to the instruction which would have been
! returned to if the operation had succeeded, i.e., the exception handler
! must repair the error if the program is to continue.

_m_exception:
	ld	[ %GLOBALS + G_CALLOUTS ], %TMP1
	ld	[ %TMP1 - GLOBAL_CELL_TAG + CELL_VALUE_OFFSET ], %TMP1
	cmp	%TMP1, UNSPECIFIED_CONST
	be	Lexception
	nop
	mov	4, %TMP1
	b	internal_scheme_call
	mov	MS_EXCEPTION_HANDLER, %TMP2
	! never returns
Lexception:
	mov	%TMP0, %TMP1
	set	_C_exception, %TMP0
	b	callout_to_C
	nop


! end-of-file
