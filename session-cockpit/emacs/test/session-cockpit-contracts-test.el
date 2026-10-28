;;; session-cockpit-contracts-test.el --- Emacs's half of the contracts -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs and Claude Code's side meet at files: the agenda Emacs reads and the
;; submissions it puts into the inbox.  Each scenario in the plugin's
;; contract_fixtures holds those files step by step, with what Claude and the
;; user see of them; these tests hold Emacs to it, and Ruby's contract tests
;; hold the other side.

;;; Code:

(require 'ert)
(require 'session-cockpit)
(require 'session-cockpit-test-helpers)

(ert-deftest session-cockpit-test-round-trip ()
  (session-cockpit-test-with-session session
    (session-cockpit-test-set-session-info
     session (session-cockpit-test-contract-fixture "round_trip/01_session.json"))
    (session-cockpit-test-set-agenda
     session (session-cockpit-test-contract-fixture "round_trip/01_agenda.json"))
    (session-cockpit-test-set-updated session "2026-10-25 14:02")
    (should (equal (session-cockpit-test-user-will-pick 0
                     (call-interactively #'session-cockpit-show))
                   (split-string (session-cockpit-test-contract-fixture "round_trip/01_picker.txt")
                                 "\n" t)))
    (should (equal (session-cockpit-test-visible-text)
                   (session-cockpit-test-contract-fixture "round_trip/01_dashboard.txt")))

    (session-cockpit-test-user-clicks "JSON lines (Recommended)" :on "JSON lines (Recommended)")
    (session-cockpit-test-goto-line-with "JSON lines or SQLite?")
    (session-cockpit-test-user-will-write "Keep it greppable"
      (session-cockpit-test-user-types "r"))
    (session-cockpit-test-goto-line-with "Which parts ship first?")
    (session-cockpit-test-user-types "1" "2")
    (session-cockpit-test-user-submits-with-comment "Go ahead")
    (should (equal (session-cockpit-test-last-submission session)
                   (session-cockpit-test-contract-fixture "round_trip/02_submission.json")))

    (session-cockpit-test-set-agenda
     session (session-cockpit-test-contract-fixture "round_trip/03_agenda.json"))
    (session-cockpit-test-user-types "g")
    (should (equal (session-cockpit-test-visible-text)
                   (session-cockpit-test-contract-fixture "round_trip/03_dashboard.txt")))

    (session-cockpit-test-set-agenda
     session (session-cockpit-test-contract-fixture "round_trip/04_agenda.json"))
    (session-cockpit-test-user-types "g")
    (should (equal (session-cockpit-test-visible-text)
                   (session-cockpit-test-contract-fixture "round_trip/04_dashboard.txt")))))

(ert-deftest session-cockpit-test-anchors ()
  (session-cockpit-test-with-session session
    (let ((project (session-cockpit-test-copy-contract-project session "anchors/project")))
      (session-cockpit-test-set-agenda
       session (session-cockpit-test-contract-fixture "anchors/01_agenda.json" project))
      (session-cockpit-show (session-cockpit-test-session-id session))
      (should (equal (session-cockpit-test-visible-text)
                     (session-cockpit-test-contract-fixture "anchors/01_dashboard.txt")))

      (session-cockpit-test-change-file session "lib/watch.rb"
                                        (concat "# frozen_string_literal: true\n"
                                                "\n"
                                                "module SessionCockpit\n"
                                                "  module Watch\n"
                                                "    def self.run(out:)\n"
                                                "      loop do\n"
                                                "        deliver(out)\n"
                                                "        sleep 0.1\n"
                                                "      end\n"
                                                "    end\n"
                                                "  end\n"
                                                "end\n"))
      (session-cockpit-test-change-file session "README.md"
                                        "# The watch\n\nDelivers what the user submits.\n")
      (session-cockpit-test-user-types "g")
      (should (equal (session-cockpit-test-visible-text)
                     (session-cockpit-test-contract-fixture "anchors/02_dashboard.txt")))
      (session-cockpit-test-goto-line-with "Should the watch also follow /clear?")
      (session-cockpit-test-user-types "1")
      (session-cockpit-test-user-submits-with-comment "Go ahead")
      (should (equal (session-cockpit-test-last-submission session)
                     (session-cockpit-test-contract-fixture "anchors/02_submission.json" project))))))

(provide 'session-cockpit-contracts-test)
;;; session-cockpit-contracts-test.el ends here
