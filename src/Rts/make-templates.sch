; -*- mode: makefile; indent-tabs-mode: t; tab-width: 8 -*-
;
; Copyright 2004 Lars T Hansen
;
; The program GENERATE-MAKEFILE generates a simple makefile from a
; selected configuration.  Normally it is used to generate Rts/Makefile
; by the BUILD-MAKEFILE in the build script.
;
; The generated makefile will always have libpetit.whatever as the default
; target, so executing "make" without arguments will usually be enough.
;
; TO DO:
; Some of the targets, like 'clean', are still Unix-specific.

(define (generate-makefile makefile-name configuration)
  (let ((c (assq configuration *makefile-configurations*)))
    (if (not c)
	(begin
	  (newline)
	  (display "ERROR: No configuration for ")
	  (display configuration)
	  (newline)
	  (newline)
	  (display "Available configurations are: ")
	  (newline)
	  (for-each (lambda (c)
		      (display "   ")
		      (display (car c))
		      (newline))
		    *makefile-configurations*))
	(begin
	  (delete-file makefile-name)
	  (call-with-output-file makefile-name
	    (lambda (out)
	      (call-with-values (cdr c)
		(lambda (definitions target)
		  (display "# Generated by Rts/make-templates.sch" out)
		  (newline out)
		  (display "# Configuration: " out)
		  (display configuration out)
		  (newline out)
		  (newline out)
		  (display definitions out)
		  (newline out)
		  (newline out)
		  (display make-template-file-sets out)
		  (newline out)
		  (newline out)
		  (display make-template-rule-sets out)
		  (newline out)
		  (newline out)
		  (display target out)
		  (newline out)
		  (newline out)
                  ;; hack to work around bug in heap dumping 
                  ;; (can't have strings with length > 4092)
		  (display (string-append
                            make-template-rts-dependencies-1
                            make-template-rts-dependencies-2)
                            out)
		  (newline out)
		  (newline out)
		  (display make-template-standard-targets out)
		  (newline out)
		  (newline out)))))))))

(define *makefile-configurations*
  `((sparc-solaris-static-gcc
     . ,(lambda ()
	  (values make-template-sparc-solaris-gcc-gas 
		  make-template-target-sparc-solaris)))
    (sparc-solaris-static-gcc-bdw
     . ,(lambda ()
	  (values make-template-sparc-solaris-gcc-gas 
		  make-template-target-sparc-solaris-bdw)))
    (sparc-solaris-static-cc
     . ,(lambda ()
	  (values make-template-sparc-solaris-cc-as 
		  make-template-target-sparc-solaris)))
    (sparc-solaris-static-cc-bdw
     . ,(lambda ()
	  (values make-template-sparc-solaris-cc-as 
		  make-template-target-sparc-solaris-bdw)))
    (petit-unix-shared-gcc
     . ,(lambda ()
	  (values make-template-petit-unix-gcc
		  make-template-target-petit-unix-shared)))
    (petit-macosx-shared-gcc
     . ,(lambda ()
	  (values make-template-petit-macosx-gcc-shared 
		  make-template-target-petit-macosx-shared)))
    (petit-unix-static-gcc
     . ,(lambda () 
	  (values make-template-petit-unix-gcc
		  make-template-target-petit-unix-static)))
    (petit-win32-static-mingw
     . ,(lambda () 
	  (values make-template-petit-unix-gcc
		  make-template-target-petit-unix-static)))
    (petit-win32-static-codewarrior
     . ,(lambda () 
	  (values make-template-petit-win32-cw6
		  make-template-target-petit-win32-static)))
    (petit-win32-static-visualc
     . ,(lambda () 
	  (values make-template-petit-win32-visualc
		  make-template-target-petit-win32-static)))
    (petit-osf/1-static-decc
     . ,(lambda ()
	  (values make-template-petit-osf1-decc
		  make-template-target-petit-unix-static)))
    (x86-win32-static-visualc-nasm
     . ,(lambda ()
	  (values make-template-petit-win32-visualc
		  make-template-target-nasm-x86-win32-static)))
    (x86-win32-static-visualc 
     . ,(lambda ()
	  (values make-template-sassy-win32-visualc
		  make-template-target-sassy-win32)))
    (x86-unix-static-gcc-nasm
     . ,(lambda () 
	  (values make-template-petit-unix-gcc
		  make-template-target-nasm-x86-unix-static)))
    (sassy-macosx-static-gcc-nasm
     . ,(lambda () 
	  (values make-template-sassy-macosx-gcc
		  make-template-target-sassy-unix-static)))
    (sassy-unix-static-gcc-nasm
     . ,(lambda () 
	  (values make-template-sassy-unix-gcc
		  make-template-target-sassy-unix-static)))))

(define-syntax define-make-template
  (syntax-rules ()
    ((_ template-name string-arg)
     (define template-name (string-append common-make-template "\n" string-arg)))))

(define (template-common uncommon)
  (string-append
"INC_ROOT = ../../include
CFLAGS    = -ISys -I$(INC_ROOT) -I$(INC_ROOT)/Sys -I$(INC_ROOT)/Shared $(DEBUGINFO) $(OPTIMIZE)
ASFLAGS   = -I$(INC_ROOT)/ -I$(INC_ROOT)/Sys/ -I$(INC_ROOT)/Shared/
" uncommon))

; Petit Larceny: Unix: gcc
; Petit Larceny: Win32: gcc under cygwin or mingw
; Petit Larceny: MacOS X: gcc (not building a shared library)
; Petit Larceny with x86 back-end: Unix: NASM macro assembler
(define make-template-petit-unix-gcc
  (template-common
"O=o
CC=gcc
DEBUGINFO=#-gstabs+
OPTIMIZE=-O3 -DNDEBUG2 # -DNDEBUG
CFLAGS+=-c -falign-functions=4 -I$(INC_ROOT)/Standard-C
AS=nasm
ASFLAGS+=-f elf -I$(INC_ROOT)/Nasm/ -DLINUX"))

; Native Larceny with Sassy back-end: Unix: NASM macro assembler for Rts
(define make-template-sassy-unix-gcc
  (template-common
"O=o
CC=gcc
DEBUGINFO=#-g -gstabs+
OPTIMIZE=-O3 -DNDEBUG2 # -DNDEBUG
CFLAGS+=-c -falign-functions=4 -m32
LIBS=-ldl -lm
AS=nasm
ASFLAGS+=-f elf -g -DLINUX"))

(define make-template-sassy-macosx-gcc
  (template-common
"O=o
CC=gcc
DEBUGINFO=#-g -gstabs+
OPTIMIZE=-O3 -DNDEBUG2 # -DNDEBUG
CFLAGS+=-c -falign-functions=4 -ISys -IBuild -IIAssassin $(DEBUGINFO) $(OPTIMIZE)
LIBS=-ldl -lm
AS=nasm
ASFLAGS+=-f macho -g -IIAssassin/ -IBuild/ -DMACOSX"))


; Petit Larceny: MacOS X: gcc (building a shared library)
(define make-template-petit-macosx-gcc-shared
  (template-common
"O=o
CC=gcc
DEBUGINFO=#-gstabs+
OPTIMIZE=-O3 -DNDEBUG2 # -DNDEBUG
CFLAGS+=-c -fno-common -I$(INC_ROOT)/Standard-C"))

; Petit Larceny: Win32: Metrowerks CodeWarrior 6
(define make-template-petit-win32-cw6
  (template-common
"O=obj
CC=mwcc
OPT=-opt on
DEBUG=-g
CFLAGS=-c $(DEBUG) $(OPT) -I$(INC_ROOT)/Standard-C
LIBS=-lm
.c.obj:
	$(CC) -c $(CFLAGS) -o $*.obj $<"))

; Petit Larceny: Win32: Microsoft Visual C/C++ with DOS shell
; Probably not up-to-date, has not been tested for some time!
(define make-template-petit-win32-visualc
  (template-common
"O=obj
CC=cl
AS=nasmw
.asm.obj: 
	nasmw -f win32 -DWIN32 -I$(INC_ROOT)/Sys/ -I$(INC_ROOT)/Nasm -I$(INC_ROOT)/ -o $*.obj $<
.c.obj:
	cl /c /Zp4 /O2 /Zi /ISys /I$(INC_ROOT)/Sys /I$(INC_ROOT)/Shared /I$(INC_ROOT)/Standard-C /I$(INC_ROOT) /DSTDC_SOURCE /Fo$*.obj $<"))

; Petit Larceny: DEC Alpha OSF/1: DEC C compiler
; Probably not up-to-date, has not been tested for some time!
(define make-template-petit-osf1-decc
  (template-common
"CC=cc
CCXFLAGS=-g3 -taso -xtaso_short -ieee
LD_SHARED=ld -shared -taso -g3 -soname libpetit.so -o libpetit.so -lm -lc -all
# Needed because make leaves the -o off.
# Why is this here?  See other .c.o rule below.
.c.o:
	$(CC) $(CFLAGS) -c $< -o $*.o"))

(define make-template-sparc-solaris-common
"O=o
DEBUG=-gstabs+
OPTIMIZE=-O3 -DNDEBUG2 # -DNDEBUG
PROFILE=#-pg
TCOV=#-a -g
BDW_DEBUG=-DBDW_DEBUG #-DBDW_CLEAR_STACK
LDXFLAGS=#Util/ffi-dummy.o  # For compiling with -p (avoids linker trouble)
CFLAGS+=-c -I$(INC_ROOT)/Standard-C \\
	$(DEBUG) $(OPTIMIZE) $(PROFILE) $(TCOV) $(BDW_DEBUG) $(CCXFLAGS)
CCXFLAGS=-D__USE_FIXED_PROTOTYPES__ -Wpointer-arith -Wmissing-prototypes \\
	-Wimplicit -Wreturn-type -Wunused -Wuninitialized
AS=../Build/gasmask.sh
LIBS=-lm -ldl
.c.o:
	$(CC) $(CFLAGS) -DUSER=\\\"$$LOGNAME\\\" -DDATE=\"\\\"`date '+%Y-%m-%d %T'`\\\"\" -o $*.o $<")

; Solaris: SPARC-native Larceny: gcc and GNU assembler
(define make-template-sparc-solaris-gcc-gas
  (template-common
    (string-append
"CC=gcc
AS=../Build/gasmask.sh
ASFLAGS+=-ISparc
"
     make-template-sparc-solaris-common)))

; Solaris: SPARC-native Larceny: Sun C and Sun assembler
;
; Use the above definition with the following ones.  The Sun assembler
; runs the preprocessor for us and the gasmask script is not required.
(define make-template-sparc-solaris-cc-as
  (template-common
    (string-append
"CC=cc
AS=as
ASFLAGS+=-P -ISparc
"
     make-template-sparc-solaris-common)))

; X86-WIN32
(define make-template-sassy-win32-visualc
  (template-common
"O=obj
CC=cl
.asm.obj: 
	nasmw -f win32 -DWIN32 -I$(INC_ROOT)/Sys/ -I$(INC_ROOT)/Shared/ -I$(INC_ROOT)/ -o $*.obj $<
.c.obj:
	cl /c /Zp4 /O2 /Zi /ISys /I$(INC_ROOT)/Sys /I$(INC_ROOT)/Shared /I$(INC_ROOT) /DSTDC_SOURCE /Fo$*.obj $<
"))

;;;;;
;;;;; Targets
;;;;;

; SPARC-SOLARIS
(define make-template-target-sparc-solaris
"larceny.bin: $(LARCENY_OBJECTS) Util/ffi-dummy.o
	$(CC) $(PROFILE) $(TCOV) -o larceny.bin $(LARCENY_OBJECTS) \\
		$(LIBS) $(EXTRALIBS) $(EXTRALIBPATH) $(LDXFLAGS)
	/bin/rm -f Sys/version.o")

; X86-WIN32
(define make-template-target-sassy-win32
"larceny.bin.exe: $(X86_SASSY_LARCENY_OBJECTS) Util/ffi-dummy.o
	$(CC) $(PROFILE) $(TCOV) -o larceny.bin.exe $(X86_SASSY_LARCENY_OBJECTS) \\
		$(LIBS) $(EXTRALIBS) $(EXTRALIBPATH) $(LDXFLAGS)
	del Sys\\version.$(O)")

; SPARC-SOLARIS with Boehm collector
(define make-template-target-sparc-solaris-bdw
"bdwlarceny.bin: $(BDW_LARCENY_OBJECTS) Util/ffi-dummy.o
	( cd bdw-gc ; make gc.a )
	$(CC) $(PROFILE) $(TCOV) -o bdwlarceny.bin $(BDW_LARCENY_OBJECTS) \\
		$(LIBS) $(EXTRALIBS) $(EXTRALIBPATH) \\
		$(BOEHM_GC_LIBRARIES) $(LDXFLAGS) $(LDYFLAGS)
	/bin/rm -f Sys/version.o")

; Unix: generic
; Win32: cygwin
; Win32: mingw, if you're not using dynamic loading (other targets further down)
(define make-template-target-petit-unix-static
"libpetit.a: $(PETIT_LARCENY_OBJECTS)
	ar -r libpetit.a $(PETIT_LARCENY_OBJECTS)
	ranlib libpetit.a")

; Unix: generic gcc
(define make-template-target-petit-unix-shared
"libpetit.so: $(PETIT_LARCENY_OBJECTS)
	gcc -shared -o libpetit.so $(PETIT_LARCENY_OBJECTS)")

; SunOS 5.6 (not tested much lately)
(define make-template-target-petit-solaris-shared
"libpetit.so: $(PETIT_LARCENY_OBJECTS)
	ld -G -o libpetit.so -L/usr/lib -lc $(PETIT_LARCENY_OBJECTS) \\
		$(LIBS) $(EXTRALIBS) $(EXTRALIBPATH) $(LDXFLAGS)
	/bin/rm -f Sys/version.o")

; MacOS X dynamic shared library
; You need to set your DYLD_LIBRARY_PATH to point to Rts/ to load this.
(define make-template-target-petit-macosx-shared
"libpetit.dylib: $(PETIT_LARCENY_OBJECTS)
	gcc -undefined suppress -flat_namespace -dynamiclib \\
	 	-o libpetit.dylib $(PETIT_LARCENY_OBJECTS)")

; Win32: mingw, if you're using dynamic loading
(define make-template-target-petit-win32-mingw-shared
"libpetit.dll: $(PETIT_LARCENY_OBJECTS)
	dllwrap --output-lib=libpetit.lib --dllname=libpetit.dll \\
		--driver-name=gcc $(PETIT_LARCENY_OBJECTS)")

; Win32: other compilers
(define make-template-target-petit-win32-static
"libpetit.lib: $(PETIT_LARCENY_OBJECTS)
	lib /libpath:Rts /name:libpetit /out:libpetit.lib \\
	   $(PETIT_LARCENY_OBJECTS)")

; Win32: Intel x86 with the NASM back-end
(define make-template-target-nasm-x86-win32-static
"libpetit.lib: $(X86_NASM_LARCENY_OBJECTS)
	lib /libpath:Rts /name:libpetit /out:libpetit.lib \\
	   $(X86_NASM_LARCENY_OBJECTS)")

; Unix: Intel x86 with the NASM back-end
(define make-template-target-nasm-x86-unix-static
"libpetit.a: $(X86_NASM_LARCENY_OBJECTS)
	ar -r libpetit.a $(X86_NASM_LARCENY_OBJECTS)
	ranlib libpetit.a")

(define make-template-target-sassy-unix-static
"larceny.bin: $(X86_SASSY_LARCENY_OBJECTS)
	$(CC) $(PROFILE) -m32 $(TCOV) -o larceny.bin $(X86_SASSY_LARCENY_OBJECTS) \\
		$(LIBS) $(EXTRALIBS) $(EXTRALIBPATH) $(LDXFLAGS)
	rm Sys/version.$(O)")

; Big bags of files
(define make-template-file-sets
"COMMON_RTS_OBJECTS=\\
	Sys/argv.$(O) Sys/barrier.$(O) Sys/callback.$(O) Sys/gc_t.$(O) \\
	Sys/ldebug.$(O) Sys/malloc.$(O) Sys/osdep-generic.$(O) \\
	Sys/osdep-macos.$(O) Sys/osdep-unix.$(O) Sys/osdep-win32.$(O) \\
	Sys/primitive.$(O) Sys/signals.$(O) Sys/sro.$(O) Sys/stack.$(O) \\
	Sys/syscall.$(O) Sys/util.$(O) Sys/version.$(O)

PRECISE_GC_OBJECTS=\\
	Sys/alloc.$(O) Sys/cheney.$(O) Sys/gc.$(O) \\
	Sys/cheney-check.$(O) Sys/cheney-np.$(O) Sys/cheney-split.$(O) \\
	Sys/heapio.$(O) Sys/los.$(O) Sys/memmgr.$(O) Sys/ffi.$(O) \\
	Sys/msgc-core.$(O) Sys/np-sc-heap.$(O) Sys/nursery.$(O) \\
	Sys/old_heap_t.$(O) Sys/old-heap.$(O) \\
	Sys/seqbuf.$(O) Sys/remset.$(O) Sys/remset-np.$(O) \\
	Sys/sc-heap.$(O) Sys/semispace.$(O) Sys/static-heap.$(O) \\
	Sys/stats.$(O) Sys/young_heap_t.$(O)

BOEHM_GC_OBJECTS=\\
	Sys/bdw-gc.$(O) Sys/bdw-stats.$(O) Sys/bdw-collector.$(O) \\
	Sys/bdw-heapio.$(O) Sys/bdw-ffi.$(O)

BOEHM_GC_SPARC_OBJECTS=\\
	Sparc/bdw-memory.$(O) Sparc/bdw-generic.$(O) Sparc/bdw-cglue.$(O)

BOEHM_GC_LIBRARIES=\\
	bdw-gc/gc.a

COMMON_SPARC_OBJECTS=\\
	Sparc/barrier.$(O) Sparc/cache.$(O) Sparc/cache0.$(O) \\
	Sparc/glue.$(O) Sparc/mcode.$(O) Sparc/signals.$(O) \\
	Sparc/syscall2.$(O) sparc-table.$(O)

SPARC_PRECISE_GC_OBJECTS=\\
	Sparc/memory.$(O) Sparc/generic.$(O) Sparc/cglue.$(O)

PETIT_OBJECTS=\\
	Shared/arithmetic.$(O) Standard-C/millicode.$(O) \\
	Shared/multiply.$(O) Standard-C/syscall2.$(O) c-table.$(O)

X86_NASM_OBJECTS=\\
	Shared/arithmetic.$(O) Standard-C/millicode.$(O) \\
	Nasm/i386-driver.$(O) Shared/i386-millicode.$(O) \\
	Shared/multiply.$(O) Standard-C/syscall2.$(O) nasm-table.$(O)

X86_SASSY_OBJECTS=\\
	Shared/arithmetic.$(O) IAssassin/millicode.$(O) \\
	IAssassin/i386-driver.$(O) Shared/i386-millicode.$(O) \\
	Shared/multiply.$(O) IAssassin/syscall2.$(O) nasm-table.$(O)

X86_SASSY_LARCENY_OBJECTS=\\
	Sys/larceny.$(O)\\
	IAssassin/config.$(O)\\
	$(COMMON_RTS_OBJECTS)\\
	$(PRECISE_GC_OBJECTS)\\
	$(X86_SASSY_OBJECTS)	

# SPARC only
LARCENY_OBJECTS=\\
	Sys/larceny.$(O) \\
	Sparc/config.$(O) \\
	$(COMMON_RTS_OBJECTS) \\
	$(COMMON_SPARC_OBJECTS) \\
	$(PRECISE_GC_OBJECTS) \\
	$(SPARC_PRECISE_GC_OBJECTS)

# SPARC only
BDW_LARCENY_OBJECTS=\\
	Sys/bdw-larceny.$(O) \\
	Sparc/config.$(O) \\
	$(COMMON_RTS_OBJECTS) \\
	$(COMMON_SPARC_OBJECTS) \\
	$(BOEHM_GC_OBJECTS) \\
	$(BOEHM_GC_SPARC_OBJECTS)

# Generic Unix
PETIT_LARCENY_OBJECTS=\\
	Sys/larceny.$(O) \\
	Standard-C/config.$(O) \\
	$(COMMON_RTS_OBJECTS) \\
	$(PRECISE_GC_OBJECTS) \\
	$(PETIT_OBJECTS)

# Intel x86 with the NASM backend
X86_NASM_LARCENY_OBJECTS=\\
	Sys/larceny.$(O) \\
	Standard-C/config.$(O) \\
	$(COMMON_RTS_OBJECTS) \\
	$(PRECISE_GC_OBJECTS) \\
	$(X86_NASM_OBJECTS)

")

(define make-template-rule-sets
".SUFFIXES:	.asm
.c.o:
	$(CC) -c $(CFLAGS) $(CPPFLAGS) -o $@ $<
.s.o:
	$(AS) -o $*.o $< $(ASFLAGS)
.asm.o:
	$(AS) -o $*.o $< $(ASFLAGS)")

(define make-template-standard-targets
"hsplit: Util/hsplit.o
	$(CC) $(PROFILE) $(TCOV) $(DEBUGINFO) $(LDXFLAGS) -o hsplit \\
	   Util/hsplit.o

Util/hsplit.o: Util/hsplit.c
	$(CC) -g -o Util/hsplit.o -I$(INC_ROOT) -I$(INC_ROOT)/Sys -c Util/hsplit.c

clean:
	rm -f larceny.bin larceny.bin.exe hsplit bdwlarceny.bin petit-larceny core \\
	   Build/*.$(O) Nasm/*.$(O) Sparc/*.$(O) Standard-C/*.$(O) \\
	   Sys/*.$(O) Util/*.$(O) \\
	   libpetit.lib libpetit.so libpetit.dylib libpetit.a libpetit.dll \\
	   Shared/arithmetic.c

rtsclean: clean
	rm -f Build/*.s Build/*.*h

realclean: clean
	if [ -d bdw-gc ]; then ( cd bdw-gc ; make clean ); fi
	rm -rf Build")

(define make-template-rts-dependencies-1
"LARCENY_H=$(INC_ROOT)/Sys/larceny-types.h $(INC_ROOT)/Sys/macros.h \\
	  Sys/assert.h Sys/larceny.h \\
	  $(INC_ROOT)/cdefs.h $(INC_ROOT)/config.h
SPARC_ASM_H=$(INC_ROOT)/asmdefs.h Sparc/asmmacro.h
PETIT_H=$(INC_ROOT)/Shared/millicode.h $(INC_ROOT)/Shared/petit-config.h \\
	$(INC_ROOT)/Shared/petit-machine.h

Shared/arithmetic.$(O): $(LARCENY_H) $(PETIT_H)
Standard-C/millicode.$(O): $(LARCENY_H) $(PETIT_H) Sys/gc_t.h Sys/barrier.h \\
	Sys/stack.h
IAssassin/millicode.$(O): $(LARCENY_H) $(PETIT_H) Sys/gc_t.h Sys/barrier.h \\
	Sys/stack.h
Shared/i386-millicode.$(O): $(LARCENY_H)
IAssassin/i386-driver.$(O): $(LARCENY_H) 
Shared/multiply.$(O): $(LARCENY_H) $(PETIT_H)
Standard-C/syscall2.$(O): $(LARCENY_H) $(PETIT_H)
IAssassin/syscall2.$(O): $(LARCENY_H) $(PETIT_H)
Standard-C/config.$(O): $(LARCENY_H) $(PETIT_H)

Sparc/barrier.$(O): $(SPARC_ASM_H)
Sparc/bdw-memory.$(O): Sparc/memory.s $(SPARC_ASM_H)
Sparc/cache.$(O): $(LARCENY_H)
Sparc/cache0.$(O): $(SPARC_ASM_H)
Sparc/cglue.$(O): $(LARCENY_H) Sys/signals.h
Sparc/bdw-cglue.$(O): Sparc/cglue.c $(LARCENY_H) Sys/signals.h
Sparc/generic.$(O): $(SPARC_ASM_H)
Sparc/bdw-generic.$(O): Sparc/generic.s $(SPARC_ASM_H)
Sparc/glue.$(O): $(SPARC_ASM_H)
Sparc/mcode.$(O): $(SPARC_ASM_H)
Sparc/memory.$(O): $(SPARC_ASM_H)
Sparc/signals.$(O): $(LARCENY_H)
Sparc/syscall2.$(O): $(LARCENY_H)")

(define make-template-rts-dependencies-2 "

Sys/alloc.$(O): $(LARCENY_H) Sys/barrier.h Sys/gclib.h Sys/semispace_t.h
Sys/argv.$(O): $(LARCENY_H)
Sys/barrier.$(O): $(LARCENY_H) Sys/memmgr.h Sys/barrier.h
Sys/bdw-collector.$(O): $(LARCENY_H) Sys/barrier.h Sys/gc.h Sys/gc_t.h \\
	Sys/gclib.h Sys/stats.h Sys/memmgr.h Sys/stack.h \\
	bdw-gc/include/gc.h
Sys/bdw-gc.$(O): Sys/gc.c $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/heapio.h \\
	Sys/static_heap_t.h
Sys/bdw-larceny.$(O): Sys/larceny.c $(LARCENY_H) Sys/gc.h
Sys/bdw-stats.$(O): Sys/stats.c $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/memmgr.h
Sys/bdw-ffi.$(O): Sys/ffi.c $(LARCENY_H)
Sys/callback.$(O): $(LARCENY_H)
Sys/cheney.$(O): $(LARCENY_H) Sys/barrier.h Sys/gc_t.h Sys/gclib.h \\
	Sys/los_t.h Sys/memmgr.h Sys/semispace_t.h Sys/static_heap_t.h
Sys/cheney-np.$(O): $(LARCENY_H) Sys/barrier.h Sys/gc_t.h Sys/gclib.h \\
	Sys/los_t.h Sys/memmgr.h Sys/semispace_t.h Sys/static_heap_t.h
Sys/cheney-split.$(O): $(LARCENY_H) Sys/barrier.h Sys/gc_t.h Sys/gclib.h \\
	Sys/los_t.h Sys/memmgr.h Sys/semispace_t.h Sys/static_heap_t.h
Sys/cheney-check.$(O): $(LARCENY_H) Sys/barrier.h Sys/gc_t.h Sys/gclib.h \\
	Sys/los_t.h Sys/memmgr.h Sys/semispace_t.h Sys/static_heap_t.h
Sys/ffi.$(O): $(LARCENY_H)
Sys/gc.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/heapio.h Sys/semispace_t.h \\
	Sys/static_heap_t.h
Sys/gc_t.$(O): $(LARCENY_H) Sys/gc_t.h
Sys/heapio.$(O): $(LARCENY_H) Sys/heapio.h Sys/semispace_t.h Sys/gclib.h
Sys/larceny.$(O): $(LARCENY_H) Sys/gc.h
Sys/ldebug.$(O): $(LARCENY_H)
Sys/los.$(O): $(LARCENY_H) Sys/gclib.h Sys/los_t.h
Sys/malloc.$(O): $(LARCENY_H)
Sys/memmgr.$(O): $(LARCENY_H) Sys/barrier.h Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/heapio.h Sys/los_t.h Sys/memmgr.h \\
	Sys/old_heap_t.h Sys/remset_t.h Sys/static_heap_t.h Sys/young_heap_t.h 
Sys/np-sc-heap.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/los_t.h Sys/memmgr.h Sys/old_heap_t.h \\
	Sys/remset_t.h Sys/semispace_t.h Sys/young_heap_t.h
Sys/nursery.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/los_t.h Sys/memmgr.h Sys/stack.h \\
	Sys/young_heap_t.h
Sys/old_heap_t.$(O): $(LARCENY_H) Sys/old_heap_t.h
Sys/old-heap.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/los_t.h Sys/memmgr.h Sys/old_heap_t.h \\
	Sys/remset_t.h Sys/semispace_t.h Sys/static_heap_t.h Sys/young_heap_t.h
Sys/osdep.$(O): $(LARCENY_H)
Sys/seqbuf.$(O): $(LARCENY_H) Sys/gclib.h Sys/seqbuf_t.h
Sys/remset.$(O): $(LARCENY_H) Sys/gclib.h Sys/memmgr.h Sys/remset_t.h
Sys/remset-np.$(O): $(LARCENY_H) Sys/gclib.h Sys/memmgr.h Sys/remset_t.h
Sys/sc-heap.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/los_t.h Sys/memmgr.h Sys/semispace_t.h \\
	Sys/stack.h Sys/static_heap_t.h Sys/young_heap_t.h
Sys/semispace.$(O): $(LARCENY_H) Sys/gclib.h Sys/semispace_t.h
Sys/signals.$(O): $(LARCENY_H) Sys/signals.h
Sys/sro.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h Sys/heapio.h \\
	Sys/memmgr.h
Sys/stack.$(O): $(LARCENY_H) Sys/stack.h
Sys/static-heap.$(O): $(LARCENY_H) Sys/gc.h Sys/gclib.h Sys/stats.h \\
	Sys/memmgr.h Sys/semispace_t.h Sys/static_heap_t.h
Sys/stats.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h Sys/gclib.h \\
	Sys/stats.h Sys/memmgr.h
Sys/syscall.$(O): $(LARCENY_H) Sys/signals.h
Sys/primitive.$(O): $(LARCENY_H)  Sys/signals.h
Sys/osdep-unix.$(O): $(LARCENY_H)
Sys/osdep-win32.$(O): $(LARCENY_H)
Sys/osdep-generic.$(O): $(LARCENY_H)
Sys/util.$(O): $(LARCENY_H) Sys/gc.h Sys/gc_t.h
Sys/version.$(O): $(INC_ROOT)/config.h
Sys/young_heap_t.$(O): $(LARCENY_H) Sys/young_heap_t.h")

; eof
