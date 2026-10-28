;;; session-cockpit-test.el --- Tests for session-cockpit.el -*- lexical-binding: t; -*-

;;; Commentary:
;; What the cockpit buffer shows of a session, and how what the user answers
;; there reaches Claude.

;;; Code:

(require 'ert)
(require 'session-cockpit)
(require 'session-cockpit-test-helpers)

(ert-deftest session-cockpit-test-an-open-question-shows-its-numbered-options ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?"
                              '(("JSON lines" "Greppable") ("SQLite" "Queryable")))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. ( ) JSON lines — Greppable"
     "     2. ( ) SQLite — Queryable"
     "      Other…")))

(ert-deftest session-cockpit-test-a-question-without-options-offers-only-an-answer-in-text ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "What should the log be called?")

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] What should the log be called?"
     "      Answer…")))

(ert-deftest session-cockpit-test-a-multi-select-questions-options-show-checkboxes ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which parts ship first?"
                              '(("Picker" "Lists sessions") ("Header" "Counts answers"))
                              :multi-select t)

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] Which parts ship first?"
     "     1. [ ] Picker — Lists sessions"
     "     2. [ ] Header — Counts answers"
     "      Other…")))

(ert-deftest session-cockpit-test-an-options-preview-is-shown-below-it-behind-its-marker ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which header?"
                              '(("Count" "Shows the count" "2 unsent\nSubmit") ("Plain" "Only Submit")))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] Which header?"
     "     1. ( ) Count — Shows the count"
     "            2 unsent"
     "            Submit"
     "     2. ( ) Plain — Only Submit"
     "      Other…")))

(ert-deftest session-cockpit-test-further-lines-of-a-question-continue-behind-its-id ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?\nBoth work."
                              '(("JSON lines" "Greppable") ("SQLite" "Queryable")))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     Both work."
     "     1. ( ) JSON lines — Greppable"
     "     2. ( ) SQLite — Queryable"
     "      Other…")))

(ert-deftest session-cockpit-test-answered-and-withdrawn-questions-are-not-shown ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite")
                              :status "answered")
    (session-cockpit-test-ask session "Rename the log?" '("Yes" "No") :status "withdrawn")
    (session-cockpit-test-ask session "Which parts ship first?" '("Picker" "Header"))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q3] Which parts ship first?"
     "     1. ( ) Picker"
     "     2. ( ) Header"
     "      Other…")))

(ert-deftest session-cockpit-test-without-open-questions-the-cockpit-says-so ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite")
                              :status "answered")

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read "No open questions.")))

(ert-deftest session-cockpit-test-a-question-is-followed-by-an-empty-line ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Rename the log?" '("Yes" "No"))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. ( ) JSON lines"
     "     2. ( ) SQLite"
     "      Other…"
     ""
     "[q2] Rename the log?"
     "     1. ( ) Yes"
     "     2. ( ) No"
     "      Other…")))

(ert-deftest session-cockpit-test-tab-on-a-question-hides-its-options ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")

    (session-cockpit-test-user-types "TAB")

    (session-cockpit-test-buffer-should-read "[q1] JSON lines or SQLite?")))

(ert-deftest session-cockpit-test-a-collapsed-question-is-followed-by-an-empty-line-too ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Rename the log?" '("Yes" "No"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")

    (session-cockpit-test-user-types "TAB")

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     ""
     "[q2] Rename the log?"
     "     1. ( ) Yes"
     "     2. ( ) No"
     "      Other…")))

(ert-deftest session-cockpit-test-a-wrapped-question-continues-behind-its-id ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?\nBoth work." '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (should (equal (session-cockpit-test-wrap-indentation "Both work.") 5))))

(ert-deftest session-cockpit-test-a-wrapped-option-continues-behind-its-marker ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?"
                              '(("JSON lines" "Greppable") ("SQLite" "Queryable")))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (should (equal (session-cockpit-test-wrap-indentation "JSON lines — Greppable") 12))))

(ert-deftest session-cockpit-test-a-new-question-shows-a-new-badge ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite") :new t)

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (should (equal (session-cockpit-test-line-at-point) "[q1] JSON lines or SQLite?  new"))))

(ert-deftest session-cockpit-test-a-changed-question-shows-a-changed-badge ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite") :changed t)

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (should (equal (session-cockpit-test-line-at-point) "[q1] JSON lines or SQLite?  changed"))))

