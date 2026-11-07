;;;; package.lisp --- the SUBAGENTS package and its public vocabulary.
;;;;
;;;; SPDX-License-Identifier: MIT

(defpackage #:nodecode-subagents
  (:use #:cl)
  (:nicknames #:subagents)
  (:export #:task #:agents #:irc #:start-cell #:subagents-error))

(in-package #:nodecode-subagents)

(nlk:define-peripheral subagents :not-running t)
