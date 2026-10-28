;;; session-cockpit-test-helpers.el --- Sessions and a user for the tests -*- lexical-binding: t; -*-

;;; Commentary:
;; A session with a state directory of its own, the agenda Claude would have
;; written for it, the keys the user types, and what reached Claude.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'iso8601)
(require 'session-cockpit)

(defconst session-cockpit-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory of the Emacs tests.")

(defmacro session-cockpit-test-with-session (session &rest body)
  "Run BODY with SESSION bound to a fresh session of its own.
The session's state lives in a temporary directory that is deleted
afterwards, together with the user's unsent changes and any buffer the
cockpit opened."
  (declare (indent 1))
  `(let* ((session-cockpit-state-directory (make-temp-file "session-cockpit-test-" t))
          (session-cockpit-drafts-directory (make-temp-file "session-cockpit-test-drafts-" t))
          (,session (list :id (format "test-session-%s" (random 1000000))
                          :state-directory session-cockpit-state-directory)))
     (unwind-protect
         (save-window-excursion ,@body)
       (session-cockpit-test--kill-buffers)
       (delete-directory (plist-get ,session :state-directory) t)
       (delete-directory session-cockpit-drafts-directory t))))

(defun session-cockpit-test-session-id (session)
  "Return the ID of SESSION."
  (plist-get session :id))

(defun session-cockpit-test-another-session (session)
  "Return a fresh session next to SESSION, with its state in the same place."
  (list :id (format "test-session-%s" (random 1000000))
        :state-directory (plist-get session :state-directory)))

(defun session-cockpit-test-set-project (session project)
  "Record PROJECT as the directory SESSION runs in, as its SessionStart hook would."
  (session-cockpit-test-set-session-info session `((project . ,project))))

(defun session-cockpit-test-set-updated (session time)
  "Make SESSION's agenda look last updated at TIME, \"YYYY-MM-DD HH:MM\" local time."
  (set-file-times (session-cockpit-test--file session "agenda.json")
                  (encode-time (iso8601-parse (concat (string-replace " " "T" time) ":00")))))

(cl-defun session-cockpit-test-ask (session question &optional options
                                             &key multi-select anchors (status "open") new changed)
  "Put QUESTION with OPTIONS on SESSION's agenda, as Claude would.
An option is its label, or a list of its label, description and, optionally,
preview; without options, the question is answered in free text.  Several
options may be picked if MULTI-SELECT.  ANCHORS are the places in SESSION's
project the question points at, each a list of file, first and last line;
their text is read from the project as the MCP server does.  The question
has STATUS, and is marked new if NEW and changed if CHANGED.  Questions are
numbered q1, q2, … in the order they are asked."
  (session-cockpit-test--update-agenda session
    (lambda (questions)
      (append questions
              (list `((id . ,(format "q%d" (1+ (length questions))))
                      (question . ,question)
                      (options . ,(mapcar #'session-cockpit-test--option options))
                      (multiSelect . ,(if multi-select t :false))
                      ,@(when anchors
                          `((anchors . ,(mapcar (lambda (anchor)
                                                  (apply #'session-cockpit-test--anchor session anchor))
                                                anchors))))
                      (status . ,status)
                      ,@(when new '((new . t)))
                      ,@(when changed '((changed . t)))))))))

(defun session-cockpit-test-set-status (session question status)
  "Give QUESTION in SESSION the STATUS, as Claude's side would."
  (session-cockpit-test--change-question session question `(status . ,status)))

(defun session-cockpit-test-set-options (session question options)
  "Give QUESTION in SESSION the OPTIONS, as Claude would, marking it changed.
OPTIONS are as `session-cockpit-test-ask' takes them."
  (session-cockpit-test--change-question
   session question `(options . ,(mapcar #'session-cockpit-test--option options)) '(changed . t)))

(defun session-cockpit-test--change-question (session question &rest entries)
  "Set ENTRIES, each a key and its value, on QUESTION in SESSION's agenda."
  (session-cockpit-test--update-agenda session
    (lambda (questions)
      (mapcar (lambda (entry)
                (if (equal (alist-get 'question entry) question)
                    (append entries
                            (seq-remove (lambda (field) (assq (car field) entries)) entry))
                  entry))
              questions))))

(defun session-cockpit-test--anchor (session file start &optional end)
  "Return the anchor on lines START to END of FILE, as JSON.
FILE is relative to SESSION's project or absolute, and goes into the anchor
absolute.  Its text is read from the file; END defaults to START."
  (let ((end (or end start)))
    `((file . ,(session-cockpit-test--project-file session file)) (start . ,start) (end . ,end)
      (text . ,(string-join (seq-subseq (split-string (session-cockpit-test--file-content session file) "\n")
                                        (1- start) end)
                            "\n")))))

(defun session-cockpit-test-create-project (session files)
  "Create SESSION's project holding FILES, an alist from path to content.
Its SessionStart hook records it, as for a session started in it.  Return
its directory."
  (let ((project (expand-file-name (format "project-%s" (plist-get session :id))
                                   (plist-get session :state-directory))))
    (pcase-dolist (`(,path . ,content) files)
      (let ((file (expand-file-name path project)))
        (make-directory (file-name-directory file) t)
        (with-temp-file file
          (insert content))))
    (session-cockpit-test-set-project session project)
    project))

(defun session-cockpit-test-copy-contract-project (session path)
  "Make a copy of the project in the contract fixture at PATH SESSION's project.
A copy, so a scenario can change its files.  Return its directory."
  (let ((project (expand-file-name (format "project-%s" (plist-get session :id))
                                   (plist-get session :state-directory))))
    (copy-directory (expand-file-name path (expand-file-name "../../contract_fixtures"
                                                             session-cockpit-test--directory))
                    project nil t t)
    (session-cockpit-test-set-project session project)
    project))

(defun session-cockpit-test-change-file (session file content)
  "Make FILE in SESSION's project hold CONTENT, as the user editing it would.
A buffer visiting it gets the new content too."
  (let ((path (session-cockpit-test--project-file session file)))
    (with-temp-file path
      (insert content))
    (when-let* ((buffer (find-buffer-visiting path)))
      (with-current-buffer buffer
        (revert-buffer t t t)))))

(defun session-cockpit-test-user-visits (session file)
  "Visit FILE in SESSION's project, as the user would, and return its buffer.
The current buffer stays as it is."
  (find-file-noselect (session-cockpit-test--project-file session file)))

(defun session-cockpit-test-marks (buffer)
  "Return the marks of open questions in BUFFER, in order.
Each is its first and last line and what hovering over it shows."
  (with-current-buffer buffer
    (mapcar (lambda (overlay)
              (list (line-number-at-pos (overlay-start overlay))
                    (1- (line-number-at-pos (overlay-end overlay)))
                    (overlay-get overlay 'help-echo)))
            (sort (seq-filter (lambda (overlay) (overlay-get overlay 'session-cockpit-mark))
                              (overlays-in (point-min) (point-max)))
                  (lambda (a b) (< (overlay-start a) (overlay-start b)))))))

(defun session-cockpit-test-shown-lines ()
  "Return what another window than the selected one shows: file and line.
The file is its name, and the line the one at that window's point."
  (when-let* ((window (seq-find (lambda (window) (not (eq window (selected-window))))
                                (window-list))))
    (with-current-buffer (window-buffer window)
      (list (file-name-nondirectory (or (buffer-file-name) ""))
            (line-number-at-pos (window-point window))))))

(defun session-cockpit-test--project-file (session file)
  "Return the path of FILE in SESSION's project."
  (expand-file-name file (alist-get 'project (session-cockpit-test--read-json
                                              (session-cockpit-test--file session "session.json")))))

(defun session-cockpit-test--file-content (session file)
  "Return what FILE in SESSION's project holds."
  (with-temp-buffer
    (insert-file-contents (session-cockpit-test--project-file session file))
    (buffer-string)))

(defun session-cockpit-test--option (option)
  "Return OPTION, a label or a list of label, description and preview, as JSON."
  (pcase-let ((`(,label ,description ,preview) (ensure-list option)))
    `((label . ,label)
      ,@(when description `((description . ,description)))
      ,@(when preview `((preview . ,preview))))))

(defun session-cockpit-test-goto-line-with (text)
  "Move point to the start of the line showing TEXT."
  (goto-char (point-min))
  (search-forward text)
  (goto-char (pos-bol)))

(defun session-cockpit-test-line-at-point ()
  "Return the line at point, without whitespace at its end."
  (string-trim-right (buffer-substring-no-properties (pos-bol) (pos-eol))))

(cl-defun session-cockpit-test-user-clicks (label &key on)
  "Click the button reading LABEL on the line showing ON, as the user would.
An option's button reads as its label, without the marker in front.  Point
ends up elsewhere first, since a click does not need it there.  There is no
mouse in the test daemon, so this looks up what a click there runs (a
`mouse-1' on a link is followed as `mouse-2') and fails unless that pushes
the button."
  (let ((position (save-excursion
                    (goto-char (point-min))
                    (search-forward on)
                    (let ((end (pos-eol)))
                      (goto-char (pos-bol))
                      (cl-loop for position from (point) below end
                               for button = (button-at position)
                               when (and button
                                         (equal (replace-regexp-in-string
                                                 "\\`[([][ •x][])] " ""
                                                 (string-trim (button-label button)))
                                                label))
                               return position)))))
    (unless position
      (ert-fail (format "No %s button on the line showing %s" label on)))
    (goto-char (point-min))
    (let ((command (key-binding [mouse-2] nil nil position)))
      (unless (eq command 'push-button)
        (ert-fail (format "Clicking %s runs %s, not push-button" label command))))
    (push-button position t)))

(defun session-cockpit-test-wrap-indentation (text)
  "Return how many columns deep the line showing TEXT continues when wrapped."
  (save-excursion
    (goto-char (point-min))
    (search-forward text)
    (jit-lock-fontify-now (pos-bol) (pos-eol))
    (pcase (get-text-property (pos-bol) 'wrap-prefix)
      (`(space :align-to (,columns . width)) columns)
      ((and (pred stringp) prefix) (string-width prefix)))))

(defun session-cockpit-test-buffer-should-read (&rest lines)
  "Assert that the current buffer shows LINES, up to trailing whitespace.
Only visible text counts, so collapsed sections show just their heading."
  (should (equal (string-trim-right (session-cockpit-test-visible-text))
                 (string-join lines "\n"))))

(defun session-cockpit-test-visible-text ()
  "Return the text of the current buffer the user can see.
Whitespace at the ends of lines and of the text is left out, and the text
ends in a newline, like a text file."
  (let ((text "")
        (position (point-min)))
    (while (< position (point-max))
      (let ((next (next-single-char-property-change position 'invisible)))
        (unless (invisible-p position)
          (setq text (concat text (buffer-substring-no-properties position next))))
        (setq position next)))
    (concat (string-trim-right (replace-regexp-in-string "[ \t]+$" "" text)) "\n")))

(defmacro session-cockpit-test-wait-until (condition)
  "Let Emacs process events until CONDITION holds, failing after 2 seconds."
  `(let ((deadline (+ (float-time) 2)))
     (while (not ,condition)
       (when (> (float-time) deadline)
         (ert-fail (format "Still not true after 2 seconds: %S" ',condition)))
       ;; Reading input, unlike `accept-process-output', also handles file
       ;; notifications, which arrive as input events.
       (sit-for 0.05))))

(defun session-cockpit-test-header-line ()
  "Return the header line of the current buffer as the user sees it.
Whitespace at its ends is left out."
  (string-trim (substring-no-properties (format-mode-line header-line-format))))

(defun session-cockpit-test-user-clicks-in-header-line (label)
  "Click the button reading LABEL in the header line, as the user would.
Afterwards the current buffer is the one the user is looking at."
  (let* ((line (format-mode-line header-line-format))
         (position (or (string-search label line)
                       (ert-fail (format "No %s in the header line" label))))
         (keymap (get-text-property position 'keymap line))
         (command (and keymap (lookup-key keymap [header-line mouse-1]))))
    (unless (commandp command)
      (ert-fail (format "Clicking %s in the header line does nothing" label)))
    (call-interactively command)
    (set-buffer (window-buffer (selected-window)))))

(defun session-cockpit-test-user-submits-with-comment (comment)
  "Submit from the cockpit buffer with COMMENT, as the user would.
The user opens the message buffer, writes COMMENT and sends it."
  (session-cockpit-test-user-types "c")
  (insert comment)
  (session-cockpit-test-user-types "C-c C-c"))

(defun session-cockpit-test-written-comment ()
  "Return what the user wrote in the message buffer, its # lines left out."
  (string-trim (replace-regexp-in-string "^#.*\n?" "" (buffer-string))))

(defun session-cockpit-test-without-comment-line (monitor-output)
  "Return MONITOR-OUTPUT, what Claude read of a submit, without its comment.
The message buffer's preview shows the rest before a comment is written."
  (replace-regexp-in-string "^Comment: .*\n" "" monitor-output))

(defun session-cockpit-test-message-preview ()
  "Return what the message buffer shows Claude will read, as one string.
That is the # lines after \"Claude reads your submit as:\", without the #."
  (save-excursion
    (goto-char (point-min))
    (search-forward "# Claude reads your submit as:\n")
    (replace-regexp-in-string "^# " "" (buffer-substring (point) (point-max)))))

(defun session-cockpit-test-user-types (&rest keys)
  "Type KEYS, in `kbd' notation, as the user would.
Afterwards the current buffer is the one the user is looking at.  Skipped in
batch, where no command loop runs."
  (when noninteractive
    (ert-skip "Typing needs an interactive session"))
  (execute-kbd-macro (kbd (string-join keys " ")))
  (set-buffer (window-buffer (selected-window))))

(defmacro session-cockpit-test-user-will-write (text &rest body)
  "Run BODY with the user writing TEXT into the reply editor and submitting it.
Return what the editor showed: its :reference and the :initial-text it
started out with.  The editor itself needs a graphical frame, so this
stands in for it."
  (declare (indent 1))
  `(let ((shown nil))
     (cl-letf (((symbol-function 'session-cockpit-edit-reply)
                (cl-function
                 (lambda (&key reference initial-text on-submit)
                   (setq shown (list :reference reference :initial-text initial-text))
                   (funcall on-submit ,text)))))
       ,@body)
     shown))

(defun session-cockpit-test-user-restarts-emacs ()
  "Kill every buffer of the session, losing what they hold only in memory."
  (session-cockpit-test--kill-buffers))

(defmacro session-cockpit-test-user-will-pick (n &rest body)
  "Run BODY with the user picking the Nth candidate when asked to choose.
Return the candidates shown, in the order shown."
  (declare (indent 1))
  `(let ((shown nil))
     (cl-letf (((symbol-function 'completing-read)
                (lambda (_prompt collection &rest _)
                  (let* ((metadata (completion-metadata "" collection nil))
                         (sort (or (completion-metadata-get metadata 'display-sort-function)
                                   (lambda (candidates) (sort candidates #'string<)))))
                    (setq shown (funcall sort (all-completions "" collection)))
                    (nth ,n shown)))))
       ,@body)
     shown))

(defmacro session-cockpit-test-user-will-answer (answer &rest body)
  "Run BODY with the user answering a yes-or-no prompt with ANSWER, \"y\" or \"n\".
Return the prompt, or nil if there was none."
  (declare (indent 1))
  `(let ((prompt nil))
     (cl-letf (((symbol-function 'y-or-n-p)
                (lambda (shown)
                  (setq prompt shown)
                  (equal ,answer "y"))))
       ,@body)
     prompt))

(defun session-cockpit-test-user-error-from (&rest keys)
  "Type KEYS as the user would, and return the message they are refused with."
  (condition-case err
      (progn (apply #'session-cockpit-test-user-types keys)
             (ert-fail "Typing was not refused"))
    (user-error (error-message-string err))))

(defun session-cockpit-test-submissions (session)
  "Return the comments submitted to Claude in SESSION, oldest first.
They are what lies in the session's inbox, for Claude to take over."
  (let ((inbox (session-cockpit-test--file session "inbox")))
    (when (file-directory-p inbox)
      (mapcar (lambda (path)
                (alist-get 'comment (session-cockpit-test--read-json path)))
              (directory-files inbox t "\\.json\\'")))))

(defun session-cockpit-test--update-agenda (session function)
  "Replace the questions of SESSION's agenda with what FUNCTION makes of them.
The agenda is written the way the MCP server writes `agenda.json'."
  (declare (indent 1))
  (let* ((path (session-cockpit-test--file session "agenda.json"))
         (questions (when (file-exists-p path)
                      (alist-get 'questions (session-cockpit-test--read-json path)))))
    (session-cockpit-test--write-agenda
     session `((questions . ,(vconcat
                              (mapcar #'session-cockpit-test--json-ready
                                      (funcall function questions))))))))

(defun session-cockpit-test--write-agenda (session agenda)
  "Write AGENDA as SESSION's `agenda.json', as the MCP server does.
That is through a temporary file renamed into place."
  (let* ((path (session-cockpit-test--file session "agenda.json"))
         (temp-path (concat path ".tmp")))
    (make-directory (file-name-directory path) t)
    (with-temp-file temp-path
      (insert (json-serialize agenda)))
    (rename-file temp-path path t)))

(defun session-cockpit-test--json-ready (question)
  "Return QUESTION with its options and anchors as vectors for `json-serialize'."
  (mapcar (lambda (entry)
            (if (memq (car entry) '(options anchors))
                (cons (car entry) (vconcat (cdr entry)))
              entry))
          question))

(defun session-cockpit-test-last-submission (session)
  "Return the newest file in SESSION's inbox, as it lies there for Claude.
It reads as `session-cockpit-test-contract-fixture' reads JSON."
  (let ((inbox (session-cockpit-test--file session "inbox")))
    (when (file-directory-p inbox)
      (session-cockpit-test--read-json-value
       (car (last (directory-files inbox t "\\.json\\'")))))))

(defun session-cockpit-test-set-agenda (session agenda)
  "Make AGENDA the agenda of SESSION, as the MCP server would write it.
AGENDA is JSON as `session-cockpit-test-contract-fixture' reads it."
  (session-cockpit-test--write-agenda session agenda))

(defun session-cockpit-test-set-session-info (session info)
  "Make INFO what SESSION recorded about itself, as its SessionStart hook would.
INFO is JSON as `session-cockpit-test-contract-fixture' reads it."
  (let ((path (session-cockpit-test--file session "session.json")))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert (json-serialize info)))))

(defun session-cockpit-test-contract-fixture (path &optional project)
  "Return the contract fixture at PATH: parsed if it is JSON, as text otherwise.
<project> in it stands for PROJECT, the directory the session runs in.  JSON
objects come as alists with sorted keys and arrays as vectors, so two JSON
values are `equal' when they are the same JSON."
  (with-temp-buffer
    (insert-file-contents (expand-file-name path (expand-file-name "../../contract_fixtures"
                                                                   session-cockpit-test--directory)))
    (when project
      (goto-char (point-min))
      (while (search-forward "<project>" nil t)
        (replace-match project t t)))
    (if (string-suffix-p ".json" path)
        (session-cockpit-test--sorted-keys
         (progn (goto-char (point-min))
                (json-parse-buffer :object-type 'alist :array-type 'array)))
      (buffer-string))))

(defun session-cockpit-test--read-json-value (path)
  "Return the JSON in the file at PATH, with objects' keys sorted.
Objects come as alists and arrays as vectors."
  (session-cockpit-test--sorted-keys
   (with-temp-buffer
     (insert-file-contents path)
     (json-parse-buffer :object-type 'alist :array-type 'array))))

(defun session-cockpit-test--sorted-keys (json)
  "Return JSON with the keys of every object sorted."
  (cond ((vectorp json) (vconcat (mapcar #'session-cockpit-test--sorted-keys json)))
        ((consp json)
         (sort (mapcar (lambda (entry)
                         (cons (car entry) (session-cockpit-test--sorted-keys (cdr entry))))
                       json)
               (lambda (a b) (string< (car a) (car b)))))
        (t json)))

(defun session-cockpit-test--file (session name)
  "Return the path of the file NAME in SESSION's state directory."
  (expand-file-name name (expand-file-name (plist-get session :id)
                                           (plist-get session :state-directory))))

(defun session-cockpit-test--read-json (path)
  "Return the JSON in the file at PATH."
  (with-temp-buffer
    (insert-file-contents path)
    (json-parse-buffer :object-type 'alist :array-type 'list)))

(defun session-cockpit-test--kill-buffers ()
  "Kill every buffer the cockpit opened, and those visiting the sessions' files."
  (dolist (buffer (buffer-list))
    (when (or (string-prefix-p "*session-cockpit" (buffer-name buffer))
              (and (buffer-file-name buffer)
                   (file-in-directory-p (buffer-file-name buffer) session-cockpit-state-directory)))
      (with-current-buffer buffer
        (set-buffer-modified-p nil))
      (kill-buffer buffer))))

(provide 'session-cockpit-test-helpers)
;;; session-cockpit-test-helpers.el ends here
