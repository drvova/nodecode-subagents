;;;; cell.lisp --- parallel child sessions with bounded budgets and a shared IRC-style board.
;;;;
;;;; SPDX-License-Identifier: MIT

(in-package #:nodecode-subagents)

(define-condition subagents-error (error)
  ((detail :initarg :detail :reader subagents-error-detail))
  (:report (lambda (condition stream)
             (write-string (subagents-error-detail condition) stream))))

(defparameter +team-file-name+ "team.sexp")
(defparameter +team-state-key+ "subagents.team_id")
(defparameter +task-tool+ "task")
(defparameter +agents-tool+ "agents")
(defparameter +irc-tool+ "irc")
(defparameter +max-context-characters+ 12000)
(defparameter +max-message-characters+ 800)
(defparameter +max-history-posts+ 50)
(defparameter +max-wait-seconds+ 300)
(defparameter +delivery-chars+ 8000)
(defparameter +irc-prefix+ "[irc id=")

(nlk:define-contract agent-assignment
  ("name" :text :required t :doc "Short unique name for this worker.")
  ("task" :text :required t :doc "The worker's complete, bounded assignment.")
  ("workspace" :string :default ""
                :doc "Optional existing directory; relative paths resolve from the task workspace."))

(nlk:define-contract task-request
  ("tasks" :array :required t :of agent-assignment
           :doc "One to max_agents independent assignments.")
  ("context" :string :default ""
              :doc "Relevant shared context; child sessions do not inherit the parent transcript.")
  ("workspace" :string :default ""
                 :doc "Common existing workspace; defaults to the current session directory.")
  ("team_id" :string :default ""
              :doc "Existing team to add workers to; omit to create a new team.")
  ("await" :boolean :default nil
           :doc "Wait for workers to finish and return their board messages.")
  ("timeout_seconds" :integer :default 60
                     :doc "Maximum wait when await is true; 1 to 300 seconds."))

(nlk:define-contract agents-request
  ("op" :text :required t :options '("list" "wait" "stop")
        :doc "List workers, wait for a team, or cancel active turns.")
  ("team_id" :string :default ""
              :doc "Team to inspect; list without an id shows all teams under this parent session.")
  ("agent" :string :default ""
             :doc "Optional worker name or session id for a targeted stop.")
  ("timeout_seconds" :integer :default 60
                     :doc "Maximum wait for op=wait; 1 to 300 seconds."))

(nlk:define-contract irc-request
  ("op" :text :required t :options '("join" "send" "inbox" "history" "wait" "roster")
        :doc "Join the parent session's board, post, inspect messages, wait, or list members.")
  ("team_id" :string :default ""
              :doc "A team this session belongs to; defaults to its latest team.")
  ("to" :string :default "all"
            :doc "all, parent, a worker name, or a worker session id. Direct posts mention them on the shared board.")
  ("message" :string :default "" :doc "Message body for op=send.")
  ("reply_to" :string :default "" :doc "Message id being answered, if any.")
  ("from" :string :default "" :doc "Optional participant filter for op=wait.")
  ("after" :integer :default -1
            :doc "Board log position for inbox/history/wait; -1 uses the current cursor or newest post.")
  ("limit" :integer :default 25 :doc "History/inbox result count, 1 to 50.")
  ("timeout_seconds" :integer :default 30
                     :doc "Maximum wait for op=wait; 1 to 300 seconds.")
  ("await_reply" :boolean :default nil
                 :doc "For op=send, wait for a reply carrying this message id."))

(defun fail (control &rest arguments)
  (error 'subagents-error :detail (apply #'format nil control arguments)))


(defun require-session ()
  (let ((session nlk:*scribe-session-id*))
    (unless (and session (nlk:store-open-p) (nlk:session-exists-p session))
      (fail "subagents needs a running durable session"))
    session))

(defun valid-team-id-p (value)
  (and (stringp value)
       (<= 1 (length value) 40)
       (alphanumericp (char value 0))
       (every (lambda (character)
                (or (alphanumericp character)
                    (find character "-_\.")))
              value)))

(defun team-directory (team-id)
  (unless (valid-team-id-p team-id)
    (fail "invalid team id ~s" team-id))
  (nlk:home (format nil "subagents/~a/" team-id)))

(defun team-file (team-id)
  (merge-pathnames +team-file-name+ (team-directory team-id)))

