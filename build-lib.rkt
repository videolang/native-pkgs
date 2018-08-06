#lang racket

(provide (all-defined-out))

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline)

(define-runtime-path here ".")

(define gcc (find-executable-path "gcc"))
(define git (find-executable-path "git"))
(define make (find-executable-path "make"))
(define otool (find-executable-path "otool"))
(define install-name-tool (find-executable-path "install_name_tool"))

(define cores 4)

;; Currently unused
(define (build-fribidi fribidi-target fribidi)
  (parameterize ([current-directory (build-path here "fribidi-src")])
    (system* git "clean" "-fxd")
    (system* git "checkout" ".")
    (system* (simple-form-path "bootstrap"))
    (system* (simple-form-path "configure")
             (format "--prefix=~a" (current-directory))
             "--enable-shared")
    ;; Run make twice, first time failes
    (system* make (format "-j~a" cores))
    (system* make (format "-j~a" cores))
    ;; make install fails, but the needed file is still generated.
    (system* make "install"))
  (copy-file (build-path here "fribidi-src" "lib" fribidi)
           (build-path fribidi-target fribidi)
           #t))

(define (build-frei0r)
  (parameterize ([current-directory (build-path here "frei0r-src")])
    (system* git "clean" "-fxd")
    (system* (simple-form-path "autogen.sh"))
    (system* (simple-form-path "configure") (format "--prefix=~a" (current-directory)))
    (system* make (format "-j~a" cores))
    (system* make "install")))

(define (build-ffmpeg ffmpeg-target os)
  (parameterize ([current-directory (build-path here "ffmpeg-src")])
    (system* git "clean" "-fxd")
    (system* (simple-form-path "configure")
             "--enable-shared"
             ;"--disable-pthreads" ;; <-- Only uncomment for testing
             "--disable-sdl2"
             "--disable-indev=jack"
             "--enable-libopenh264"
             (format "--prefix=~a" (current-directory)))
    ;"--libdir='@loader_path'")
    (system* make (format "-j~a" cores))
    (system* make "install"))
  (when (eq? os 'macosx)
    (define fribidi "libfribidi.0.dylib")
    (define openh264 "libopenh264.4.dylib")
    (define avutil "libavutil.56.dylib")
    (define swresample "libswresample.3.dylib")
    (define swscale "libswscale.5.dylib")
    (define avcodec "libavcodec.58.dylib")
    (define avformat "libavformat.58.dylib")
    (define avfilter "libavfilter.7.dylib")
    (define ffmpeg-def-table
      (hash avutil (set)
            swresample (set avutil)
            swscale (set avutil)
            avcodec (set avutil swresample)
            avformat (set avutil avcodec swresample)
            avfilter (set avutil avformat avcodec swscale swresample)))
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
                 lib)))
    (for ([(lib target-set) (in-dict ffmpeg-def-table)])
      (copy-file (build-path here "ffmpeg-src" "lib" lib)
                 (build-path ffmpeg-target lib)
                 #t))))

(define (build-libvid target-dir target-name os word-size
                      #:gcc [local-gcc #f])
  (parameterize ([current-directory (build-path here "libvid-src")])
    (define args
      `(,(or local-gcc gcc) "-Wall" "-Werror"
             "-shared"
             ,@(case os
                 [(unix) (list "-fPIC" (case word-size
                                         [(32) "-m32"]
                                         [(64) "-m64"]))]
                 [(macosx) (list "-undefined" "dynamic_lookup"
                                 "-L../ffmpeg-src/lib/" "-lavutil")]
                 [(windows) (case word-size
                              [(32) "-L../ffmpeg-i386-win32/" "-lavutil-55"]
                              [(64) "-L../ffmpeg-x86_64-win32/" "-labutil-55"])])
             "-o" ,(if (absolute-path? target-dir)
                       (build-path target-dir target-name)
                       (build-path here target-dir target-name))
             "-I../ffmpeg-src/include"
             "libvid.c"))
    (apply system* args)))
