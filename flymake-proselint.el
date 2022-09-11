;;; flymake-proselint.el --- Flymake backend for proselint -*- lexical-binding: t; -*-

;; Copyright (C) 2021-2022  Free Software Foundation, Inc.
;;
;; Author: Manuel Uberti <manuel.uberti@inventati.org>
;; Maintainer: Manuel Uberti <~manuel-uberti/flymake-proselint@lists.sr.ht>
;; Version: 0.2.3
;; Keywords: convenience
;; Package-Requires: ((emacs "26.1"))
;; URL: https://git.sr.ht/~manuel-uberti/flycheck-proselint

;; flymake-proselint is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 3, or (at your option) any later version.
;;
;; flymake-proselint is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License
;; along with flymake-proselint.  If not, see http://www.gnu.org/licenses.

;;; Commentary:

;; This package adds support for proselint (http://proselint.com/) in Flymake.

;; Once installed, the backend can be enabled with:
;; (add-hook 'markdown-mode-hook #'flymake-proselint-setup)

;;; Code:

(eval-when-compile
  (require 'subr-x)
  (require 'pcase))
(require 'flymake)

(defgroup flymake-proselint ()
  "Flymake backend for proselint."
  :prefix "flymake-proselint-"
  :group 'flymake)

(defcustom flymake-proselint-message-format
  "%m%r"
  "A format string to generate diagnostic messages.
The following %-sequences are replaced:

  %m - the message text
  %r - replacement suggestions
  %c - the error code"
  :type 'string)

(defun flymake-proselint-sentinel-1 (source data)
  "Handle a successfully parsed DATA from SOURCE.
DATA is a list of error diagnostics that are converted into
Flymake diagnostic objects."
  (let (diags)
    (dolist (err (plist-get data :errors))
      (push (flymake-make-diagnostic
             source
             (plist-get err :start)
             (plist-get err :end)
             (pcase (plist-get err :severity)
               ("warning"	:warning)
               ("suggestion"	:note)
               (_		:error))
             (format-spec
              flymake-proselint-message-format
              `((?m . ,(plist-get err :message))
                (?c . ,(plist-get err :check))
                (?r . ,(let ((replacements (plist-get err :replacements)))
                         (cond
                          ((or (eq replacements :null) (null replacements))
                           ;; There are no replacements.
                           "")
                          ((stringp replacements)
                           (concat " (Replacement: " replacements ")"))
                          ((listp replacements)
                           (concat " (Replacements: "
                                   (mapconcat
                                    (lambda (r)
                                      (plist-get r :unique))
                                    replacements ", ")
                                   ")"))))))))
            diags))
    diags))

(defvar-local flymake-proselint--flymake-proc nil)

(defun flymake-proselint-sentinel (proc _event)
  "Sentinel on PROC for handling Proselint response.
A successfully parsed message is passed onto the function
`flymake-proselint-sentinel-1' for further handling."
  (pcase (process-status proc)
    ('exit
     (let ((report-fn (process-get proc 'report-fn))
           (source (process-get proc 'source)))
       (unwind-protect
           (with-current-buffer (process-buffer proc)
             (goto-char (point-min))
             (cond
              ((with-current-buffer source
                 (not (eq proc flymake-proselint--flymake-proc)))
               (flymake-log :warning "Canceling obsolete check %s" proc))
              ((= (point-max) (point-min))
               (flymake-log :debug "Empty response"))
              ((condition-case err
                   (let ((response (json-parse-buffer :object-type 'plist
                                                      :array-type 'list)))
                     (if (string= (plist-get response :status) "success")
                         (thread-last
                           (plist-get response :data)
                           (flymake-proselint-sentinel-1 source)
                           (funcall report-fn))
                       (flymake-log :error "Check failed")))
                 (json-parse-error
                  (flymake-log :error "Invalid response: %S" err))))))
         (with-current-buffer source
           (setq flymake-proselint--flymake-proc nil))
         (kill-buffer (process-buffer proc)))))
    ('signal (kill-buffer (process-buffer proc)))))

(defun flymake-proselint-backend (report-fn &rest _args)
  "Flymake backend for Proselint.
REPORT-FN is the flymake reporter function.  See the Info
node (flymake) Backend functions for more details."
  (unless (executable-find "proselint")
    (user-error "Executable proselint not found on PATH"))

  (when (process-live-p flymake-proselint--flymake-proc)
    (kill-process flymake-proselint--flymake-proc))

  (let ((proc (make-process
               :name "proselint-flymake" :noquery t :connection-type 'pipe
               :buffer (generate-new-buffer " *proselint-flymake*")
               :command '("proselint" "--json" "-")
               :sentinel #'flymake-proselint-sentinel)))
    (process-put proc 'source (current-buffer))
    (process-put proc 'report-fn report-fn)
    (setq flymake-proselint--flymake-proc proc)
    (save-restriction
      (widen)
      (process-send-region proc (point-min) (point-max))
      (process-send-eof proc))))

;;;###autoload
(defun flymake-proselint-setup ()
  "Enable Flymake backend proselint."
  (add-hook 'flymake-diagnostic-functions #'flymake-proselint-backend nil t))

(provide 'flymake-proselint)

;;; flymake-proselint.el ends here
