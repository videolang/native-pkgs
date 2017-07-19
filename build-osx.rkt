#!/usr/bin/env bash
#lang racket

;; This is a script to compile the native packages for OS X.

(require compiler/find-exe)
(define otool (find-executable-path "otool"))
(define install-name-tool (find-executable-path "install_name_tool"))
(define make (find-executable-path "make"))
