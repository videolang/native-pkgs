#lang racket

(provide (all-defined-out))

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline)

(define-runtime-path here ".")

(define gcc (find-executable-path "gcc"))
(define make (find-executable-path "make"))

(define cores 4)

(define (build-libvid target-dir target-name)
  (parameterize ([current-directory (build-path here "libvid-src")])
    (define args
      `(,gcc "-m64" "-Wall" "-Werror"
             "-shared"
             ,@(case (system-type 'os)
                 [(macosx) (list "-undefined" "dynamic_lookup")]
                 [else '()])
             "-o" ,(if (absolute-path? target-dir)
                       (build-path target-dir target-name)
                       (build-path here target-dir target-name))
             "-I../ffmpeg-src/include"
             "-fPIC"
             "libvid.c"))
    (apply system* args)))
