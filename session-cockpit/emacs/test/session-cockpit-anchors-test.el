;;; session-cockpit-anchors-test.el --- Tests for the places questions point at -*- lexical-binding: t; -*-

;;; Commentary:
;; Places in the project's files a question points at: how the cockpit shows
;; them, finds them again once the files change, and marks them in the
;; buffers visiting those files.

;;; Code:

(require 'ert)
(require 'session-cockpit)
(require 'session-cockpit-test-helpers)

(defconst session-cockpit-test-watch-rb
  "module Watch\n  def self.run\n    loop do\n      deliver\n      sleep 0.1\n    end\n  end\nend\n"
  "A file for questions to point at.")

(ert-deftest session-cockpit-test-an-anchor-shows-below-its-question-with-its-lines ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" '("Yes" "No")
                              :anchors '(("lib/watch.rb" 2 3)))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] Should this also handle /clear?"
     "     ⌖ lib/watch.rb:2-3"
     "       def self.run"
     "         loop do"
     "     1. ( ) Yes"
     "     2. ( ) No"
     "      Other…")))

(ert-deftest session-cockpit-test-an-anchor-on-a-single-line-names-only-that-line ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Why a module?" nil :anchors '(("lib/watch.rb" 1)))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] Why a module?"
     "     ⌖ lib/watch.rb:1"
     "       module Watch"
     "      Answer…")))

(ert-deftest session-cockpit-test-an-anchors-lines-are-cut-off-after-three ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Is this loop fine?" nil :anchors '(("lib/watch.rb" 3 6)))

    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-buffer-should-read
     "[q1] Is this loop fine?"
     "     ⌖ lib/watch.rb:3-6"
     "       loop do"
     "         deliver"
     "         sleep 0.1"
     "       … 1 more line"
     "      Answer…")))

