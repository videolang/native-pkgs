#!/usr/bin/env racket
#lang racket

;; This is a script to compile the native packages for 32-bit windows

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline)

(define-runtime-path here ".")

(define gcc (find-executable-path "gcc"))
(define make (find-executable-path "make"))

(define libvid-target (build-path here "libvid-i386-linux"))

(define cores 4)

;; Need to compile ffmpeg, but only for libvid's include path.
(parameterize ([current-directory (build-path here "ffmpeg-src")])
  (system* (simple-form-path "configure")
           (format "--prefix=~a" (current-directory)))
  (system* make (format "-j~a" cores))
  (system* make "install"))

(parameterize ([current-directory (build-path here "libvid-src")])
  (system* gcc "-m32" "-Wall" "-Werror"
           "-shared"
           "-o" (build-path libvid-target "libvid.so.0")
           "-I../ffmpeg-src/include"
           "-fPIC"
           "libvid.c"))
