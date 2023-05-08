#!/usr/bin/env racket
#lang racket

;; This is a script to compile the native packages for OS X.

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline
         "build-lib.rkt")

(define-runtime-path here ".")
(define libvid-target (build-path here "libvid-aarch64-macosx"))
(build-libvid libvid-target "libvid.0.dylib" 'macosx 64)

#|
(define cores 1)
(command-line
 #:program "build"
 #:once-each
 [("-j") cores* "Cores"
         (set! cores cores*)])

(define-runtime-path here ".")

(fribidi "libfribidi.0.dylib")
(openh264 "libopenh264.4.dylib")
(avutil "libavutil.56.dylib")
(swresample "libswresample.3.dylib")
(swscale "libswscale.5.dylib")
(avcodec "libavcodec.58.dylib")
(avformat "libavformat.58.dylib")
(avfilter "libavfilter.7.dylib")
(avdevice "libavdevice.58.dylib")
(libvid "libvid.0.dylib")

(define ffmpeg-target (build-path here "ffmpeg-aarch64-macosx"))
(define openh264-target (build-path here "openh264-aarch64-macosx"))
(define fribidi-target (build-path here "fribidi-aarch64-macosx"))
(define libvid-target (build-path here "libvid-aarch64-macosx"))

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
  (building-lib "lame")
  (build-lame 'macosx)
  (building-lib "frei0r")
  (build-frei0r)
  (building-lib "ffmpeg")
  (build-ffmpeg ffmpeg-target 'macosx)
  (building-lib "libvid")
  (build-libvid libvid-target "libvid.0.dylib" 'macosx 64))

(void
 (system* install-name-tool "-id"
          (format "@loader_path/~a" (openh264))
          (build-path here "openh264-src" "lib" (openh264))))

(copy-file (build-path here "openh264-src" "lib" (openh264))
           (build-path openh264-target (openh264))
           #t)
|#