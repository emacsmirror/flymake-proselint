;;; flymake-proselint.el --- Flymake backend for proselint -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Manuel Uberti <manuel.uberti@inventati.org>
;;
;; Author: Manuel Uberti <manuel.uberti@inventati.org>
;; Version: 1.0.0
;; Package-Requires: ((emacs "26.1") (flymake-quickdef "1.0.0"))
;; URL: https://github.com/manuel-uberti/flymake-proselint

;;; Commentary:

;; This package add support for proselint (http://proselint.com/) in Flymake.

;; Once installed, the backend can be enabled with:
;; (add-hook 'markdown-mode-hook #'flymake-proselint-setup)

;;; Code:

(require 'flymake)
(require 'flymake-quickdef)

(flymake-quickdef-backend
  flymake-proselint-backend
  :pre-let ((proselint-exec (executable-find "proselint")))
  :pre-check (unless proselint-exec (error "proselint not found on PATH"))
  :write-type 'pipe
  :proc-form (list proselint-exec "-")
  :search-regexp "^.+:\\([[:digit:]]+\\):\\([[:digit:]]+\\): \\(.+\\)$"
  :prep-diagnostic (let* ((lnum (string-to-number (match-string 1)))
                          (lcol (string-to-number (match-string 2)))
                          (msg (match-string 3))
                          (pos (flymake-diag-region fmqd-source lnum lcol))
                          (beg (car pos))
                          (end (cdr pos)))
                     (list fmqd-source beg end :warning msg)))

;;;###autoload
(defun flymake-proselint-setup ()
  "Enable Flymake backend proselint."
  (add-hook 'flymake-diagnostic-functions #'flymake-proselint-backend nil t))

(provide 'flymake-proselint)

;;; flymake-proselint.el ends here
