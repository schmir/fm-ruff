;;; fm-ruff-tests.el --- Tests for fm-ruff  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for the fm-ruff flymake backend.

;;; Code:

(require 'ert)
(require 'flymake)
(require 'fm-ruff)

(defmacro fm-ruff-test--with-buffer (&rest body)
  "Execute BODY in a temp buffer, cleaning up ruff processes afterward."
  (declare (indent 0) (debug t))
  `(let ((buf (generate-new-buffer " *fm-ruff-test*"))
         (fm-ruff-test--procs nil))
     (cl-letf* ((orig-make-process (symbol-function 'make-process))
                ((symbol-function 'make-process)
                 (lambda (&rest args)
                   (let ((proc (apply orig-make-process args)))
                     (push proc fm-ruff-test--procs)
                     proc))))
       (unwind-protect
           (with-current-buffer buf
             ,@body)
         ;; Replace sentinels with no-ops before killing so the
         ;; original sentinels don't try to parse partial output or
         ;; access dead buffers.
         (dolist (proc fm-ruff-test--procs)
           (set-process-sentinel proc #'ignore)
           (when (process-live-p proc)
             (kill-process proc)))
         ;; Clean up process buffers.
         (dolist (proc fm-ruff-test--procs)
           (when (buffer-live-p (process-buffer proc))
             (kill-buffer (process-buffer proc))))
         (when (buffer-live-p buf)
           (kill-buffer buf))))))

(defun fm-ruff-test--wait-for-process ()
  "Wait for `fm-ruff--flymake-proc' to finish."
  (let ((deadline (+ (float-time) 10)))
    (while (and (process-live-p fm-ruff--flymake-proc)
                (< (float-time) deadline))
      (accept-process-output fm-ruff--flymake-proc 0.1)))
  ;; Let the sentinel run.
  (accept-process-output nil 0.5))

(ert-deftest fm-ruff-test-setup-adds-hook ()
  "Test that `fm-ruff-setup' adds `fm-ruff-flymake' to flymake diagnostic functions."
  (with-temp-buffer
    (python-mode)
    (let ((flymake-diagnostic-functions nil))
      (fm-ruff-setup)
      (should (memq #'fm-ruff-flymake flymake-diagnostic-functions)))))

(ert-deftest fm-ruff-test-setup-skips-non-python ()
  "Test that `fm-ruff-setup' does nothing outside python-mode."
  (with-temp-buffer
    (fundamental-mode)
    (let ((flymake-diagnostic-functions nil))
      (fm-ruff-setup)
      (should-not (memq #'fm-ruff-flymake flymake-diagnostic-functions)))))

(ert-deftest fm-ruff-test-setup-is-buffer-local ()
  "Test that `fm-ruff-setup' only affects the current buffer."
  (let ((buf1 (generate-new-buffer " *test-buf1*"))
        (buf2 (generate-new-buffer " *test-buf2*")))
    (unwind-protect
        (progn
          (with-current-buffer buf1
            (python-mode)
            (let ((flymake-diagnostic-functions nil))
              (fm-ruff-setup)
              (should (memq #'fm-ruff-flymake
                            (buffer-local-value 'flymake-diagnostic-functions buf1)))))
          (with-current-buffer buf2
            (should-not (memq #'fm-ruff-flymake
                              (default-value 'flymake-diagnostic-functions)))))
      (kill-buffer buf1)
      (kill-buffer buf2))))

(ert-deftest fm-ruff-test-flymake-proc-is-buffer-local ()
  "Test that `fm-ruff--flymake-proc' is buffer-local."
  (with-temp-buffer
    (should (local-variable-if-set-p 'fm-ruff--flymake-proc))))

(ert-deftest fm-ruff-test-error-when-ruff-missing ()
  "Test that an error is raised when ruff executable is not found."
  (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) nil)))
    (should-error (fm-ruff-flymake #'ignore)
                  :type 'error)))

(ert-deftest fm-ruff-test-error-when-json-unavailable ()
  "Test that an error is raised when JSON support is missing."
  (cl-letf (((symbol-function 'executable-find) (lambda (_cmd) t))
            ((symbol-function 'json-available-p) (lambda () nil)))
    (should-error (fm-ruff-flymake #'ignore)
                  :type 'error)))

(ert-deftest fm-ruff-test-flymake-starts-process ()
  "Test that `fm-ruff-flymake' starts a ruff process."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (fm-ruff-test--with-buffer
    (insert "import os\n")
    (fm-ruff-flymake #'ignore)
    (should (processp fm-ruff--flymake-proc))
    (should (string= "fm-ruff" (process-name fm-ruff--flymake-proc)))))

(ert-deftest fm-ruff-test-flymake-kills-old-process ()
  "Test that starting a new check kills the previous process."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (fm-ruff-test--with-buffer
    (insert "import os\n")
    (fm-ruff-flymake #'ignore)
    (let ((first-proc fm-ruff--flymake-proc))
      (fm-ruff-flymake #'ignore)
      (should-not (eq first-proc fm-ruff--flymake-proc)))))

(ert-deftest fm-ruff-test-flymake-uses-stdin-filename ()
  "Test that the process command includes --stdin-filename."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (fm-ruff-test--with-buffer
    (insert "x = 1\n")
    (fm-ruff-flymake #'ignore)
    (let ((cmd (process-command fm-ruff--flymake-proc)))
      (should (cl-some (lambda (arg) (string-prefix-p "--stdin-filename=" arg)) cmd))
      (should (member "-" cmd)))))

(ert-deftest fm-ruff-test-flymake-reports-diagnostics ()
  "Test that ruff diagnostics are reported via the report function."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (let ((reported nil))
    (fm-ruff-test--with-buffer
      (insert "import os\n")
      (fm-ruff-flymake (lambda (diags &rest _) (setq reported diags)))
      (fm-ruff-test--wait-for-process)
      (should (consp reported))
      (should (cl-every (lambda (d) (cl-typep d 'flymake--diag)) reported))
      ;; "import os" without usage should trigger F401.
      (let ((msg (flymake-diagnostic-text (car reported))))
        (should (string-match-p "ruff:" msg))
        (should (string-match-p "F401" msg))))))

(ert-deftest fm-ruff-test-flymake-clean-file-no-diagnostics ()
  "Test that a clean Python file produces no diagnostics."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (let ((reported nil)
        (called nil))
    (fm-ruff-test--with-buffer
      (insert "x = 1\n")
      (fm-ruff-flymake (lambda (diags &rest _)
                          (setq reported diags)
                          (setq called t)))
      (fm-ruff-test--wait-for-process)
      (should called)
      (should (null reported)))))

(ert-deftest fm-ruff-test-flymake-output-format-json ()
  "Test that the process is invoked with --output-format=json."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (fm-ruff-test--with-buffer
    (insert "x = 1\n")
    (fm-ruff-flymake #'ignore)
    (let ((cmd (process-command fm-ruff--flymake-proc)))
      (should (member "--output-format=json" cmd))
      (should (member "--quiet" cmd)))))

(ert-deftest fm-ruff-test-flymake-narrowed-buffer ()
  "Test that flymake checks the full buffer even when narrowed."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (let ((reported nil))
    (fm-ruff-test--with-buffer
      (insert "import os\nimport sys\nx = 1\n")
      (narrow-to-region 1 10)
      (fm-ruff-flymake (lambda (diags &rest _) (setq reported diags)))
      (fm-ruff-test--wait-for-process)
      ;; Should find warnings for both unused imports.
      (should (consp reported))
      (should (>= (length reported) 2)))))

(ert-deftest fm-ruff-test-flymake-diagnostic-severity ()
  "Test that diagnostics are reported with :error severity."
  (skip-unless (executable-find "ruff"))
  (skip-unless (json-available-p))
  (let ((reported nil))
    (fm-ruff-test--with-buffer
      (insert "import os\n")
      (fm-ruff-flymake (lambda (diags &rest _) (setq reported diags)))
      (fm-ruff-test--wait-for-process)
      (should (consp reported))
      (should (eq :error (flymake-diagnostic-type (car reported)))))))

(ert-deftest fm-ruff-test-provide ()
  "Test that the package provides the fm-ruff feature."
  (should (featurep 'fm-ruff)))

;;; fm-ruff-tests.el ends here
