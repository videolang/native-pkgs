#lang racket

(provide (all-defined-out))

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline)

(define-runtime-path here ".")

;; Executables for compilation
(define gcc (make-parameter (find-executable-path "gcc")))
(define git (find-executable-path "git"))
(define make (find-executable-path "make"))
(define otool (find-executable-path "otool"))
(define install-name-tool (find-executable-path "install_name_tool"))

;; Core count.
(define cores (make-parameter 4))

;; Parameters for target binaries
(define fribidi (make-parameter #f))
(define openh264 (make-parameter #f))
(define avutil (make-parameter #f))
(define swresample (make-parameter #f))
(define swscale (make-parameter #f))
(define avcodec (make-parameter #f))
(define avformat (make-parameter #f))
(define avfilter (make-parameter #f))
(define avdevice (make-parameter #f))
(define libvid (make-parameter #f))

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
    (system* make (format "-j~a" (cores)))
    (system* make (format "-j~a" (cores)))
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
    (system* make (format "-j~a" (cores)))
    (system* make "install")))

(define (build-lame os)
  (parameterize ([current-directory (build-path here "lame-src")])
    (system* git "clean" "-fxd")
    (system* git "checkout" ".")
    (when (eq? os 'macosx)
      (define file-to-patch "include/libmp3lame.sym")
      (define patch-string "lame_init_old")
      (define lines (file->lines file-to-patch))
      (with-output-to-file file-to-patch
        #:exists 'replace
        (λ ()
          (for ([i (in-list lines)]
                #:unless (equal? i patch-string))
            (displayln i)))))
    (system* (simple-form-path "configure")
             "--disable-dependency-tracking"
             "--disable-debug"
             "--enable-nasm"
             (format "--prefix=~a" (current-directory)))
    (system* make (format "-j~a" (cores)))
    (system* make "install")))

(define (build-ffmpeg ffmpeg-target os)
  (parameterize ([current-directory (build-path here "ffmpeg-src")])
    (system* git "clean" "-fxd")
    (system* (simple-form-path "configure")
             "--enable-shared"
             ;"--enable-debug=3" ;; <-- Optional, for debugging
             ;"--disable-pthreads" ;; <-- Only uncomment for testing
             "--disable-sdl2"
             "--disable-indev=jack"
             "--enable-libmp3lame"
             "--enable-libopenh264"
             (format "--prefix=~a" (current-directory)))
    ;"--libdir='@loader_path'")
    (system* make (format "-j~a" (cores)))
    (system* make "install"))
  (when (eq? os 'macosx)
    (define ffmpeg-def-table
      (hash (avutil) (set)
            (swresample) (set (avutil))
            (swscale) (set (avutil))
            (avcodec) (set (avutil) (swresample))
            (avformat) (set (avutil) (avcodec) (swresample))
            (avfilter) (set (avutil) (avformat) (avcodec) (swscale) (swresample))
            (avdevice) (set (avutil) (avformat) (avcodec) (avfilter) (swscale) (swresample))))
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

(define (build-libvid target-dir target-name os word-size)
  (define abs-target-dir (if (absolute-path? target-dir)
                             (build-path target-dir)
                             (build-path here target-dir)))
  (parameterize ([current-directory (build-path here "libvid-src")])
    (define args
      `(,(gcc) "-Wall" "-Werror"
             "-shared"
             ,@(case os
                 [(unix) (list "-fPIC" (case word-size
                                         [(32) "-m32"]
                                         [(64) "-m64"]))]
                 [(macosx) (list "-undefined" "dynamic_lookup"
                                 "-L../ffmpeg-src/lib/" "-lavutil")]
                 [(windows) (case word-size
                              [(32) (list "-L../ffmpeg-i386-win32/" "-lavutil-56")]
                              [(64) (list "-L../ffmpeg-x86_64-win32/" "-lavutil-56")])])
             "-o" ,(build-path abs-target-dir target-name)
             "-I../ffmpeg-src/include"
             "libvid.c"))
    (apply system* args))
  (when (eq? os 'macosx)
    (parameterize ([current-directory abs-target-dir])
      (system* install-name-tool
               "-change" 
               (format "~a/~a/~a"
                       (path->string (simplify-path (build-path here "ffmpeg-src/")))
                       "lib"
                       (avutil))
               (format "@loader_path/~a" (avutil))
               (libvid)))))
