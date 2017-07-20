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

(define openh264 "libopenh264.4.dylib")
(define avutil "libavutil.55.dylib")
(define swresample "libswresample.2.dylib")
(define swscale "libswscale.4.dylib")
(define avcodec "libavcodec.57.dylib")
(define avformat "libavformat.57.dylib")
(define avfilter "libavfilter.6.dylib")

(define ffmpeg-target (build-path here "ffmpeg-x86_64-macosx"))
(define openh264-target (build-path here "openh264-x86_64-macosx"))

(define git (find-executable-path "git"))
(define otool (find-executable-path "otool"))
(define install-name-tool (find-executable-path "install_name_tool"))
(define make (find-executable-path "make"))

(void
#;
 (parameterize ([current-directory (build-path here "libass-src")])
   (system* git "clean" "-fxd")
   (system* (build-path (current-directory) "autogen.sh"))
   (system* (build-path (current-directory) "configure")
            (format "--prefix=~a" (current-directory)))
   (system* make (format "-j~a" cores))
   (system* make "install"))
 (parameterize ([current-directory (build-path here "openh264-src")])
   (system* git "clean" "-fxd")
   (system* make (format "-j~a" cores) "all" "install" (format "PREFIX=~a" (current-directory))))
 (parameterize ([current-directory (build-path here "ffmpeg-src")]
                [current-environment-variables
                 (environment-variables-copy (current-environment-variables))])
   (putenv "PKG_CONFIG_PATH" (path->string (build-path here "openh264-src")))
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


(define ffmpeg-def-table
  (hash avutil (set)
        swresample (set avutil)
        swscale (set avutil)
        avcodec (set avutil swresample)
        avformat (set avutil avcodec swresample)
        avfilter (set avutil avformat avcodec swscale swresample)))

(void
 (parameterize ([current-directory (build-path here "ffmpeg-src" "lib")])
   (define (rename input libname relative-to)
     (define from
       (format "~a/~a/~a"
               (path->string (simplify-path (build-path here relative-to)))
               "lib"
               libname))
     (define to (format "@loader_path/~a" libname))
     (system* install-name-tool "-change" from to input))
   (for ([(lib target-set) (in-dict ffmpeg-def-table)])
     (for ([target target-set])
       (rename lib target "ffmpeg-src/"))
     (rename lib openh264 "openh264-src/")
     (system* install-name-tool "-id"
              (format "@loader_path/~a" lib)
              lib))))

(void
 (system* install-name-tool "-id"
          (format "@loader_path/~a" openh264)
          (build-path here "openh264-src" "lib" openh264)))

(for ([(lib target-set) (in-dict ffmpeg-def-table)])
  (copy-file (build-path here "ffmpeg-src" "lib" lib)
             (build-path ffmpeg-target lib)
             #t))

(copy-file (build-path here "openh264-src" "lib" openh264)
           (build-path openh264-target openh264)
           #t)
