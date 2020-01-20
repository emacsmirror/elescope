;;; elescope --- Clone remote projects in a flash -*- lexical-binding: t -*-

;; Copyright (C) 2020 Stéphane Maniaci

;; Author: Stéphane Maniaci <stephane dot maniaci at gmail.com>
;; URL: https://github.com/freesteph/elescope
;; Package-Version: 20200117.410
;; Version: 0.1

;; This file is NOT part of GNU Emacs.

;; elescope.el is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; elescope.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with elescope.el.  If not, see
;; <http://www.gnu.org/licenses/>.


;;; Commentary:
;;; Clone remote projects in a flash.

;;; Code:
(require 'request)
(require 'ivy)

(defcustom elescope-root-folder nil
  "Directory to clone projects into."
  :group 'elescope
  :type 'directory)

(defcustom elescope-clone-depth 1
  "Depth argument to be passed to git clone.

Defaults to 1 which makes all clones shallow clones."
  :group 'eslescope
  :type 'integer)

(defvar elescope-forges
  '(github gitlab)
  "Forges understood by elescope.")

(defvar elescope--debounce-timer nil)

(defun elescope--parse-gh (data)
  "Parse the DATA returned by GitHub and maps on the full name attribute."
  (mapcar
   (lambda (i) (alist-get 'full_name i))
   (seq-take (alist-get 'items data) 10)))

(defun elescope--call-gh (name)
  "Search for GitHub repositories matching NAME."
  (request
    "https://api.github.com/search/repositories"
    :params (list (cons "q" name))
    :parser 'json-read
    :success (cl-function
              (lambda (&key data &allow-other-keys)
                (let ((results (elescope--parse-gh data)))
                  (ivy-update-candidates results))))))

(defun elescope--search (str)
  "Handle the minibuffer STR query and search the relevant forge."
  (or
   (ivy-more-chars)
   (progn
     (and (timerp elescope--debounce-timer)
          (cancel-timer elescope--debounce-timer))
     (setf elescope--debounce-timer
           (run-at-time "0.7 sec" nil #'elescope--call-gh str))
     (list "" (format "Looking for repositories matching %s..." str)))
   0))

(defun elescope--clone-gh (path)
  "Clone the GitHub project identified by PATH."
  (let* ((url (format "https://github.com/%s" path))
         (name (cadr (split-string path "/")))
         (destination (expand-file-name name elescope-root-folder))
         (command (format
                   "git clone --depth=%s %s %s"
                   elescope-clone-depth
                   url
                   destination)))
    (if (eql 0 (shell-command command))
        (find-file destination)
      (user-error "Something went wrong whilst cloning the project"))))

(defun elescope--ensure-root ()
  "Make sure there is a root to checkout into."
  (unless (and
           elescope-root-folder
           (file-directory-p elescope-root-folder))
    (user-error "You need to set the 'elescope-root-folder' variable before
    checking out any project")))

(defun elescope-checkout (select-forges)
  "Prompt a repository name to search for.

If the function is called with the prefix SELECT-FORGES argument,
prompt a forge to search from (defaults to GitHub)."
  (interactive "P")
  (elescope--ensure-root)
  (if select-forges
      (completing-read "Forge: " elescope-forges)
    (let ((forge 'github))
      (ivy-read "Project: " #'elescope--search
                :dynamic-collection t
                :action #'elescope--clone-gh
                :caller 'elescope-checkout))))


(provide 'elescope)
;;; elescope.el ends here
