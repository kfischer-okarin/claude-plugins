;;; run-tests.el --- Runs the tests inside the test daemon -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)

(let ((test-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path test-dir)
  (add-to-list 'load-path (expand-file-name ".." test-dir)))

;; magit-section and what it needs, as the user's Emacs installs them.
(dolist (package '("magit-section" "compat" "cond-let" "llama"))
  (add-to-list 'load-path (expand-file-name package (locate-user-emacs-file "elpaca/builds/"))))

(defun session-cockpit-run-tests (results-file)
  "Run every session-cockpit test and write a report to RESULTS-FILE.
Each test gets a line, and every failure starts with FAILED."
  (require 'session-cockpit-test)
  (require 'session-cockpit-anchors-test)
  (require 'session-cockpit-contracts-test)
  (let ((stats (ert-run-tests "^session-cockpit-test-" #'ignore)))
    (with-temp-file results-file
      (seq-doseq (test (ert--stats-tests stats))
        (let ((result (ert-test-most-recent-result test)))
          (insert (format "%s %s\n"
                          (cond ((ert-test-passed-p result) "passed")
                                ((ert-test-skipped-p result) "SKIPPED")
                                (t "FAILED"))
                          (ert-test-name test)))
          (when (ert-test-result-with-condition-p result)
            (insert (format "  %S\n" (ert-test-result-with-condition-condition result))))))
      (insert (format "%d tests, %d unexpected\n"
                      (ert-stats-total stats)
                      (ert-stats-completed-unexpected stats))))))

;;; run-tests.el ends here
