;;; rundeck.el --- Render Rundeck Metrics in Org Mode -*- lexical-binding: t; coding: utf-8 -*-

;; Copyright (C) 2020 Philip Beadling

;; Author: Philip Beadling <phil@beadling.co.uk>
;; Maintainer: Philip Beadling <phil@beadling.co.uk>
;; Created: 15 Nov 2020
;; Modified: 15 Nov 2020
;; Version: 1.0
;; Package-Requires: ((emacs "26.3"))
;; Keywords: data rundeck
;; URL: https://github.com/falloutphil/rundeck.el
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;; Set Request Curl Options to contain --insecure to ignore SSL cert issues


;;; Code:
(require 'request)
(require 'json)
(require 'cl)
(require 'auth-source)

(setq host "rundeck:4443")
(setq addr (concat "https://" host))

(defun tick-cross (val)
  (if (string= val "t") "✔" "✖"))

(defun convert-job-to-row (job-alist)
  "Convert alist to org table row."
  (message "row")
  (let-alist job-alist
    (insert (format "| %s | [[%s][%s]] | %s | %s |\n" .group .href .name (tick-cross .enabled) (tick-cross .scheduled)))))

;; http://ergoemacs.org/emacs/elisp_parse_org_mode.html
(defun convert-job-to-item (job-alist)
  "Convert alist to an org todo list item."
  (message "item")
  (let-alist job-alist
    (insert (format (concat
                     "** [[%s][%s]]\n"
                     ":PROPERTIES:\n"
                     ":Enabled: %s\n"
                     ":Scheduled: %s\n"
                     ":END:\n")
                    .href .name .enabled .scheduled))))


(defun format-table ()
  (previous-line)
  (org-table-align)
  (goto-char (point-min))
  (forward-line 2)
  (org-table-next-field)
  (org-table-next-field)
  (org-table-sort-lines t ?a)
  (org-table-previous-field)
  (org-table-sort-lines t ?a))

(switch-to-buffer "Rundeck")
(org-mode)
;;(insert "| Group | Name | Enabled | Scheduled |\n")
;;(insert "|-\n")
(insert "* Parent Item\n")

(let ((auth (nth 0 (auth-source-search :host host
                                       :requires '(user secret)))))
  (request
    (concat addr "/j_security_check")
    :type "POST"
    :data `(("j_username" . ,(plist-get auth :user))
            ("j_password" . ,(funcall (plist-get auth :secret))))
    :sync t
    :timeout 5
    :complete (function*
               (lambda (&key response &allow-other-keys)
                 (if (string= (request-response-url response) (concat addr "/menu/home"))
                     (message "Rundeck Auth OK")
                     (message "Rundeck Auth FAILED"))
                 (message "Done: %s / %s"
                          (request-response-status-code response)
                          (request-response-url response))))))

(request
  (concat addr "/api/25/project/SIMM/jobs")
  :headers '(("Accept" . "application/json"))
  :parser 'json-read
  :success (function*
            (lambda (&key data &allow-other-keys)
              ;(mapc #'convert-job-to-row data)
              (mapc #'convert-job-to-item data))))
              ;(format-table))))

(message "Rundeck Complete")
(provide 'rundeck)
;;; rundeck.el ends here