(ert-deftest session-cockpit-test-typing-an-options-number-picks-it ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")

    (session-cockpit-test-user-types "2")

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. ( ) JSON lines"
     "     2. (•) SQLite"
     "      Note…")))

(ert-deftest session-cockpit-test-picking-another-option-of-a-single-answer-question-switches ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "2")

    (session-cockpit-test-user-types "1")

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. (•) JSON lines"
     "     2. ( ) SQLite"
     "      Note…")))

(ert-deftest session-cockpit-test-picking-the-picked-option-takes-the-pick-back ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "2")

    (session-cockpit-test-user-types "2")

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. ( ) JSON lines"
     "     2. ( ) SQLite"
     "      Other…")))

(ert-deftest session-cockpit-test-on-a-multi-select-question-picks-add-up ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which parts ship first?" '("Picker" "Header" "Brief")
                              :multi-select t)
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which parts ship first?")

    (session-cockpit-test-user-types "3" "1")

    (session-cockpit-test-buffer-should-read
     "[q1] Which parts ship first?"
     "     1. [x] Picker"
     "     2. [ ] Header"
     "     3. [x] Brief"
     "      Note…")))

(ert-deftest session-cockpit-test-clicking-an-option-picks-it ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-user-clicks "SQLite" :on "2. ( ) SQLite")

    (session-cockpit-test-goto-line-with "2. ")
    (should (equal (session-cockpit-test-line-at-point) "     2. (•) SQLite"))))

(ert-deftest session-cockpit-test-ret-on-an-option-picks-it ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?"
                              '(("JSON lines" "Greppable") ("SQLite" "Queryable")))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Queryable")
    (end-of-line)

    (session-cockpit-test-user-types "RET")

    (session-cockpit-test-goto-line-with "Queryable")
    (should (equal (session-cockpit-test-line-at-point) "     2. (•) SQLite — Queryable"))))

(ert-deftest session-cockpit-test-a-number-without-an-option-says-so ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")

    (should (equal (session-cockpit-test-user-error-from "3") "[q1] has no option 3"))))

(ert-deftest session-cockpit-test-written-text-shows-under-the-options-as-unsent ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")

    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-buffer-should-read
     "[q1] Which name?"
     "     1. ( ) events"
     "     2. ( ) log"
     "     ↳ you: history  unsubmitted  🗑️")))

(ert-deftest session-cockpit-test-r-on-a-question-with-unsent-text-opens-it-for-editing ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))

    (should (equal (session-cockpit-test-user-will-write "history, maybe"
                     (session-cockpit-test-user-types "r"))
                   '(:reference "[q1] Which name?" :initial-text "history")))))

(ert-deftest session-cockpit-test-ret-on-a-questions-heading-opens-the-editor ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")

    (should (equal (session-cockpit-test-user-will-write "history"
                     (session-cockpit-test-user-types "RET"))
                   '(:reference "[q1] Which name?" :initial-text nil)))))

(ert-deftest session-cockpit-test-clicking-other-opens-the-editor ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (should (equal (session-cockpit-test-user-will-write "history"
                     (session-cockpit-test-user-clicks "Other…" :on "Other…"))
                   '(:reference "[q1] Which name?" :initial-text nil)))))

(ert-deftest session-cockpit-test-k-on-unsent-text-deletes-it ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))
    (session-cockpit-test-goto-line-with "↳ you: history")

    (session-cockpit-test-user-types "k")

    (session-cockpit-test-buffer-should-read
     "[q1] Which name?"
     "     1. ( ) events"
     "     2. ( ) log"
     "      Other…")))

(ert-deftest session-cockpit-test-clicking-the-trash-can-deletes-the-unsent-text ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-user-clicks "🗑️" :on "↳ you: history")

    (session-cockpit-test-buffer-should-read
     "[q1] Which name?"
     "     1. ( ) events"
     "     2. ( ) log"
     "      Other…")))

(ert-deftest session-cockpit-test-an-empty-text-from-the-editor-drops-the-unsent-one ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-user-will-write ""
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-buffer-should-read
     "[q1] Which name?"
     "     1. ( ) events"
     "     2. ( ) log"
     "      Other…")))

(ert-deftest session-cockpit-test-a-submit-sends-the-picks-and-texts-with-the-comment ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")
    (session-cockpit-test-user-will-write "Keep it greppable"
      (session-cockpit-test-user-types "r"))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-user-submits-with-comment "Go ahead")

    (should (equal (session-cockpit-test-last-submission session)
                   '((answers . [((id . "q1") (selected . ["JSON lines"]) (text . "Keep it greppable"))
                                 ((id . "q2") (selected . []) (text . "history"))])
                     (comment . "Go ahead")
                     (type . "submitted"))))))

