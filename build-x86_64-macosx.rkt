#!/usr/bin/env racket
#lang racket

;; This is a script to compile the native packages for OS X.

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline)

(define cores 1)
(command-line
 #:program "build"
 #:once-each
 [("-j") cores* "Cores"
         (set! cores cores*)])

(define-runtime-path here ".")

(define git (find-executable-path "git"))
(define otool (find-executable-path "otool"))
(define install-name-tool (find-executable-path "install_name_tool"))
(define make (find-executable-path "make"))
(void
 (parameterize ([current-directory (build-path here "openh264-src")])
   (system* git "clean" "-fxd")
   (system* make (format "-j~a" cores) "all" "install" (format "PREFIX=~a" (current-directory))))
 (parameterize ([current-directory (build-path here "ffmpeg-src")]
                [current-environment-variables
                 (environment-variables-copy (current-environment-variables))])
   (system* git "clean" "-fxd")
   (system* (build-path (current-directory) "configure")
            "--enable-shared"
            "--disable-sdl2"
            "--disable-indev=jack"
            "--enable-libopenh264"
            (format "--prefix=~a" (current-directory)))
            ;"--libdir='@loader_path'")
   (system* make (format "-j~a" cores))
   (system* make "install")))

(define avutil "libavutil.55.dylib")
(define swresample "libswresample.2.dylib")
(define swscale "libswscale.4.dylib")
(define avcodec "libavcodec.57.dylib")
(define avformat "libavformat.57.dylib")
(define avfilter "libavfitler.6.dylib")

(define ffmpeg-def-table
  (hash avutil (set avutil)
        swresample (set avutil swresample)
        swscale (set avutil swscale)
        avcodec (set avutil swresample avcodec)
        avformat (set avutil avcodec swresample)
        avfilter (set avutil avformat avcodec swscale swresample)))

(void
 (parameterize ([current-directory (build-path here "ffmpeg-src//" "lib")])
   (define (rename input libname)
     (define from (path->string (build-path (current-directory) libname)))
     (define to (format "@loader_path/~a" libname))
     (system* install-name-tool "-change" from to input))
   (for ([(lib target-set) (in-dict ffmpeg-def-table)])
     (for ([target target-set])
       (rename lib target)))))