(ert-deftest session-cockpit-test-ret-on-an-anchor-shows-its-lines-next-to-the-cockpit ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-goto-line-with "loop do")

    (session-cockpit-test-user-types "RET")

    (should (equal (session-cockpit-test-shown-lines) '("watch.rb" 2)))
    (should (eq major-mode 'session-cockpit-mode))))

(ert-deftest session-cockpit-test-clicking-an-anchor-shows-its-lines ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (session-cockpit-test-user-clicks "⌖ lib/watch.rb:2-3" :on "⌖")

    (should (equal (session-cockpit-test-shown-lines) '("watch.rb" 2)))))

(ert-deftest session-cockpit-test-an-anchor-whose-lines-moved-shows-where-they-are-now ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-change-file session "lib/watch.rb"
                                      (concat "# frozen_string_literal: true\n\n"
                                              session-cockpit-test-watch-rb))

    (session-cockpit-test-user-types "g")

    (session-cockpit-test-goto-line-with "⌖")
    (should (equal (session-cockpit-test-line-at-point) "     ⌖ lib/watch.rb:4-5"))))

(ert-deftest session-cockpit-test-of-several-places-with-the-text-the-nearest-wins ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session '(("notes.txt" . "a\nTODO\nb\nTODO\nc\n")))
    (session-cockpit-test-ask session "Which TODO first?" nil :anchors '(("notes.txt" 4)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-change-file session "notes.txt" "a\nTODO\nb\nx\nTODO\nc\n")

    (session-cockpit-test-user-types "g")

    (session-cockpit-test-goto-line-with "⌖")
    (should (equal (session-cockpit-test-line-at-point) "     ⌖ notes.txt:5"))))

(ert-deftest session-cockpit-test-an-anchor-whose-text-is-gone-shows-as-not-found ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Why a module?" nil :anchors '(("lib/watch.rb" 1)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (session-cockpit-test-change-file session "lib/watch.rb"
                                      (string-replace "module" "class" session-cockpit-test-watch-rb))

    (session-cockpit-test-user-types "g")

    (session-cockpit-test-buffer-should-read
     "[q1] Why a module?"
     "     ⌖ lib/watch.rb:1  not found"
     "       module Watch"
     "      Answer…")))

(ert-deftest session-cockpit-test-a-submit-tells-claude-which-anchors-were-not-found ()
  (session-cockpit-test-with-session session
    (let ((project (session-cockpit-test-create-project
                    session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))))
      (session-cockpit-test-ask session "Why a module?" nil :anchors '(("lib/watch.rb" 1)))
      (session-cockpit-test-ask session "Is this loop fine?" nil :anchors '(("lib/watch.rb" 3)))
      (session-cockpit-show (session-cockpit-test-session-id session))
      (session-cockpit-test-change-file session "lib/watch.rb"
                                        (string-replace "module" "class" session-cockpit-test-watch-rb))

      (session-cockpit-test-user-submits-with-comment "")

      (should (equal (alist-get 'lost_anchors (session-cockpit-test-last-submission session))
                     (vector `((end . 1) (file . ,(expand-file-name "lib/watch.rb" project))
                               (id . "q1") (start . 1))))))))

(ert-deftest session-cockpit-test-an-anchor-outside-the-project-shows-its-full-path-home-as-tilde ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (let ((elsewhere (make-temp-file "~/session-cockpit-test-" t)))
      (unwind-protect
          (progn
            (with-temp-file (expand-file-name "zshrc" elsewhere)
              (insert "export EDITOR=emacsclient\n"))
            (session-cockpit-test-ask session "Keep emacsclient?" nil
                                      :anchors `((,(expand-file-name "zshrc" elsewhere) 1)))

            (session-cockpit-show (session-cockpit-test-session-id session))

            (session-cockpit-test-goto-line-with "⌖")
            (should (equal (session-cockpit-test-line-at-point)
                           (format "     ⌖ ~/%s/zshrc:1" (file-name-nondirectory elsewhere)))))
        (delete-directory elsewhere t)))))

(ert-deftest session-cockpit-test-a-visited-file-marks-the-lines-open-questions-point-at ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))

    (let ((file (session-cockpit-test-user-visits session "lib/watch.rb")))

      (should (equal (session-cockpit-test-marks file)
                     '((2 3 "[q1] Should this also handle /clear?")))))))

(ert-deftest session-cockpit-test-a-file-visited-before-the-cockpit-opened-gets-marked-too ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (let ((file (session-cockpit-test-user-visits session "lib/watch.rb")))

      (session-cockpit-show (session-cockpit-test-session-id session))

      (should (equal (session-cockpit-test-marks file)
                     '((2 3 "[q1] Should this also handle /clear?")))))))

(ert-deftest session-cockpit-test-a-mark-follows-its-lines-when-they-move ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (let ((file (session-cockpit-test-user-visits session "lib/watch.rb")))
      (session-cockpit-test-change-file session "lib/watch.rb"
                                        (concat "# frozen_string_literal: true\n\n"
                                                session-cockpit-test-watch-rb))

      (session-cockpit-test-user-types "g")

      (should (equal (session-cockpit-test-marks file)
                     '((4 5 "[q1] Should this also handle /clear?")))))))

(ert-deftest session-cockpit-test-a-question-no-longer-open-stops-marking ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (let ((file (session-cockpit-test-user-visits session "lib/watch.rb")))
      (session-cockpit-test-set-status session "Should this also handle /clear?" "withdrawn")

      (session-cockpit-test-user-types "g")

      (should (equal (session-cockpit-test-marks file) nil)))))

(ert-deftest session-cockpit-test-closing-the-cockpit-takes-its-marks-away ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-create-project session `(("lib/watch.rb" . ,session-cockpit-test-watch-rb)))
    (session-cockpit-test-ask session "Should this also handle /clear?" nil :anchors '(("lib/watch.rb" 2 3)))
    (session-cockpit-show (session-cockpit-test-session-id session))
    (let ((file (session-cockpit-test-user-visits session "lib/watch.rb")))

      (kill-buffer (format "*session-cockpit: %s*" (session-cockpit-test-session-id session)))

      (should (equal (session-cockpit-test-marks file) nil)))))

(provide 'session-cockpit-anchors-test)
;;; session-cockpit-anchors-test.el ends here