(ert-deftest session-cockpit-test-a-submit-sends-the-answers-in-the-order-of-the-questions ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-types "2")
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")

    (session-cockpit-test-user-submits-with-comment "")

    (should (equal (alist-get 'answers (session-cockpit-test-last-submission session))
                   [((id . "q1") (selected . ["JSON lines"]))
                    ((id . "q2") (selected . ["log"]))]))))

(ert-deftest session-cockpit-test-after-a-submit-nothing-is-picked-anymore ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")

    (session-cockpit-test-user-submits-with-comment "")

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. ( ) JSON lines"
     "     2. ( ) SQLite"
     "      Other…")))

(ert-deftest session-cockpit-test-a-comment-written-in-the-message-buffer-is-submitted ()
  (session-cockpit-test-with-session session
    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-user-submits-with-comment "JSON lines sounds good")

    (should (equal (session-cockpit-test-submissions session)
                   '("JSON lines sounds good")))))

(ert-deftest session-cockpit-test-c-c-c-k-discards-the-comment ()
  (session-cockpit-test-with-session session
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-user-types "c")
    (insert "Go ahead")
    (session-cockpit-test-user-will-answer "y"
      (session-cockpit-test-user-types "C-c C-k"))

    (session-cockpit-test-user-types "c")

    (should (equal (session-cockpit-test-written-comment) ""))))

(ert-deftest session-cockpit-test-c-c-c-k-asks-before-discarding-a-written-comment ()
  (session-cockpit-test-with-session session
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-user-types "c")
    (insert "Go ahead")

    (should (equal (session-cockpit-test-user-will-answer "n"
                     (session-cockpit-test-user-types "C-c C-k"))
                   "Discard this comment? "))
    (should (equal (session-cockpit-test-written-comment) "Go ahead"))))

(ert-deftest session-cockpit-test-lines-starting-with-hash-are-left-out-of-the-comment ()
  (session-cockpit-test-with-session session
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-user-types "c")
    (insert "Go ahead\n# just a note to myself")

    (session-cockpit-test-user-types "C-c C-c")

    (should (equal (session-cockpit-test-submissions session) '("Go ahead")))))

(ert-deftest session-cockpit-test-the-message-buffer-shows-what-claude-will-read ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "What should the log be called?")
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "What should the log be called?")
    (session-cockpit-test-user-will-write "events"
      (session-cockpit-test-user-types "r"))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-will-write "Whatever is\neasiest to grep"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-user-types "c")

    (should (equal (session-cockpit-test-message-preview)
                   (concat "**Dashboard submit**\n"
                           "[q1] What should the log be called?\n"
                           "  Answer: events\n"
                           "[q2] JSON lines or SQLite?\n"
                           "  Other: Whatever is\n"
                           "         easiest to grep\n")))))

(ert-deftest session-cockpit-test-opening-the-message-buffer-again-keeps-the-comment-and-shows-the-submit-anew ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-user-types "c")
    (insert "Go ahead")
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")

    (session-cockpit-test-user-types "c")

    (should (equal (session-cockpit-test-written-comment) "Go ahead"))
    (should (equal (session-cockpit-test-message-preview)
                   "**Dashboard submit**\n[q1] JSON lines or SQLite?\n  → JSON lines\n"))))

(ert-deftest session-cockpit-test-the-header-line-counts-the-unsent-answers ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-will-write "history"
      (session-cockpit-test-user-types "r"))

    (should (equal (session-cockpit-test-header-line) "2 unsent answers  Submit"))))

(ert-deftest session-cockpit-test-with-nothing-unsent-the-header-line-shows-only-submit ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (should (equal (session-cockpit-test-header-line) "Submit"))))

