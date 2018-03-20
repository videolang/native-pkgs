#!/usr/bin/env racket
#lang racket

;; This is a script to compile the native packages for 32-bit windows

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline)

(define-runtime-path here ".")

(define gcc (find-executable-path "i686-w64-mingw32-gcc"))

(define libvid-target (build-path here "libvid-i386-win32"))

(parameterize ([current-directory (build-path here "libvid-src")])
  (system* gcc "-Wall" "-Werror"
           "-shared"
           "-o" (build-path libvid-target "libvid-0.dll")
           "-I../ffmpeg-src/include"
           "-L../ffmpeg-i386-win32/"
           "-lavutil-55"
           "libvid.c"))