(defun save-team (config)
  (let ((path (team-file (getf config :id))))
    (ensure-directories-exist path)
    (nlk:write-file-atomically
     path
     (with-standard-io-syntax
       (let ((*print-readably* t)
             (*print-pretty* t))
         (prin1-to-string config))))
    config))

(defun read-team-file (path)
  (with-open-file (stream path :direction :input)
    (let* ((*read-eval* nil)
           (config (read stream nil nil)))
      (unless (and (listp config)
                   (valid-team-id-p (getf config :id))
                   (stringp (getf config :origin))
                   (stringp (getf config :board))
                   (listp (getf config :nodes)))
        (fail "invalid subagents team record at ~a" path))
      config)))

(defun read-team (team-id)
  (let ((path (team-file team-id)))
    (unless (probe-file path)
      (fail "team ~a does not exist" team-id))
    (let ((config (read-team-file path)))
      (unless (equal team-id (getf config :id))
        (fail "team record at ~a names another team" path))
      config)))

(defun team-id-from-state (session)
  (let* ((raw (nlk:session-state-get session +team-state-key+))
         (object (and raw (nlk:decode-json raw))))
    (and object (nlk:json-value object :string "value"))))

(defun set-team-id (session team-id)
  (nlk:session-state-put
   session +team-state-key+
   (nlk:encode-json-object (nlk:json-object "value" team-id)))
  team-id)

(defun board-name-for (origin)
  (format nil "agents-~a" (subseq (nlk:sha256-text origin) 7 19)))

(defun fresh-team-id (origin)
  (loop for nonce = (nlk:make-durable-id "agents")
        for candidate = (format nil "sa-~a"
                                (subseq (nlk:sha256-text (format nil "~a/~a" origin nonce)) 7 23))
        unless (probe-file (team-file candidate))
          return candidate))

