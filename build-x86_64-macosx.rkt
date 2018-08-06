#!/usr/bin/env racket
#lang racket

;; This is a script to compile the native packages for OS X.

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline
         "build-lib.rkt")

(define cores 1)
(command-line
 #:program "build"
 #:once-each
 [("-j") cores* "Cores"
         (set! cores cores*)])

(define-runtime-path here ".")

(define fribidi "libfribidi.0.dylib")
(define openh264 "libopenh264.4.dylib")
(define avutil "libavutil.56.dylib")
(define swresample "libswresample.3.dylib")
(define swscale "libswscale.5.dylib")
(define avcodec "libavcodec.58.dylib")
(define avformat "libavformat.58.dylib")
(define avfilter "libavfilter.7.dylib")
(define libvid "libvid.0.dylib")

(define ffmpeg-target (build-path here "ffmpeg-x86_64-macosx"))
(define openh264-target (build-path here "openh264-x86_64-macosx"))
(define fribidi-target (build-path here "fribidi-x86_64-macosx"))
(define libvid-target (build-path here "libvid-x86_64-macosx"))

(define git (find-executable-path "git"))
(define otool (find-executable-path "otool"))
(define install-name-tool (find-executable-path "install_name_tool"))
(define make (find-executable-path "make"))
(define gcc (find-executable-path "gcc"))

(define (building-lib lib)
  (displayln "==================================================================")
  (printf "Building ~a~n" lib)
  (displayln "=================================================================="))

(parameterize ([current-directory here]
               [current-environment-variables
                (environment-variables-copy (current-environment-variables))])
  (putenv "PKG_CONFIG_PATH"
          (string-join (list (path->string (simple-form-path "libpng-src/lib/pkgconfig"))
                             (path->string (simple-form-path "freetype2-src/lib/build/pkgconfig"))
                             (path->string (simple-form-path "openh264-src")))
                       ":"))
  (parameterize ([current-directory (build-path here "libpng16-src")])
    (building-lib "libpng")
    (system* git "checkout" ".")
    (system* git "clean" "-fxd")
    (system* (simple-form-path "autogen.sh"))
    (system* (simple-form-path "configure")
             (format "--prefix=~a" (current-directory)))
    (system* make (format "-j~a" cores))
    (system* make "install"))
  (parameterize ([current-directory (build-path here "freetype2-src")])
    (building-lib "freetype2")
    (system* git "checkout" ".")
    (system* git "clean" "-fxd")
    (make-directory (simple-form-path "build"))
    (system* (simple-form-path "autogen.sh"))
    (system* (simple-form-path "configure")
             (format "--prefix=~a" (simple-form-path "build")))
    (system* make (format "-j~a" cores))
    (system* make "install"))
  (parameterize ([current-directory (build-path here "libass-src")])
    (building-lib "libass")
    (system* git "clean" "-fxd")
    (system* (simple-form-path "autogen.sh"))
    (system* (simple-form-path "configure")
             (format "--prefix=~a" (current-directory)))
    (system* make (format "-j~a" cores))
    (system* make "install"))
  (parameterize ([current-directory (build-path here "openh264-src")])
    (building-lib "openh264")
    (system* git "clean" "-fxd")
    (system* make (format "-j~a" cores) "all" "install" (format "PREFIX=~a" (current-directory))))
  (building-lib "frei0r")
  (build-frei0r)
  (building-lib "ffmpeg")
  (build-ffmpeg ffmpeg-target 'macosx)
  (building-lib "libvid")
  (build-libvid libvid-target "libvid.0.dylib" 'macosx 64))

(define ffmpeg-def-table
  (hash avutil (set)
        swresample (set avutil)
        swscale (set avutil)
        avcodec (set avutil swresample)
        avformat (set avutil avcodec swresample)
        avfilter (set avutil avformat avcodec swscale swresample)))

(void
 (parameterize ([current-directory (build-path here "libvid-src")])
   (system* install-name-tool
            "-change" 
            (format "~a/~a/~a"
                    (path->string (simplify-path (build-path here "ffmpeg-src/")))
                    "lib"
                    avutil)
            (format "@loader_path/~a" avutil)
            libvid)))

(void
 (system* install-name-tool "-id"
          (format "@loader_path/~a" openh264)
          (build-path here "openh264-src" "lib" openh264)))

(copy-file (build-path here "openh264-src" "lib" openh264)
           (build-path openh264-target openh264)
           #t)

(copy-file (build-path here "libvid-src" libvid)
           (build-path libvid-target libvid)
           #t)
