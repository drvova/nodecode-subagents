;;;; nodecode-subagents.asd --- task-focused child sessions with a shared board.
;;;;
;;;; SPDX-License-Identifier: MIT

(asdf:defsystem "nodecode-subagents"
  :description "Parallel task sessions with lifecycle controls and IRC-style board messaging"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("nodecode" "nodecode-board")
  :serial t
  :components ((:file "package")
               (:file "cell")))