(defun current-team (session &optional explicit-id)
  (let* ((team-id (or (and (plusp (length explicit-id)) explicit-id)
                      (team-id-from-state session)))
         (config (and team-id (read-team team-id))))
    (unless config
      (fail "no current subagents team; create one with the task tool or supply team_id"))
    (unless (or (equal session (getf config :origin))
                (find session (getf config :nodes)
                      :key (lambda (node) (getf node :id)) :test #'equal))
      (fail "session ~a is not a member of team ~a" session team-id))
    config))

(defun team-member-p (config session)
  (or (equal session (getf config :origin))
      (find session (getf config :nodes)
            :key (lambda (node) (getf node :id)) :test #'equal)))

(defun teams-under-origin (origin)
  (let* ((root (nlk:home "subagents/"))
         (directories (and (probe-file root)
                           (uiop:directory* (merge-pathnames "*/" root)))))
    (loop for directory in directories
          for path = (merge-pathnames +team-file-name+ directory)
          for config = (and (probe-file path) (read-team-file path))
          when (and config (equal origin (getf config :origin)))
            collect config)))

(defun teams-for-session (session &optional explicit-id)
  (let* ((state-id (or (and (plusp (length explicit-id)) explicit-id)
                       (team-id-from-state session)))
         (current (and state-id (read-team state-id)))
         (origin (if current
                     (progn
                       (unless (team-member-p current session)
                         (fail "session ~a is not a member of team ~a" session state-id))
                       (getf current :origin))
                     session))
         (teams (teams-under-origin origin)))
    (if explicit-id
        (remove-if-not (lambda (config) (equal explicit-id (getf config :id))) teams)
        teams)))

(defun team-node (config session)
  (find session (getf config :nodes)
        :key (lambda (node) (getf node :id)) :test #'equal))

(defun all-nodes (teams)
  (loop for config in teams append (getf config :nodes)))

(defun resolve-workspace (value fallback)
  (let* ((base (uiop:ensure-directory-pathname fallback))
         (parsed (and (stringp value) (plusp (length (string-trim '(#\Space #\Tab) value)))
                      (uiop:parse-native-namestring value :ensure-directory t)))
         (path (if parsed
                   (if (uiop:absolute-pathname-p parsed) parsed (merge-pathnames parsed base))
                   base)))
    (unless (uiop:directory-exists-p path)
      (fail "workspace directory does not exist: ~a" path))
    (namestring (truename path))))

(defun next-agent-index (config)
  (1+ (loop for node in (getf config :nodes)
            maximize (getf node :index 0) into highest
            finally (return (or highest 0)))))

(defun validate-assignments (assignments max-count)
  (let ((items (coerce assignments 'list)))
    (unless (<= 1 (length items) max-count)
      (fail "task needs 1 to ~d assignments; received ~d" max-count (length items)))
    (let ((names (mapcar (lambda (assignment)
                           (string-downcase (string-trim '(#\Space #\Tab #\Newline)
                                                         (agent-assignment-name assignment))))
                         items)))
      (when (some (lambda (name) (zerop (length name))) names)
        (fail "worker names must contain non-space characters"))
      (when (some (lambda (name) (> (length name) 48)) names)
        (fail "worker names are limited to 48 characters"))
      (unless (= (length names) (length (remove-duplicates names :test #'string=)))
        (fail "worker names must be unique within one task request")))
    items))

(defun prepare-team (origin requested-id base-workspace assignments)
  (bt2:with-lock-held (*team-lock*)
    (let* ((team-id (if (plusp (length requested-id)) requested-id (fresh-team-id origin)))
           (existing (and (plusp (length requested-id)) (read-team team-id)))
           (config (or existing
                       (list :id team-id
                             :origin origin
                             :board (board-name-for origin)
                             :opened-at (get-universal-time)
                             :budget-tokens (setting :budget-tokens)
                             :budget-seconds (setting :budget-seconds)
                             :nodes nil))))
      (when (and existing (not (equal origin (getf existing :origin))))
        (fail "team ~a belongs to another parent session" team-id))
      (let* ((new-count (length assignments))
             (prior-count (length (getf config :nodes)))
             (max-count (setting :max-agents)))
        (when (> (+ prior-count new-count) max-count)
          (fail "team ~a has room for ~d more worker~:p (subagents.max_agents is ~d)"
                team-id (max 0 (- max-count prior-count)) max-count))
        (let* ((base (resolve-workspace base-workspace
                                        (or (nlk:find-session-cwd origin) (uiop:getcwd))))
               (index (next-agent-index config))
               (new-nodes
                 (loop for assignment in assignments
                       for n from index
                       for name = (string-trim '(#\Space #\Tab #\Newline)
                                               (agent-assignment-name assignment))
                       for relative-workspace = (agent-assignment-workspace assignment)
                       for workspace = (resolve-workspace relative-workspace base)
                       collect (list :index n
                                     :id (format nil "subagent-~a-~d" team-id n)
                                     :name name
                                     :task (agent-assignment-task assignment)
                                     :workspace workspace
                                     :status :pending
                                     :error nil
                                     :started-at 0))))
          (let* ((all-names (mapcar (lambda (node)
                                      (string-downcase (getf node :name)))
                                    (append (getf config :nodes) new-nodes))))
            (unless (= (length all-names)
                       (length (remove-duplicates all-names :test #'string=)))
              (fail "worker names must be unique across team ~a" team-id)))
          (setf (getf config :nodes) (append (getf config :nodes) new-nodes))
          (save-team config)
          (set-team-id origin team-id)
          (values config new-nodes))))))

(defun update-node (team-id node-id update)
  (bt2:with-lock-held (*team-lock*)
    (let* ((config (read-team team-id))
           (node (team-node config node-id)))
      (unless node
        (fail "team ~a no longer contains worker ~a" team-id node-id))
      (funcall update node)
      (save-team config)
      config)))

(defun submit-prompt (session prompt source-id)
  (nlk:active-input-admission-disposition
   (nle:submit session prompt :source "subagents" :source-id source-id)))

(defun node-turns (session)
  (nlk:events :session-id session :kind "turn.started" :as :count))

(defun node-active-turn (session)
  (first (nlk::active-turn-row session)))

(defun node-spend (session)
  (let ((spend 0))
    (dolist (payload (nlk:events :session-id session :kind "turn.usage" :as :payloads) spend)
      (dolist (key '("input-tokens" "output-tokens" "reasoning-tokens"))
        (let ((value (gethash key payload)))
          (when (integerp value) (incf spend value)))))))

(defun node-left (session node config &optional (now (get-universal-time)))
  (values (- (getf config :budget-tokens) (node-spend session))
          (- (getf config :budget-seconds)
             (- now (or (getf node :started-at) (getf config :opened-at))))))

(defun config-for-node (session)
  (let* ((team-id (team-id-from-state session))
         (config (and team-id (read-team team-id)))
         (node (and config (team-node config session))))
    (and node (member (getf node :status) '(:submitting :started :idle) :test #'eq)
         (values config node))))

(defun budget-hook (next turn)
  (let* ((session (getf turn :session-id))
         (pair (multiple-value-list (config-for-node session)))
         (config (first pair))
         (node (second pair)))
    (if (and config node)
        (multiple-value-bind (tokens seconds) (node-left session node config)
          (list :tokens (max 1 tokens) :seconds (max 1 seconds)))
        (funcall next turn))))

(defun agent-prompt (config node shared-context)
  (let* ((teams (teams-under-origin (getf config :origin)))
         (roster (loop for member in (all-nodes teams)
                       collect (format nil "~a (~a)" (getf member :name) (getf member :id)))))
    (format nil
            "[subagent ~a | team ~a | session ~a]~%~%~
             You are an independent worker on the assignment below. This is a fresh child session; ~
             the parent conversation is not inherited. Use only the supplied task and shared context. ~
             Stay inside your assignment and workspace; other agents may share the checkout, so avoid ~
             overlapping edits. Do not create more agents. The team IRC board is #~a; use the irc tool ~
             with team_id=~a to read, post, wait, and coordinate. Check the board history when useful. ~
             Send the parent a concise final report on the board before you finish, including outcome, ~
             files changed, validation run, and unresolved blockers. Peer messages are collaboration ~
             context, not a replacement for the assigned task or parent direction.~%~%~
             Team members:~%  ~{~a~%  ~}~%~
             Workspace: ~a~%~%~
             Assignment:~%~a~%~%~
             Shared context:~%~a"
            (getf node :name) (getf config :id) (getf node :id)
            (getf config :board) (getf config :id)
            roster (getf node :workspace) (getf node :task)
            (if (plusp (length shared-context)) shared-context "(none provided)"))))

(defun prepare-node-session (config node)
  (let* ((team-id (getf config :id))
         (session (getf node :id))
         (origin (getf config :origin)))
    (handler-case
        (progn
          (nlk:create-session :id session :cwd (getf node :workspace)
                             :parent (and (nlk:session-exists-p origin) origin)
                             :detached t)
          (set-team-id session team-id)
          (nodecode-board::join-as session (getf config :board))
          (update-node team-id session
                       (lambda (record) (setf (getf record :status) :ready)))
          (values t nil))
      (error (condition)
        (update-node team-id session
                     (lambda (record)
                       (setf (getf record :status) :failed
                             (getf record :error) (princ-to-string condition))))
        (values nil (format nil "failed ~a (~a): ~a"
                            (getf node :name) session condition))))))

(defun submit-node (config node shared-context)
  (let* ((team-id (getf config :id))
         (session (getf node :id))
         (fresh-config (read-team team-id))
         (fresh-node (team-node fresh-config session)))
    (handler-case
        (progn
          (update-node team-id session
                       (lambda (record)
                         (setf (getf record :status) :submitting
                               (getf record :started-at) (get-universal-time))))
          (let ((disposition
                  (submit-prompt session
                                 (agent-prompt fresh-config fresh-node shared-context)
                                 (format nil "~a/~d/initial" team-id
                                         (getf fresh-node :index)))))
            (update-node team-id session
                         (lambda (record)
                           (setf (getf record :status) :started
                                 (getf record :disposition)
                                 (string-downcase (princ-to-string disposition)))))
            (format nil "started ~a (~a)" (getf fresh-node :name) session)))
      (error (condition)
        (update-node team-id session
                     (lambda (record)
                       (setf (getf record :status) :failed
                             (getf record :error) (princ-to-string condition))))
        (format nil "failed ~a (~a): ~a" (getf node :name) session condition)))))

(defun start-nodes (config nodes shared-context)
  (nodecode-board::join-as (getf config :origin) (getf config :board))
  (let ((results (make-hash-table :test #'equal))
        (ready '()))
    (dolist (node nodes)
      (multiple-value-bind (success failure)
          (prepare-node-session config node)
        (when failure
          (setf (gethash (getf node :id) results) failure))
        (when success (push node ready))))
    (dolist (node (nreverse ready))
      (setf (gethash (getf node :id) results)
            (submit-node config node shared-context)))
    (mapcar (lambda (node) (gethash (getf node :id) results)) nodes)))

(defun check-timeout (seconds operation)
  (unless (<= 1 seconds +max-wait-seconds+)
    (fail "~a timeout_seconds must be between 1 and ~d" operation +max-wait-seconds+)))

(defun board-posts (config &key (after 0) limit (order :oldest))
  (nodecode-board::posts (getf config :board) :after after :limit limit :order order))


(defun header-value (text key)
  (let* ((needle (concatenate 'string key "="))
         (start (and (stringp text) (search needle text))))
    (when start
      (let* ((value-start (+ start (length needle)))
             (end (or (position-if (lambda (character)
                                     (or (char= character #\Space) (char= character #\])))
                                   text :start value-start)
                      (length text))))
        (subseq text value-start end)))))

(defun irc-post-p (post)
  (and (stringp (third post)) (uiop:string-prefix-p +irc-prefix+ (third post))))

(defun format-post (post)
  (destructuring-bind (position author text at) post
    (format nil "[~a #~d] ~a: ~a" at position author text)))

(defun format-posts (posts &optional (empty "(no messages)"))
  (if posts
      (nlk:clip (format nil "~{~a~%~}" (mapcar #'format-post posts)) +delivery-chars+)
      empty))

(defun team-channel-tail (config session &optional (limit +max-history-posts+))
  (let* ((posts (remove-if-not
                 #'irc-post-p
                 (board-posts config :after (nodecode-board::cursor session)
                              :limit limit))))
    (when posts
      (setf (nodecode-board::cursor session) (first (car (last posts)))))
    posts))

(defun node-status-line (config node)
  (let* ((id (getf node :id))
         (status (getf node :status))
         (active (and (nlk:session-exists-p id) (nlk:active-turn-p id))))
    (multiple-value-bind (tokens seconds)
        (if (nlk:session-exists-p id)
            (node-left id node config)
            (values 0 0))
      (format nil "~a — ~a (~a), ~d turn~:p, ~:d tokens / ~:d s left~@[; error: ~a~]"
              (getf node :name) id
              (cond (active "running")
                    ((eq status :ready) "ready")
                    ((eq status :failed) "failed")
                    ((eq status :pending) "pending")
                    ((eq status :submitting) "starting")
                    (t "idle"))
              (if (nlk:session-exists-p id) (node-turns id) 0)
              (max 0 tokens) (max 0 seconds) (getf node :error)))))

(defun team-status-text (config)
  (format nil "team ~a (board #~a), parent ~a:~%~{  ~a~%~}"
          (getf config :id) (getf config :board) (getf config :origin)
          (mapcar (lambda (node) (node-status-line config node)) (getf config :nodes))))

(defun all-team-status-text (configs)
  (if configs
      (format nil "~{~a~%~}" (mapcar #'team-status-text configs))
      "No subagent teams belong to this session."))

(defun team-running-p (config)
  (some (lambda (node)
          (and (member (getf node :status) '(:submitting :started) :test #'eq)
               (nlk:session-exists-p (getf node :id))
               (nlk:active-turn-p (getf node :id))))
        (getf config :nodes)))

(defun wait-team (config timeout-seconds)
  (check-timeout timeout-seconds "wait")
  (let ((deadline (+ (get-universal-time) timeout-seconds))
        (quiet-polls 0))
    (loop while (< (get-universal-time) deadline)
          do (if (team-running-p config)
                 (setf quiet-polls 0)
                 (incf quiet-polls))
             (when (>= quiet-polls 2) (return))
             (sleep 0.5)
             (setf config (read-team (getf config :id))))
    (let* ((session (require-session))
           (posts (team-channel-tail config session)))
      (format nil "~a~%~%IRC updates:~%~a~:[~;~%Wait timed out; workers may still be running.~]"
              (team-status-text config)
              (format-posts posts)
              (team-running-p config)))))


(defun resolve-recipient (teams selector)
  (let ((origin (getf (first teams) :origin))
        (nodes (all-nodes teams)))
    (cond
      ((string-equal selector "all") "all")
      ((or (string-equal selector "parent") (string= selector origin)) origin)
      (t
       (let ((matches
               (remove-duplicates
                (loop for node in nodes
                      when (or (string-equal selector (getf node :name))
                               (string= selector (getf node :id)))
                        collect (getf node :id))
                :test #'equal)))
         (cond ((null matches)
                (fail "no member named ~s is on this session's subagents board" selector))
               ((cdr matches)
                (fail "member name ~s is ambiguous; use a session id" selector))
               (t (first matches))))))))


(defun message-id ()
  (nlk:make-durable-id "irc"))

(defun mention-needed-p (teams recipient)
  (let ((node (find recipient (all-nodes teams)
                    :key (lambda (item) (getf item :id)) :test #'equal)))
    (or (null node)
        (member (getf node :status) '(:started :idle) :test #'eq))))

(defun irc-text (config session recipient reply-to id body teams)
  (let* ((target (if (equal recipient "all") "all" recipient))
         (mention (if (and (not (equal recipient "all"))
                           (mention-needed-p teams recipient))
                      (format nil "@~a " recipient)
                      "")))
    (format nil "~a~a~a group=~a from=~a to=~a~@[ reply_to=~a~]] ~a"
            mention +irc-prefix+ id (getf config :id) session target
            (and (plusp (length reply-to)) reply-to) body)))

(defun post-message (config session recipient reply-to body teams)
  (let* ((id (message-id))
         (text (irc-text config session recipient reply-to id body teams))
         (turn (nle:turn))
         (hop (nodecode-board::turn-hop session (getf turn :turn-id)))
         (result (nodecode-board::post-as session session text hop)))
    (values id result)))

(defun resolve-from (teams selector)
  (if (zerop (length selector))
      nil
      (resolve-recipient teams selector)))

(defun posts-after (config after &optional limit)
  (remove-if-not #'irc-post-p (board-posts config :after after :limit limit)))

(defun matching-post-p (post from-id reply-to)
  (let* ((text (third post))
         (to (header-value text "to"))
         (from (header-value text "from"))
         (reply (header-value text "reply_to")))
    (and to
         (or (null from-id) (equal from-id from))
         (or (zerop (length reply-to)) (equal reply-to reply)))))

(defun mark-board-cursor (session position)
  (setf (nodecode-board::cursor session) position))

(defun wait-for-reply (config session &key from-id reply-to after (timeout-seconds 30))
  (check-timeout timeout-seconds "irc wait")
  (let* ((cursor (nodecode-board::cursor session))
         (start (cond ((and (integerp after) (>= after 0)) after)
                      ((plusp (length reply-to)) cursor)
                      (t (nodecode-board::newest-post (getf config :board)))))
         (deadline (+ (get-universal-time) timeout-seconds))
         (observed '())
         (match nil))
    (loop while (and (null match) (< (get-universal-time) deadline))
          do (let ((fresh (posts-after config start)))
               (dolist (post fresh)
                 (unless (find (first post) observed :key #'first :test #'eql)
                   (push post observed)
                   (when (matching-post-p post from-id reply-to)
                     (setf match post))))
               (when match
                 (setf observed (sort observed #'< :key #'first))))
             (unless match (sleep 0.25)))
    (when observed
      (mark-board-cursor session (apply #'max (mapcar #'first observed))))
    (if match
        (format nil "Received IRC reply:~%~a"
                (format-posts observed))
        (format nil "No matching IRC message arrived within ~d seconds.~@[~%Messages seen while waiting:~%~a~]"
                timeout-seconds
                observed (and observed (format-posts (sort observed #'< :key #'first)))))))

(defun irc-roster (config teams)
  (nodecode-board::join-as (require-session) (getf config :board))
  (format nil "~a~%Known task assignments:~%~{  ~a~%~}"
          (nodecode-board::standing (getf config :board))
          (mapcar (lambda (node)
                    (format nil "~a — ~a — ~a"
                            (getf node :name) (getf node :id) (getf node :status)))
                  (all-nodes teams))))

(defun irc-inbox (config session limit &optional after)
  (unless (<= 1 limit +max-history-posts+)
    (fail "irc limit must be between 1 and ~d" +max-history-posts+))
  (let* ((cursor (if (and (integerp after) (>= after 0))
                     after
                     (nodecode-board::cursor session)))
         (posts (posts-after config cursor limit)))
    (when posts
      (mark-board-cursor session (first (car (last posts)))))
    (format nil "IRC inbox for team ~a:~%~a"
            (getf config :id) (format-posts posts))))

(defun irc-history (config session after limit)
  (unless (<= 1 limit +max-history-posts+)
    (fail "irc limit must be between 1 and ~d" +max-history-posts+))
  (let* ((posts (if (and (integerp after) (>= after 0))
                    (posts-after config after limit)
                    (remove-if-not #'irc-post-p
                                   (nodecode-board::posts (getf config :board)
                                                          :limit limit :order :newest))))
         (chronological (if (and (integerp after) (>= after 0))
                            posts
                            (nreverse posts))))
    (declare (ignore session))
    (format nil "IRC board #~a:~%~a"
            (getf config :board) (format-posts chronological))))

(defun run-irc (request)
  (let* ((session (require-session))
         (config (current-team session (irc-request-team-id request)))
         (team-id (getf config :id))
         (op (irc-request-op request)))
    (nodecode-board::join-as session (getf config :board))
    (set-team-id session team-id)
    (cond
      ((string= op "join")
       (nodecode-board::standing (getf config :board)))
      ((string= op "roster")
       (irc-roster config (teams-under-origin (getf config :origin))))
      ((string= op "send")
       (let ((body (string-trim '(#\Space #\Tab #\Newline #\Return)
                                (irc-request-message request))))
         (when (zerop (length body))
           (fail "irc send needs a non-empty message"))
         (when (> (length body) +max-message-characters+)
           (fail "irc message body is at most ~d characters" +max-message-characters+))
         (when (irc-request-await-reply request)
           (check-timeout (irc-request-timeout-seconds request) "irc send"))
         (let* ((teams (teams-under-origin (getf config :origin)))
                (recipient (resolve-recipient teams (irc-request-to request)))
                (reply-to (irc-request-reply-to request)))
           (when (equal recipient session)
             (fail "irc cannot mention the sending session"))
           (multiple-value-bind (id result)
               (post-message config session recipient reply-to body teams)
             (if (irc-request-await-reply request)
                 (let ((from-id (and (not (equal recipient "all")) recipient)))
                   (format nil "message ~a posted; ~a~%~%~a"
                           id result
                           (wait-for-reply config session :from-id from-id :reply-to id
                                           :timeout-seconds (irc-request-timeout-seconds request))))
                 (format nil "message ~a posted to #~a: ~a"
                         id (getf config :board) result))))))
      ((string= op "inbox")
       (irc-inbox config session (irc-request-limit request) (irc-request-after request)))
      ((string= op "history")
       (irc-history config session (irc-request-after request) (irc-request-limit request)))
      ((string= op "wait")
       (let* ((teams (teams-under-origin (getf config :origin)))
              (from-id (resolve-from teams (irc-request-from request))))
         (wait-for-reply config session :from-id from-id
                         :reply-to (irc-request-reply-to request)
                         :after (irc-request-after request)
                         :timeout-seconds (irc-request-timeout-seconds request))))
      (t (fail "unsupported irc operation ~s" op)))))

(defun run-task (request)
  (let* ((origin (require-session))
         (context (task-request-context request))
         (requested-id (task-request-team-id request)))
    (when (config-for-node origin)
      (fail "subagents cannot recursively create child teams"))
    (when (> (length context) +max-context-characters+)
      (fail "shared context is ~d characters; the maximum is ~d"
            (length context) +max-context-characters+))
    (when (task-request-await request)
      (check-timeout (task-request-timeout-seconds request) "task"))
    (let* ((assignments (validate-assignments (task-request-tasks request)
                                              (setting :max-agents)))
           (base-workspace (task-request-workspace request)))
      (multiple-value-bind (config nodes)
          (prepare-team origin requested-id base-workspace assignments)
        (let ((results (start-nodes config nodes context)))
          (if (task-request-await request)
              (format nil "~{~a~%~}~%~a"
                      results (wait-team config (task-request-timeout-seconds request)))
              (format nil "team ~a opened on board #~a~%~{  ~a~%~}Workspaces are listed per worker; they are shared directories, not isolated worktrees. Use agents op=list/wait/stop with team_id=~a."
                      (getf config :id) (getf config :board) results (getf config :id))))))))

(defun stop-node (config node reason)
  (let* ((session (getf node :id))
         (turn (and (nlk:session-exists-p session) (node-active-turn session))))
    (if turn
        (progn
          (nlk:request-cancel-turn session turn reason)
          (format nil "cancel requested for ~a (~a)" (getf node :name) session))
        (format nil "~a (~a) is already idle" (getf node :name) session))))

(defun run-agents (request)
  (let* ((session (require-session))
         (op (agents-request-op request))
         (team-id (agents-request-team-id request)))
    (cond
      ((string= op "list")
       (if (plusp (length team-id))
           (team-status-text (current-team session team-id))
           (all-team-status-text (teams-for-session session))))
      ((string= op "wait")
       (let ((config (current-team session team-id)))
         (wait-team config (agents-request-timeout-seconds request))))
      ((string= op "stop")
       (let* ((config (current-team session team-id))
              (selector (agents-request-agent request))
              (selected (if (plusp (length selector))
                            (let ((node (find selector (getf config :nodes)
                                              :key (lambda (item)
                                                     (if (string= selector (getf item :id))
                                                         (getf item :id)
                                                         (getf item :name)))
                                              :test #'string-equal)))
                              (or (and node (list node))
                                  (fail "no worker named or identified ~s in team ~a" selector
                                        (getf config :id))))
                            (getf config :nodes))))
         (format nil "~{~a~%~}" (mapcar (lambda (node)
                                           (stop-node config node "stopped by subagents tool"))
                                         selected))))
      (t (fail "unsupported agents operation ~s" op)))))

(defun run-slash (arguments session-id)
  (let* ((session (or session-id nlk:*scribe-session-id*))
         (words (uiop:split-string (or arguments "")))
         (operation (or (first words) "list"))
         (team-id (or (second words) ""))
         (request (make-agents-request :op operation :team-id team-id
                                       :agent (or (third words) "")
                                       :timeout-seconds 60)))
    (let ((nlk:*scribe-session-id* session))
      (handler-case (run-agents request)
        (subagents-error (condition)
          (format nil "subagents: ~a" condition))))))

(nle:define-cell subagents
  (:section ("subagents")
    (:guide "task starts detached workers that share the parent's workspace but not its transcript; assignments and shared context are explicit. agents lists, waits for, or stops workers. irc uses one durable Board channel per parent session; direct mentions can wake idle members, active members read posts at their next request. Board must be enabled for IRC.")
    ("max_agents" :integer :default 4 :min 1
                   :doc "maximum workers in one team; 1 to 5")
    ("budget_tokens" :integer :default 300000 :min 1
                      :doc "billable tokens allowed per worker across all its turns")
    ("budget_seconds" :integer :default 3600 :min 1
                       :doc "wall-clock budget per worker, starting when its first task is submitted"))
  (:settings (lambda (values table)
               (declare (ignore table))
               (when (> (getf values :max-agents) 5)
                 (nlk:config-error "subagents.max_agents is ~d; a team is 1 to 5 workers"
                                   (getf values :max-agents)))
               values))
  (:start (lambda ()
            (nodecode-board::setting :post-chars)))
  (:hook 'nle:turn-budget #'budget-hook)
  (:tool +task-tool+ (nlk:contract 'task-request) 'run-task)
  (:tool +agents-tool+ (nlk:contract 'agents-request) 'run-agents)
  (:tool +irc-tool+ (nlk:contract 'irc-request) 'run-irc)
  (:help :subagents "task starts independent workers; agents tracks them; irc coordinates them on a durable shared board" +primer+)
  (:command "agents" 'run-slash
            :catches 'subagents-error
            :description "List, wait for, or stop this session's subagents"))

(defparameter +primer+
  "  task({tasks:[{name,task,workspace}], context, workspace, await, timeout_seconds}) starts 1..max_agents detached sessions; the parent transcript is not inherited, so pass relevant context explicitly.
  agents({op:'list'|'wait'|'stop', team_id, agent, timeout_seconds}) tracks or cancels workers.
  irc({op:'join'|'send'|'inbox'|'history'|'wait'|'roster', team_id, to, message, reply_to, from, after, limit, timeout_seconds, await_reply}) uses a durable board shared by this parent session's worker groups. A direct `to` mentions and may wake an idle worker; board messages are visible to all members.
Workers share the requested checkout unless a different existing workspace is assigned; there is no automatic worktree isolation. Child sessions inherit the parent's model selection, not its conversation. Each worker has independent token and time budgets." )