(ert-deftest session-cockpit-test-clicking-submit-opens-the-message-buffer ()
  (session-cockpit-test-with-session session
    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-user-clicks-in-header-line "Submit")
    (insert "Go ahead")
    (session-cockpit-test-user-types "C-c C-c")

    (should (equal (session-cockpit-test-submissions session) '("Go ahead")))))

(ert-deftest session-cockpit-test-clicking-submit-while-another-window-is-selected-opens-the-cockpits-message-buffer ()
  (session-cockpit-test-with-session session
    (session-cockpit-show (session-cockpit-test-session-id session))
    (let ((cockpit (current-buffer)))
      (select-window (display-buffer (get-buffer-create "*scratch*") '(nil (inhibit-same-window . t))))

      (session-cockpit-test-user-clicks-in-header-line "Submit" :of cockpit)
      (insert "Go ahead")
      (session-cockpit-test-user-types "C-c C-c")

      (should (equal (session-cockpit-test-submissions session) '("Go ahead"))))))

(ert-deftest session-cockpit-test-unsent-answers-survive-restarting-emacs ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")
    (session-cockpit-test-user-will-write "Keep it greppable"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-user-restarts-emacs)
    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?"
     "     1. (•) JSON lines"
     "     2. ( ) SQLite"
     "     ↳ you: Keep it greppable  unsubmitted  🗑️")))

(ert-deftest session-cockpit-test-g-shows-what-claude-changed-meanwhile ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-set-status session "JSON lines or SQLite?" "withdrawn")

    (session-cockpit-test-user-types "g")

    (session-cockpit-test-buffer-should-read "No open questions.")))

(ert-deftest session-cockpit-test-the-cockpit-redraws-when-claude-changes-the-agenda ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-ask session "Which name?" '("events" "log"))

    (session-cockpit-test-wait-until
     (string-match-p "Which name?" (session-cockpit-test-visible-text)))))

(ert-deftest session-cockpit-test-an-unsent-answer-to-a-question-claude-withdrew-is-dropped ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "1")
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-user-types "2")

    (session-cockpit-test-set-status session "JSON lines or SQLite?" "withdrawn")
    (session-cockpit-test-user-types "g")
    (session-cockpit-test-user-submits-with-comment "")

    (should (equal (alist-get 'answers (session-cockpit-test-last-submission session))
                   [((id . "q2") (selected . ["log"]))]))))

(ert-deftest session-cockpit-test-a-pick-of-an-option-claude-took-off-is-dropped-but-not-the-text ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "2")
    (session-cockpit-test-user-will-write "Queries matter"
      (session-cockpit-test-user-types "r"))

    (session-cockpit-test-set-options session "JSON lines or SQLite?" '("JSON lines" "Postgres"))
    (session-cockpit-test-user-types "g")

    (session-cockpit-test-buffer-should-read
     "[q1] JSON lines or SQLite?  changed"
     "     1. ( ) JSON lines"
     "     2. ( ) Postgres"
     "     ↳ you: Queries matter  unsubmitted  🗑️")))

(ert-deftest session-cockpit-test-a-redraw-keeps-point-on-the-same-question ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-test-ask session "Which name?" '("events" "log"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "Which name?")
    (session-cockpit-test-set-status session "JSON lines or SQLite?" "withdrawn")

    (session-cockpit-test-user-types "g")

    (should (equal (session-cockpit-test-line-at-point) "[q2] Which name?"))))

(ert-deftest session-cockpit-test-a-redraw-keeps-a-collapsed-question-collapsed ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-ask session "JSON lines or SQLite?" '("JSON lines" "SQLite"))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-types "TAB")

    (session-cockpit-test-user-types "g")

    (session-cockpit-test-buffer-should-read "[q1] JSON lines or SQLite?")))

(ert-deftest session-cockpit-test-the-session-picker-lists-sessions-newest-updated-first ()
  (session-cockpit-test-with-session older
    (let ((newer (session-cockpit-test-another-session older)))
      (session-cockpit-test-set-project older "/Users/me/workspace/dev-settings")
      (session-cockpit-test-ask older "Which theme?" '("Light" "Dark") :status "answered")
      (session-cockpit-test-set-project newer "/Users/me/workspace/claude-plugins")
      (session-cockpit-test-ask newer "JSON lines or SQLite?" '("JSON lines" "SQLite"))
      (session-cockpit-test-ask newer "Which name?" '("events" "log"))
      (session-cockpit-test-set-updated older "2026-10-25 09:15")
      (session-cockpit-test-set-updated newer "2026-10-25 14:02")

      (should (equal (session-cockpit-test-user-will-pick 0
                       (call-interactively #'session-cockpit-show))
                     '("claude-plugins  10-25 14:02  2 open"
                       "dev-settings  10-25 09:15  0 open"))))))

(provide 'session-cockpit-test)
;;; session-cockpit-test.el ends here
