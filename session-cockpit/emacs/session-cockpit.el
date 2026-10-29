;;; session-cockpit.el --- A cockpit for a Claude Code session -*- lexical-binding: t; -*-

;;; Commentary:
;; Shows the questions Claude asked in a Claude Code session, shaped like
;; Claude Code's AskUserQuestion, and sends the user's answers back to Claude
;; in one submit.

;;; Code:

(require 'cl-lib)
(require 'filenotify)
(require 'magit-section)

(defgroup session-cockpit nil
  "A cockpit for a Claude Code session."
  :group 'tools)

(defvar session-cockpit-state-directory (expand-file-name "~/.local/state/session-cockpit")
  "Directory holding one directory of state per session.")

(defvar session-cockpit-drafts-directory (locate-user-emacs-file "session-cockpit/drafts")
  "Directory holding the user's unsent answers, one file per session.")

(defvar-local session-cockpit-session-id nil
  "ID of the session the current buffer belongs to.")

(defvar-local session-cockpit--answers nil
  "The user's unsent answers, as an alist from question ID to (SELECTED . TEXT).
SELECTED lists the labels of the picked options, in the options' order;
TEXT is what the user wrote, or nil.")

(defvar-keymap session-cockpit-mode-map
  "1" #'session-cockpit-pick
  "2" #'session-cockpit-pick
  "3" #'session-cockpit-pick
  "4" #'session-cockpit-pick
  "r" #'session-cockpit-write
  "RET" #'session-cockpit-pick-or-write
  "k" #'session-cockpit-delete-text
  "c" #'session-cockpit-write-message)

(define-derived-mode session-cockpit-mode magit-section-mode "Cockpit"
  "Major mode of the cockpit buffer of a session."
  ;; Questions and descriptions are indented prose, so wrap them at words and
  ;; keep the indentation on continuation lines instead of scrolling sideways.
  ;; A question continues behind its ID, an option behind its marker and the
  ;; user's text behind its arrow.
  (setq-local adaptive-fill-regexp
              "[ \t]*\\(\\[[a-z][0-9]+\\] \\|↳ \\|[0-9]\\. [([][ •x][])] \\)?")
  ;; `g' and `revert-buffer' redraw from the session's current agenda.
  (setq-local revert-buffer-function (lambda (&rest _) (session-cockpit--refresh)))
  (visual-line-mode)
  (visual-wrap-prefix-mode))

(defface session-cockpit-id '((t :inherit shadow))
  "Face of question IDs.")

(defface session-cockpit-question '((t :inherit bold))
  "Face of the question itself.")

(defface session-cockpit-option '((t :inherit default))
  "Face of an option's marker and label.")

(defface session-cockpit-option-selected '((t :inherit (bold success)))
  "Face of the marker and label of a picked option.")

(defface session-cockpit-description '((t :inherit shadow))
  "Face of an option's description.")

(defface session-cockpit-preview '((t :inherit (fixed-pitch shadow)))
  "Face of an option's preview.")

(defface session-cockpit-anchor '((t :inherit font-lock-builtin-face))
  "Face of the reference to the lines a question points at.")

(defface session-cockpit-excerpt '((t :inherit fixed-pitch))
  "Face of the text of the lines a question points at.")

(defface session-cockpit-not-found '((t :inherit (italic error)))
  "Face of the badge marking lines whose text is not in their file anymore.")

(defface session-cockpit-button
  '((t :inherit shadow :box (:line-width (1 . -1) :style released-button)))
  "Face of a button.")

(defface session-cockpit-button-hover '((t :underline t))
  "Face of a button or option under the mouse.")

(defface session-cockpit-author '((t :inherit font-lock-constant-face))
  "Face of the author of a text.")

(defface session-cockpit-unsent '((t :inherit secondary-selection :extend t))
  "Face of the user's unsent text, set apart from the question.")

(defface session-cockpit-unsent-badge '((t :inherit (italic warning)))
  "Face of the badge marking the user's unsent text.")

(defface session-cockpit-new
  '((((background dark)) :background "#26303d" :extend t)
    (t :background "#eaf1fb" :extend t))
  "Face of what Claude asked or changed since the user's last submit.")

(defface session-cockpit-new-badge '((t :inherit session-cockpit-unsent-badge))
  "Face of the badge marking what Claude asked or changed since the last submit.")

(defun session-cockpit-show (session-id)
  "Show the cockpit of the session with SESSION-ID.
Interactively, pick the session from those with an agenda, the most
recently updated first."
  (interactive (list (session-cockpit--pick-session)))
  (let ((buffer (get-buffer-create (format "*session-cockpit: %s*" session-id))))
    (with-current-buffer buffer
      (session-cockpit-mode)
      (setq session-cockpit-session-id session-id)
      (session-cockpit--load-unsent-answers)
      (session-cockpit--watch-agenda)
      ;; Its questions stop marking files once it closes.
      (add-hook 'kill-buffer-hook
                (lambda () (session-cockpit--mark-file-buffers nil (current-buffer)))
                nil t)
      (session-cockpit--refresh))
    (pop-to-buffer-same-window buffer)))

(defun session-cockpit--pick-session ()
  "Ask for a session with an agenda, the most recently updated first.
Return its ID."
  (let* ((lines (mapcar (lambda (session-id)
                          (cons (session-cockpit--picker-line session-id) session-id))
                        (session-cockpit--session-ids-newest-first)))
         (line (completing-read
                "Session: "
                (lambda (string predicate action)
                  (if (eq action 'metadata)
                      '(metadata (display-sort-function . identity)
                                 (cycle-sort-function . identity))
                    (complete-with-action action lines string predicate)))
                nil t)))
    (alist-get line lines nil nil #'equal)))

(defun session-cockpit--session-ids-newest-first ()
  "Return the IDs of the sessions with an agenda, the most recently updated first."
  (mapcar #'car
          (sort (seq-keep (lambda (directory)
                            (let ((agenda (expand-file-name "agenda.json" directory)))
                              (when (file-exists-p agenda)
                                (cons (file-name-nondirectory directory)
                                      (file-attribute-modification-time (file-attributes agenda))))))
                          (directory-files session-cockpit-state-directory t "\\`[^.]"))
                :key #'cdr :lessp #'time-less-p :reverse t)))

(defun session-cockpit--picker-line (session-id)
  "Return how the picker lists the session with SESSION-ID.
That is its project, when its agenda last changed and how many questions
wait for the user."
  (let* ((project (session-cockpit--project session-id))
         (agenda-file (expand-file-name "agenda.json"
                                        (expand-file-name session-id session-cockpit-state-directory))))
    (format "%s  %s  %d open"
            (file-name-nondirectory (directory-file-name project))
            (format-time-string "%m-%d %H:%M"
                                (file-attribute-modification-time (file-attributes agenda-file)))
            (length (session-cockpit--open-questions session-id)))))

(defun session-cockpit--watch-agenda ()
  "Redraw the current cockpit whenever its session's agenda changes.
The watch ends with the buffer or its mode."
  (let* ((cockpit (current-buffer))
         (directory (expand-file-name session-cockpit-session-id session-cockpit-state-directory))
         ;; The directory, not the file, in case the file is replaced on write.
         (watch (progn
                  (make-directory directory t)
                  (file-notify-add-watch
                   directory '(change)
                   (lambda (event)
                     (when (and (buffer-live-p cockpit)
                                (member "agenda.json"
                                        (mapcar (lambda (file)
                                                  (and (stringp file) (file-name-nondirectory file)))
                                                (cddr event))))
                       (with-current-buffer cockpit
                         (session-cockpit--refresh))))))))
    (dolist (hook '(kill-buffer-hook change-major-mode-hook))
      (add-hook hook (lambda () (file-notify-rm-watch watch)) nil t))))

(defun session-cockpit-pick (number)
  "Pick option NUMBER of the question at point, unsent until the next submit.
Interactively, NUMBER is the digit typed.  Picking a picked option takes
it back; on a question with a single answer, picking another switches."
  (interactive (list (- last-command-event ?0)))
  (let* ((id (session-cockpit--question-id-at-point))
         (options (alist-get 'options (session-cockpit--question id))))
    (unless (<= 1 number (length options))
      (user-error "[%s] has no option %d" id number))
    (session-cockpit--pick id (alist-get 'label (nth (1- number) options)))))

(defun session-cockpit-pick-or-write ()
  "Act on what is at point: show an anchor's lines, pick an option, or write.
Writing is text to the question at point."
  (interactive)
  (if-let* ((anchor (get-text-property (point) 'session-cockpit-anchor)))
      (apply #'session-cockpit--show-anchor anchor)
    (if-let* ((option (get-text-property (point) 'session-cockpit-option)))
        (session-cockpit--pick (car option) (cdr option))
      (session-cockpit-write))))

(defun session-cockpit-write ()
  "Write text to the question at point, unsent until the next submit.
It goes to Claude as the answer when no option is picked, and as a note
on the pick otherwise."
  (interactive)
  (session-cockpit--write (session-cockpit--question-id-at-point)))

(defun session-cockpit-delete-text ()
  "Delete the unsent text at point."
  (interactive)
  (session-cockpit--delete-text
   (or (get-text-property (point) 'session-cockpit-unsent-text)
       (user-error "No unsent text at point"))))

(defun session-cockpit--pick (id label)
  "Pick the option LABEL of the question with ID, or take the pick back."
  (let* ((question (session-cockpit--question id))
         (selected (session-cockpit--selected id))
         (picked (cond ((member label selected) (remove label selected))
                       ((eq (alist-get 'multiSelect question) t) (cons label selected))
                       (t (list label)))))
    (session-cockpit--set-answer
     id
     ;; In the options' order, whatever order they were picked in.
     (seq-keep (lambda (option) (car (member (alist-get 'label option) picked)))
               (alist-get 'options question))
     (session-cockpit--text id))))

(defun session-cockpit--write (id)
  "Write text to the question with ID, unsent until the next submit."
  (let ((cockpit (current-buffer)))
    (session-cockpit-edit-reply
     :reference (format "[%s] %s" id (session-cockpit--first-line
                                      (alist-get 'question (session-cockpit--question id))))
     :initial-text (session-cockpit--text id)
     :on-submit (lambda (text)
                  (with-current-buffer cockpit
                    ;; An emptied editor takes the text back.
                    (session-cockpit--set-answer id (session-cockpit--selected id)
                                                 (unless (string-empty-p text) text)))))))

(defun session-cockpit--delete-text (id)
  "Delete the unsent text on the question with ID."
  (session-cockpit--set-answer id (session-cockpit--selected id) nil))

(defun session-cockpit--set-answer (id selected text)
  "Make SELECTED and TEXT the unsent answer to the question with ID, and redraw.
With neither, the question has no unsent answer."
  (setf (alist-get id session-cockpit--answers nil 'remove #'equal)
        (when (or selected text) (cons selected text)))
  (session-cockpit--unsent-answers-changed))

(defun session-cockpit--selected (id)
  "Return the labels of the options picked on the question with ID."
  (car (alist-get id session-cockpit--answers nil nil #'equal)))

(defun session-cockpit--text (id)
  "Return the unsent text on the question with ID, or nil."
  (cdr (alist-get id session-cockpit--answers nil nil #'equal)))

(defun session-cockpit--unsent-answers-changed ()
  "Save the user's unsent answers, so they survive Emacs, and redraw."
  (session-cockpit--save-unsent-answers)
  (session-cockpit--refresh))

(defun session-cockpit--save-unsent-answers ()
  "Save the user's unsent answers, so they survive Emacs."
  (let ((path (session-cockpit--drafts-file session-cockpit-session-id))
        ;; Stored as the answers they will be submitted as.
        (answers (session-cockpit--submission-answers (current-buffer))))
    (if (seq-empty-p answers)
        (when (file-exists-p path)
          (delete-file path))
      (make-directory (file-name-directory path) t)
      (with-temp-file path
        (insert (json-serialize answers))))))

(defun session-cockpit--load-unsent-answers ()
  "Take up the unsent answers saved for the current cockpit's session."
  (let ((path (session-cockpit--drafts-file session-cockpit-session-id)))
    (when (file-exists-p path)
      (setq session-cockpit--answers
            (mapcar (lambda (answer)
                      (let-alist answer (cons .id (cons .selected .text))))
                    (session-cockpit--read-json path))))))

(defun session-cockpit--drafts-file (session-id)
  "Return the file holding the unsent answers for the session with SESSION-ID."
  (expand-file-name (format "%s.json" session-id) session-cockpit-drafts-directory))

(defun session-cockpit--question-id-at-point ()
  "Return the ID of the question at point, or signal a user error."
  (let ((section (magit-current-section)))
    (while (and section (not (eq (oref section type) 'question)))
      (setq section (oref section parent)))
    (if section
        (oref section value)
      (user-error "No question at point"))))

(defun session-cockpit--question (id)
  "Return the question with ID on the current cockpit's agenda."
  (seq-find (lambda (question) (equal (alist-get 'id question) id))
            (alist-get 'questions (session-cockpit--agenda session-cockpit-session-id))))

(defun session-cockpit--open-questions (session-id)
  "Return the questions of the session with SESSION-ID still waiting for the user."
  (seq-filter (lambda (question) (equal (alist-get 'status question) "open"))
              (alist-get 'questions (session-cockpit--agenda session-id))))

(defun session-cockpit--refresh ()
  "Draw the open questions and the user's unsent answers, keeping point's place."
  (session-cockpit--take-up-restored-answers)
  (session-cockpit--drop-stale-answers)
  (let ((place (session-cockpit--place-of-point))
        (inhibit-read-only t)
        (questions (session-cockpit--open-questions session-cockpit-session-id)))
    (setq header-line-format (session-cockpit--header-line))
    (erase-buffer)
    (magit-insert-section (agenda)
      (if questions
          (mapc #'session-cockpit--insert-question questions)
        (insert (propertize "No open questions." 'font-lock-face 'shadow) "\n")))
    (session-cockpit--restore-button-keymaps)
    ;; Hiding the collapsed sections takes effect only from here.
    (magit-section-show magit-root-section)
    (session-cockpit--goto-place place))
  (session-cockpit--mark-file-buffers))

(defvar-local session-cockpit--restored-answers-taken-up nil
  "IDs of the questions whose restored answer the cockpit took up already.")

(defun session-cockpit--take-up-restored-answers ()
  "Make the answers a rewind took back from Claude unsent answers again, and save.
Each is taken up once, so one the user deleted stays deleted, and only
where the user has no unsent answer of their own."
  (let ((changed nil))
    (dolist (question (session-cockpit--open-questions session-cockpit-session-id))
      (let-alist question
        (when (and .restored_answer
                   (not (member .id session-cockpit--restored-answers-taken-up)))
          (push .id session-cockpit--restored-answers-taken-up)
          (unless (alist-get .id session-cockpit--answers nil nil #'equal)
            (push (cons .id (cons (alist-get 'selected .restored_answer)
                                  (alist-get 'text .restored_answer)))
                  session-cockpit--answers)
            (setq changed t)))))
    (when changed
      (session-cockpit--save-unsent-answers))))

(defun session-cockpit--drop-stale-answers ()
  "Drop what Claude made moot of the unsent answers meanwhile, and save.
That is answers to questions no longer open, and picks of options Claude
took off a question."
  (let ((answers
         (seq-keep (pcase-lambda (`(,id . (,selected . ,text)))
                     (when-let* ((question (session-cockpit--question id))
                                 ((equal (alist-get 'status question) "open")))
                       (let ((selected (seq-filter
                                        (lambda (label)
                                          (seq-find (lambda (option) (equal (alist-get 'label option) label))
                                                    (alist-get 'options question)))
                                        selected)))
                         (when (or selected text)
                           (cons id (cons selected text))))))
                   session-cockpit--answers)))
    (unless (equal answers session-cockpit--answers)
      (setq session-cockpit--answers answers)
      (session-cockpit--save-unsent-answers))))

(defun session-cockpit--header-line ()
  "Return the header line: how many answers are unsent, and a Submit button."
  (let ((count (length session-cockpit--answers)))
    (concat " "
            (if (> count 0)
                ;; The button's padding adds the second space.
                (format "%d unsent answer%s " count (if (= count 1) "" "s"))
              "")
            (propertize " Submit "
                        'face 'session-cockpit-button
                        'mouse-face 'session-cockpit-button-hover
                        'keymap (define-keymap
                                  "<header-line> <mouse-1>" #'session-cockpit-submit-clicked)))))

(defun session-cockpit-submit-clicked (event)
  "Write a message to Claude from the cockpit whose Submit was clicked.
A click on a header line runs in the selected window, so this selects the
clicked one, which EVENT tells, first."
  (interactive "e")
  (select-window (posn-window (event-start event)))
  (session-cockpit-write-message))

(defun session-cockpit--place-of-point ()
  "Return where point is: its section and line within it, its line and column."
  (let ((section (magit-current-section)))
    (list :ident (and section (magit-section-ident section))
          :line-in-section (and section (count-lines (oref section start) (pos-bol)))
          :line (1- (line-number-at-pos))
          :column (current-column))))

(defun session-cockpit--goto-place (place)
  "Move point back to PLACE, as `session-cockpit--place-of-point' returned it.
If its section is gone, the line number counts instead."
  (if-let* ((section (and (plist-get place :ident)
                          (magit-get-section (plist-get place :ident)))))
      (progn (goto-char (oref section start))
             (forward-line (plist-get place :line-in-section)))
    (goto-char (point-min))
    (forward-line (plist-get place :line)))
  (move-to-column (plist-get place :column)))

;; A macro, so defined ahead of the functions using it.
(defmacro session-cockpit--tinting-news (thing &rest body)
  "Run BODY, which inserts THING, and tint what it inserted if THING is news.
News is what Claude asked or changed since the last submit."
  (declare (indent 1))
  (let ((start (make-symbol "start")))
    `(let ((,start (point)))
       (prog1 (progn ,@body)
         (when (session-cockpit--news ,thing)
           (font-lock-append-text-property ,start (point) 'font-lock-face
                                           'session-cockpit-new))))))

(defun session-cockpit--insert-question (question)
  "Insert QUESTION as a section: its options, then the user's text or a button.
Further lines of the question and everything below it line up behind its ID.
A question without options is answered in text alone."
  (let* ((id (alist-get 'id question))
         (label (concat (session-cockpit--id id) " "))
         (indentation (make-string (length label) ?\s))
         (first-line (session-cockpit--first-line (alist-get 'question question))))
    (magit-insert-section (question id)
      (session-cockpit--tinting-news question
        (magit-insert-heading
          label
          (propertize first-line 'font-lock-face 'session-cockpit-question)
          (session-cockpit--news-badge question)))
      (dolist (line (cdr (split-string (alist-get 'question question) "\n")))
        (insert indentation (propertize line 'font-lock-face 'session-cockpit-question) "\n"))
      (dolist (anchor (alist-get 'anchors question))
        (session-cockpit--insert-anchor anchor indentation))
      (seq-do-indexed (lambda (option index)
                        (session-cockpit--insert-option question option (1+ index) indentation))
                      (alist-get 'options question))
      (if-let* ((text (session-cockpit--text id)))
          (session-cockpit--insert-unsent-text id text indentation)
        (insert indentation
                (session-cockpit--button (cond ((null (alist-get 'options question)) "Answer…")
                                               ((session-cockpit--selected id) "Note…")
                                               (t "Other…"))
                                         (lambda () (session-cockpit--write id)))
                "\n")))
    ;; Space between questions, outside the section so collapsed ones keep it.
    (insert "\n")))

(defconst session-cockpit--excerpt-lines 3
  "How many lines of the text an anchor points at the cockpit shows.")

(defun session-cockpit--insert-anchor (anchor indentation)
  "Insert ANCHOR at INDENTATION: where its lines are now, and their text.
The text is cut off after `session-cockpit--excerpt-lines' lines.  An anchor
whose text is not in the file anymore is marked as not found.  `RET' or a
click anywhere on it shows its lines next to the cockpit."
  (let* ((location (session-cockpit--locate anchor))
         (target (list (alist-get 'file anchor) (or (car location) (alist-get 'start anchor))))
         (lines (session-cockpit--dedented (split-string (alist-get 'text anchor) "\n")))
         (excerpt-indentation (concat indentation "  "))
         (start (point)))
    (insert indentation
            (propertize (buttonize (concat "⌖ " (session-cockpit--anchor-reference
                                                 (session-cockpit--shown-path (alist-get 'file anchor))
                                                 (or location (cons (alist-get 'start anchor)
                                                                    (alist-get 'end anchor)))))
                                   (lambda (_) (apply #'session-cockpit--show-anchor target)))
                        'face nil
                        'mouse-face 'session-cockpit-button-hover
                        'font-lock-face 'session-cockpit-anchor)
            (if location
                ""
              (concat "  " (propertize "not found" 'font-lock-face 'session-cockpit-not-found)))
            "\n")
    (dolist (line (seq-take lines session-cockpit--excerpt-lines))
      (insert excerpt-indentation (propertize line 'font-lock-face 'session-cockpit-excerpt) "\n"))
    (when (> (length lines) session-cockpit--excerpt-lines)
      (let ((more (- (length lines) session-cockpit--excerpt-lines)))
        (insert excerpt-indentation
                (propertize (format "… %d more line%s" more (if (= more 1) "" "s"))
                            'font-lock-face 'shadow)
                "\n")))
    (put-text-property start (point) 'session-cockpit-anchor target)))

(defun session-cockpit--shown-path (path)
  "Return PATH as the cockpit shows it.
That is relative to the current cockpit's project when within it, and
starting with ~ when within the home directory otherwise."
  (let ((project (session-cockpit--project session-cockpit-session-id)))
    (if (file-in-directory-p path project)
        (file-relative-name path project)
      (abbreviate-file-name path))))

(defun session-cockpit--anchor-reference (file lines)
  "Return FILE and LINES, a cons of first and last line, as in lib/watch.rb:2-3.
A single line reads as lib/watch.rb:2."
  (format "%s:%s" file (if (= (car lines) (cdr lines))
                           (car lines)
                         (format "%d-%d" (car lines) (cdr lines)))))

(defun session-cockpit--dedented (lines)
  "Return LINES without the indentation they all share."
  (let ((indentation (apply #'min (or (seq-keep (lambda (line)
                                                   (unless (string-blank-p line)
                                                     (string-match "[^ \t]" line)))
                                                 lines)
                                       '(0)))))
    (mapcar (lambda (line) (if (string-blank-p line) "" (substring line indentation))) lines)))

(defun session-cockpit--insert-option (question option number indentation)
  "Insert OPTION, the NUMBERth of QUESTION, at INDENTATION, its preview below.
Its marker shows whether the user picked it; clicking it picks it."
  (let* ((id (alist-get 'id question))
         (label (alist-get 'label option))
         (picked (member label (session-cockpit--selected id)))
         (marker (if (eq (alist-get 'multiSelect question) t)
                     (if picked "[x]" "[ ]")
                   (if picked "(•)" "( )")))
         (prefix (format "%d. " number))
         (start (point)))
    (insert indentation prefix
            (propertize (buttonize (concat marker " " label)
                                   (lambda (_) (session-cockpit--pick id label)))
                        'face nil
                        'mouse-face 'session-cockpit-button-hover
                        'font-lock-face (if picked
                                            'session-cockpit-option-selected
                                          'session-cockpit-option))
            (if-let* ((description (alist-get 'description option))
                      ((not (string-empty-p description))))
                (concat " — " (propertize description 'font-lock-face 'session-cockpit-description))
              "")
            "\n")
    (put-text-property start (point) 'session-cockpit-option (cons id label))
    (when-let* ((preview (alist-get 'preview option)))
      (let ((preview-indentation (make-string (+ (length indentation) (length prefix)
                                                 (length marker) 1)
                                              ?\s)))
        (dolist (line (split-string preview "\n"))
          (insert preview-indentation (propertize line 'font-lock-face 'session-cockpit-preview) "\n"))))))

(defun session-cockpit--insert-unsent-text (id text indentation)
  "Insert the unsent TEXT on the question with ID, at INDENTATION."
  (let ((start (point)))
    (insert indentation (propertize "↳" 'font-lock-face 'session-cockpit-id) " "
            (propertize "you" 'font-lock-face 'session-cockpit-author)
            ": " (string-replace "\n" (concat "\n" indentation "  ") text)
            "  " (propertize "unsubmitted" 'font-lock-face 'session-cockpit-unsent-badge)
            ;; With the emoji selector, so Emacs takes an emoji font for it.
            "  " (propertize (buttonize "🗑️" (lambda (_) (session-cockpit--delete-text id)))
                             'face nil)
            "\n")
    (font-lock-append-text-property start (point) 'font-lock-face 'session-cockpit-unsent)
    (put-text-property start (point) 'session-cockpit-unsent-text id)))

(defun session-cockpit--news-badge (thing)
  "Return the badge for THING if Claude asked or changed it since the last submit."
  (if-let* ((news (session-cockpit--news thing)))
      (concat "  " (propertize news 'font-lock-face 'session-cockpit-new-badge))
    ""))

(defun session-cockpit--news (thing)
  "Return \"new\" or \"changed\" for what Claude did to THING since the last submit."
  (cond ((eq (alist-get 'new thing) t) "new")
        ((eq (alist-get 'changed thing) t) "changed")))

(defun session-cockpit--restore-button-keymaps ()
  "Give every button in the buffer its own keymap back.
A section with a body puts its heading keymap over the whole heading line,
which would make a click on a button there paste instead of push it."
  (let ((position (point-min)))
    (while (< position (point-max))
      (let ((next (next-single-property-change position 'button nil (point-max))))
        (when (get-text-property position 'button)
          (put-text-property position next 'keymap button-map))
        (setq position next)))))

(defun session-cockpit--button (label action)
  "Return a button reading LABEL that calls ACTION when pushed.
The label is padded inside the button's box."
  (propertize (buttonize (format " %s " label) (lambda (_) (funcall action)))
              'face nil
              'mouse-face 'session-cockpit-button-hover
              'font-lock-face 'session-cockpit-button))

(defun session-cockpit--id (id)
  "Return ID in brackets, dimmed."
  (propertize (format "[%s]" id) 'font-lock-face 'session-cockpit-id))

(defun session-cockpit--first-line (text)
  "Return the first line of TEXT."
  (car (split-string text "\n")))

;;;; Anchors in files
;; Where the lines a question points at are now, shown next to the cockpit
;; and marked in the buffers visiting their files.

(defun session-cockpit--locate (anchor)
  "Return where the lines of ANCHOR are now, as a cons of first and last line.
Its text is looked for in its file, or in the buffer visiting it; where it
occurs several times, the occurrence nearest the lines it was at wins.
Return nil when the text is not there anymore."
  (when-let* ((file-lines (session-cockpit--file-lines (alist-get 'file anchor))))
    (let* ((text-lines (split-string (alist-get 'text anchor) "\n"))
           (count (length text-lines))
           (wanted (1- (alist-get 'start anchor)))
           (best nil))
      (cl-loop for index from 0 to (- (length file-lines) count)
               for tail on file-lines
               when (and (equal (seq-take tail count) text-lines)
                         (or (null best) (< (abs (- index wanted)) (abs (- best wanted)))))
               do (setq best index))
      (when best
        (cons (1+ best) (+ best count))))))

(defun session-cockpit--file-lines (path)
  "Return the lines of the file at PATH, as the buffer visiting it has them.
Return nil if there is no such file."
  (if-let* ((buffer (find-buffer-visiting path)))
      (with-current-buffer buffer
        (save-restriction
          (widen)
          (split-string (buffer-substring-no-properties (point-min) (point-max)) "\n")))
    (when (file-readable-p path)
      (with-temp-buffer
        (insert-file-contents path)
        (split-string (buffer-string) "\n")))))

(defun session-cockpit--show-anchor (file line)
  "Show LINE of FILE next to the current cockpit.  Point stays in the cockpit."
  (let* ((buffer (if (file-exists-p file)
                     (find-file-noselect file)
                   (user-error "%s is not there anymore" (abbreviate-file-name file))))
         (window (display-buffer buffer '((display-buffer-reuse-window
                                           display-buffer-use-some-window
                                           display-buffer-pop-up-window)
                                          (inhibit-same-window . t)))))
    (with-selected-window window
      (goto-char (point-min))
      (forward-line (1- line))
      (recenter))))

(defface session-cockpit-anchored-lines
  '((((background dark)) :background "#3a3424" :extend t)
    (t :background "#fbf3dc" :extend t))
  "Face tinting the lines of a file that an open question points at.")

(defface session-cockpit-fringe-mark '((t :inherit warning))
  "Face of the question mark in the fringe beside lines a question points at.")

(define-fringe-bitmap 'session-cockpit-question-mark
  [#b00111100
   #b01100110
   #b00000110
   #b00001100
   #b00011000
   #b00011000
   #b00000000
   #b00011000
   #b00011000])

;; Visiting a file marks the lines the open questions point at.
(add-hook 'find-file-hook #'session-cockpit--mark-visited-file)

(defun session-cockpit--mark-visited-file ()
  "Mark the lines of the file just visited that open questions point at."
  (session-cockpit--mark-file-buffers (list (current-buffer))))

(defun session-cockpit--mark-file-buffers (&optional buffers leaving)
  "Mark the lines the open questions of the open cockpits point at.
Only BUFFERS are marked, by default all that visit files, and their earlier
marks are replaced.  LEAVING is a cockpit buffer about to close, whose
questions no longer count."
  (let ((anchors (session-cockpit--open-anchors leaving)))
    (dolist (buffer (or buffers (buffer-list)))
      (when-let* ((file (buffer-file-name buffer)))
        (with-current-buffer buffer
          (session-cockpit--mark
           (seq-filter (lambda (anchor) (file-equal-p (alist-get 'file (plist-get anchor :anchor)) file))
                       anchors)))))))

(defun session-cockpit--open-anchors (leaving)
  "Return the anchors of the open questions in the open cockpits but LEAVING.
Each is a plist of the :anchor itself and the :question pointing at it."
  (seq-mapcat
   (lambda (cockpit)
     (with-current-buffer cockpit
       (seq-mapcat (lambda (question)
                     (mapcar (lambda (anchor) (list :anchor anchor :question question))
                             (alist-get 'anchors question)))
                   (session-cockpit--open-questions session-cockpit-session-id))))
   (seq-filter (lambda (buffer)
                 (and (not (eq buffer leaving))
                      (eq (buffer-local-value 'major-mode buffer) 'session-cockpit-mode)
                      (buffer-local-value 'session-cockpit-session-id buffer)))
               (buffer-list))))

(defun session-cockpit--mark (anchors)
  "Mark the lines of ANCHORS in the current buffer, replacing earlier marks.
Each gets tinted, a question mark in the left fringe, and its question on
hover.  ANCHORS are as `session-cockpit--open-anchors' returns them."
  (save-excursion
    (save-restriction
      (widen)
      (remove-overlays (point-min) (point-max) 'session-cockpit-mark t)
      (dolist (anchor anchors)
        (when-let* ((lines (session-cockpit--locate (plist-get anchor :anchor))))
          (goto-char (point-min))
          (forward-line (1- (car lines)))
          (let ((start (point)))
            ;; Up to the start of the next line, so the tint spans the whole
            ;; width of the last line too.
            (forward-line (1+ (- (cdr lines) (car lines))))
            (let ((overlay (make-overlay start (point)))
                  (question (plist-get anchor :question)))
              (overlay-put overlay 'session-cockpit-mark t)
              (overlay-put overlay 'face 'session-cockpit-anchored-lines)
              (overlay-put overlay 'help-echo (format "[%s] %s" (alist-get 'id question)
                                                      (alist-get 'question question)))
              (overlay-put overlay 'before-string
                           (propertize " " 'display '(left-fringe session-cockpit-question-mark
                                                                  session-cockpit-fringe-mark))))))))))

(defun session-cockpit--lost-anchors (cockpit)
  "Return the anchors of COCKPIT's open questions whose text is gone.
They come as a submission lists them: question ID, file and lines."
  (with-current-buffer cockpit
    (vconcat
     (seq-mapcat (lambda (question)
                   (seq-keep (lambda (anchor)
                               (unless (session-cockpit--locate anchor)
                                 `((id . ,(alist-get 'id question))
                                   (file . ,(alist-get 'file anchor))
                                   (start . ,(alist-get 'start anchor))
                                   (end . ,(alist-get 'end anchor)))))
                             (alist-get 'anchors question)))
                 (session-cockpit--open-questions session-cockpit-session-id)))))

(defvar-keymap session-cockpit-message-mode-map
  "C-c C-c" #'session-cockpit-send-message
  "C-c C-k" #'session-cockpit-discard-message)

(define-derived-mode session-cockpit-message-mode text-mode "Cockpit Message"
  "Major mode for writing a message to Claude.
Lines starting with # are left out of the message, as in a commit message."
  (setq-local comment-start "# ")
  (setq-local font-lock-defaults '((("^#.*" . 'font-lock-comment-face)) t)))

(defvar-local session-cockpit--cockpit-buffer nil
  "The cockpit buffer a message buffer was opened from.")

(defun session-cockpit-write-message ()
  "Write a message to Claude in the session of the current cockpit.
Below the comment, the message buffer shows what Claude will read of the
submit.  Opened again, it keeps the comment and shows the submit anew."
  (interactive)
  (let ((session-id session-cockpit-session-id)
        (cockpit (current-buffer))
        (preview (session-cockpit--submission-preview (current-buffer)))
        (buffer (get-buffer-create (format "*session-cockpit message: %s*"
                                           session-cockpit-session-id))))
    (with-current-buffer buffer
      (let ((comment (session-cockpit--message-comment)))
        (session-cockpit-message-mode)
        (setq session-cockpit-session-id session-id
              session-cockpit--cockpit-buffer cockpit)
        (erase-buffer)
        (insert comment "\n"
                "# Write your comment for Claude above; lines starting with # are left out.\n"
                "# C-c C-c sends it with your answers, C-c C-k cancels.\n"
                "#\n"
                "# Claude reads your submit as:\n"
                (mapconcat (lambda (line) (concat "# " line "\n")) preview))
        (goto-char (+ (point-min) (length comment)))))
    (pop-to-buffer buffer)))

(defun session-cockpit--message-comment ()
  "Return the comment written in the current message buffer.
That is its text without the lines starting with #, trimmed."
  (string-trim (replace-regexp-in-string "^#.*\n?" "" (buffer-string))))

(defun session-cockpit--submission-preview (cockpit)
  "Return the lines Claude will read of a submit from COCKPIT, but the comment.
They are as the monitor prints them: each unsent answer under its question,
then the lines questions point at that are not in their files anymore."
  (with-current-buffer cockpit
    (let ((questions (alist-get 'questions (session-cockpit--agenda session-cockpit-session-id))))
      `("**Dashboard submit**"
        ,@(seq-mapcat (lambda (answer)
                        (session-cockpit--answer-preview
                         answer (seq-find (lambda (question)
                                            (equal (alist-get 'id question) (alist-get 'id answer)))
                                          questions)))
                      (session-cockpit--submission-answers cockpit))
        ,@(seq-map (lambda (anchor)
                     (format "⚠ [%s] %s is not in the file anymore"
                             (alist-get 'id anchor)
                             (session-cockpit--anchor-reference
                              (session-cockpit--shown-path (alist-get 'file anchor))
                              (cons (alist-get 'start anchor) (alist-get 'end anchor)))))
                   (session-cockpit--lost-anchors cockpit))))))

(defun session-cockpit--answer-preview (answer question)
  "Return the lines Claude will read of ANSWER to QUESTION.
Its text is the answer to a question without options, reads as Other when
no option was picked, and as a note on the pick otherwise."
  (let ((selected (append (alist-get 'selected answer) nil))
        (text (alist-get 'text answer)))
    `(,(format "[%s] %s" (alist-get 'id answer) (car (split-string (alist-get 'question question) "\n")))
      ,@(when selected
          (list (concat "  → " (string-join selected ", "))))
      ,@(when (and text (not (string-empty-p text)))
          (let ((label (cond ((null (alist-get 'options question)) "Answer: ")
                             ((null selected) "Other: ")
                             (t "Note: ")))
                (lines (split-string text "\n")))
            (cons (concat "  " label (car lines))
                  (mapcar (lambda (line) (concat "  " (make-string (length label) ?\s) line))
                          (cdr lines))))))))

(defun session-cockpit-send-message ()
  "Send the message in the current buffer to Claude, with the unsent answers.
It also tells which lines questions point at are not in their files anymore."
  (interactive)
  (let ((lost-anchors (session-cockpit--lost-anchors session-cockpit--cockpit-buffer)))
    (session-cockpit--submit session-cockpit-session-id
                             `((type . "submitted")
                               (comment . ,(session-cockpit--message-comment))
                               (answers . ,(session-cockpit--submission-answers
                                            session-cockpit--cockpit-buffer))
                               ,@(unless (seq-empty-p lost-anchors)
                                   `((lost_anchors . ,lost-anchors))))))
  (with-current-buffer session-cockpit--cockpit-buffer
    (setq session-cockpit--answers nil)
    (session-cockpit--unsent-answers-changed))
  (quit-window t))

(defun session-cockpit-discard-message ()
  "Close the message buffer, discarding the comment written in it.
Asks first if there is a comment to lose."
  (interactive)
  (when (or (string-empty-p (session-cockpit--message-comment))
            (y-or-n-p "Discard this comment? "))
    (quit-window t)))

(defun session-cockpit--submission-answers (cockpit)
  "Return the unsent answers of COCKPIT as a submission's answers.
They come in the order of their questions on the agenda."
  (with-current-buffer cockpit
    (vconcat
     (seq-keep (lambda (question)
                 (when-let* ((id (alist-get 'id question))
                             (answer (alist-get id session-cockpit--answers nil nil #'equal)))
                   `((id . ,id)
                     (selected . ,(vconcat (car answer)))
                     ,@(when (cdr answer) `((text . ,(cdr answer)))))))
               (alist-get 'questions (session-cockpit--agenda session-cockpit-session-id))))))

(defun session-cockpit--submit (session-id event)
  "Put EVENT into the inbox of the session with SESSION-ID.
Each submission is a file of its own, named so that the inbox sorts by
time.  Claude Code's side takes it over into the session's event log."
  (let ((inbox (expand-file-name "inbox" (expand-file-name session-id session-cockpit-state-directory))))
    (make-directory inbox t)
    (with-temp-file (expand-file-name (format "%s-%s.json"
                                              (format-time-string "%Y%m%dT%H%M%S.%6NZ" nil t)
                                              (md5 (format "%s%s" (random) (emacs-pid))))
                                      inbox)
      (insert (json-serialize event)))))

(defun session-cockpit--agenda (session-id)
  "Return the agenda of the session with SESSION-ID."
  (let ((path (expand-file-name "agenda.json"
                                (expand-file-name session-id session-cockpit-state-directory))))
    (when (file-exists-p path)
      (session-cockpit--read-json path))))

(defun session-cockpit--project (session-id)
  "Return the directory the session with SESSION-ID runs in."
  (alist-get 'project (session-cockpit--read-json
                       (expand-file-name "session.json"
                                         (expand-file-name session-id session-cockpit-state-directory)))))

(defun session-cockpit--read-json (path)
  "Return the JSON in the file at PATH, objects as alists and arrays as lists."
  (with-temp-buffer
    (insert-file-contents path)
    (json-parse-buffer :object-type 'alist :array-type 'list)))

;;;; Text editor
;; A child frame below the line at point, as kf-review's comment editor.

(defvar session-cockpit-editor-width 84
  "Width of the text editor in columns; fits an 80-column `fill-column'.")

(defvar session-cockpit-editor-height 12
  "Height of the text editor in lines.")

(defvar-local session-cockpit--editor-on-submit nil
  "Function the editor calls with the text once submitted.")

(defvar-local session-cockpit--editor-parent-frame nil
  "Frame that had input focus before the editor opened.")

(defvar-keymap session-cockpit-editor-mode-map
  "C-c C-c" #'session-cockpit-editor-submit
  "C-c C-k" #'session-cockpit-editor-cancel)

(define-minor-mode session-cockpit-editor-mode
  "Minor mode of the buffer text is written in."
  :keymap session-cockpit-editor-mode-map)

(cl-defun session-cockpit-edit-reply (&key reference initial-text on-submit)
  "Edit text to REFERENCE in a child frame below the line at point.
The editor starts out holding INITIAL-TEXT.  Submitting calls ON-SUBMIT with
the trimmed text, after the editor has closed and focus has returned."
  (let ((buffer (session-cockpit--editor-buffer reference initial-text on-submit))
        (frame (session-cockpit--editor-frame)))
    (set-window-buffer (frame-root-window frame) buffer)
    (set-window-dedicated-p (frame-root-window frame) t)
    (make-frame-visible frame)
    (select-frame-set-input-focus frame)))

(defun session-cockpit-editor-submit ()
  "Close the editor and hand the text over."
  (interactive)
  (let ((text (string-trim (buffer-string)))
        (on-submit session-cockpit--editor-on-submit))
    (session-cockpit--editor-close)
    (funcall on-submit text)))

(defun session-cockpit-editor-cancel ()
  "Close the editor without submitting, asking first if text would be lost."
  (interactive)
  (when (or (not (buffer-modified-p))
            (string-blank-p (buffer-string))
            (y-or-n-p "Discard this text? "))
    (session-cockpit--editor-close)))

(defun session-cockpit--editor-buffer (reference initial-text on-submit)
  "Return a fresh editor buffer for REFERENCE holding INITIAL-TEXT."
  ;; No leading space in the name: Emacs turns off font-lock and undo in
  ;; buffers named like that.
  (let ((buffer (generate-new-buffer "*session-cockpit text*"))
        (parent (selected-frame)))
    (with-current-buffer buffer
      (text-mode)
      (session-cockpit-editor-mode)
      (insert (or initial-text ""))
      (set-buffer-modified-p nil)
      (setq session-cockpit--editor-on-submit on-submit
            session-cockpit--editor-parent-frame parent
            mode-line-format nil
            header-line-format
            (format " Answer to %s   C-c C-c done · C-c C-k cancel" reference)))
    buffer))

(defun session-cockpit--editor-frame ()
  "Return an invisible child frame placed below the line at point."
  (let* ((origin (selected-window))
         (parent (selected-frame))
         ;; `make-frame' selects the frame it creates.
         (frame (make-frame
                 `((parent-frame . ,parent)
                   ;; Prompts such as the cancel confirmation use the
                   ;; parent's minibuffer.
                   (minibuffer . nil)
                   (visibility . nil)
                   (width . ,session-cockpit-editor-width)
                   (height . ,session-cockpit-editor-height)
                   (fullscreen . nil)
                   (undecorated . t)
                   (unsplittable . t)
                   (no-other-frame . t)
                   (child-frame-border-width . 1)
                   (left-fringe . 8)
                   (right-fringe . 0)
                   (vertical-scroll-bars . nil)
                   (horizontal-scroll-bars . nil)
                   (menu-bar-lines . 0)
                   (tool-bar-lines . 0)
                   (tab-bar-lines . 0)
                   (desktop-dont-save . t)))))
    (with-selected-window origin
      (session-cockpit--place-below-point frame))
    frame))

(defun session-cockpit--place-below-point (frame)
  "Move child FRAME to the left edge of the selected window, below point.
FRAME goes above the line instead when there is no room below it."
  (let* ((window-edges (window-inside-pixel-edges))
         (point-y (or (cdr (posn-x-y (posn-at-point))) 0))
         (line-top (+ (nth 1 window-edges) point-y))
         (below (+ line-top (line-pixel-height)))
         (above (- line-top (frame-pixel-height frame)))
         (fits-below (<= (+ below (frame-pixel-height frame))
                         (frame-pixel-height (frame-parent frame)))))
    (set-frame-position frame
                        (nth 0 window-edges)
                        (if (or fits-below (< above 0)) below above))))

(defun session-cockpit--editor-close ()
  "Delete the editor frame and buffer and refocus the frame it came from."
  (let ((buffer (current-buffer))
        (frame (selected-frame))
        (parent session-cockpit--editor-parent-frame))
    (select-frame-set-input-focus parent)
    (delete-frame frame)
    (kill-buffer buffer)))

(provide 'session-cockpit)
;;; session-cockpit.el ends here
