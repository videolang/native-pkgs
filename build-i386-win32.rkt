#!/usr/bin/env racket
#lang racket

;; This is a script to compile the native packages for 32-bit windows

(require compiler/find-exe
         racket/runtime-path
         racket/cmdline
         "build-lib.rkt")

(define-runtime-path here ".")

(define gcc (find-executable-path "i686-w64-mingw32-gcc"))

(define libvid-target (build-path here "libvid-i386-win32"))

(build-libvid libvid-target "libvid-0.dll" 'windows 64 #:gcc gcc)
