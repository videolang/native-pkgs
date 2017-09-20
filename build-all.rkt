#!/usr/bin/env racket
#lang racket

;; Convience script to build all of the native packages for all of the major OSes.
;;   (Note that macOS must be built from an macOS machine.)

(require compiler/find-exe
         racket/runtime-path)

(define-runtime-path here ".")

(define scripts
  (list "build-x86_64-macosx.rkt"
        "build-x86_64-win32.rkt"
        "build-i386-win32.rkt"
        "build-x86_64-linux.rkt"
        "build-i386-linux.rkt"))
(for ([s (in-list scripts)])
  (displayln "=============================================================")
  (displayln "=============================================================")
  (printf "Building ~a~n" s)
  (displayln "=============================================================")
  (displayln "=============================================================")
  (system* (find-exe) (build-path here s)))
