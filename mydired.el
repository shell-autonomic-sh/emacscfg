;;; mydired.el --- 

;; dired
;; Another way of achieving this:

;; we want dired not not make always a new buffer if visiting a directory
;; but using only one dired buffer for all directories.
(defadvice dired-find-file (around dired-subst-directory activate)
  "Replace current buffer if file is a directory."
  (interactive)
  (let ((orig (current-buffer))
	(filename (dired-get-filename)))
    ad-do-it
    (when (and (file-directory-p filename)
	       (not (eq (current-buffer) orig)))
      (kill-buffer orig))))

(defun dired-up-directory (&optional other-window)
  "Run Dired on parent directory of current directory."
  (interactive "P")
  (let* ((dir (dired-current-directory))
	 (orig (current-buffer))
	 (up (file-name-directory (directory-file-name dir))))
    (or (dired-goto-file (directory-file-name dir))
	;; Only try dired-goto-subdir if buffer has more than one dir.
	(and (cdr dired-subdir-alist) (dired-goto-subdir up))
	(progn
	  (kill-buffer orig)
	  (dired up)
	  (dired-goto-file dir)))))

(defun dired-copy-dir-as-kill (&optional arg)
  (interactive)
  (x-set-selection 'PRIMARY (dired-current-directory))
  (x-set-selection 'CLIPBOARD (dired-current-directory)))

(defun dired-open-file (with-prog &optional arg)
  (interactive
   (list (read-shell-command
	  "command: "
	  (cond ((memq system-type '(windows-nt cygwin)) "start")
		(t "xdg-open")))))
  (apply 'start-process "dired-open" nil
	 (append (split-string with-prog) (list (dired-get-filename)))))

(defmacro dired-common-form (funcname do-function)
  `(defun ,funcname (source-path &optional arg)
     (interactive (list (read-file-name "filepath: ")))
     (,do-function source-path (file-name-nondirectory source-path))
     (revert-buffer)))

(defmacro dired-common-to-other (funcname do-function)
  `(defun ,funcname (&optional arg)
     (interactive)
     (let ((marked (dired-get-marked-files nil arg))
	   (other (next-window (selected-window)))
	   (this (selected-window)))
       (select-window other)
       (let ((target (dired-current-directory)))
	 (mapcar
	  (lambda (source-path) (,do-function source-path target))
	  marked))
       (revert-buffer)
       (select-window this))))

(defmacro dired-common-rename-marked (funcname rename-func)
  `(defun ,funcname (&optional arg)
     (interactive)
     (mapcar
      (lambda (filepath)
	(let* ((filename (file-name-nondirectory filepath))
	       (filedir (file-name-directory filepath))
	       (newname (,rename-func filename)))
	  (if (and newname (not (string= newname filename)))
	      (rename-file filepath (concat filedir newname)))))
      (dired-get-marked-files nil arg))
     (revert-buffer)))

(defun lterm-string (str)
  (replace-regexp-in-string "^[[:space:]]*" "" str))

(defvar *tagregexp* "(.*?)\\|\\[.*?\\]")

(defun detag-filename (filename)
  (if (string-match *tagregexp* filename)
      (lterm-string
       (replace-regexp-in-string *tagregexp* "" filename))
    nil))

(defun untag-filename (filename)
  (if (string-match *tagregexp* filename)
      (replace-regexp-in-string
       *tagregexp*
       (if (= (match-beginning 0) 0)
      	   (substring (match-string 0 filename) 1 -1)
      	 (concat "_" (substring (match-string 0 filename) 1 -1)))
       filename)
    nil))

(define-key dired-mode-map "W" 'dired-copy-dir-as-kill)
(define-key dired-mode-map "b" 'dired-open-file)
(define-key dired-mode-map "c"
  (dired-common-to-other dired-copy-to-other copy-file))
(define-key dired-mode-map "r"
  (dired-common-to-other dired-rename-to-other rename-file))
(define-key dired-mode-map "%c"
  (dired-common-form dired-copy-from copy-file))
(define-key dired-mode-map "%r"
  (dired-common-form dired-rename-from rename-file))
(define-key dired-mode-map "\\d"
  (dired-common-rename-marked dired-detag-filename detag-filename))
(define-key dired-mode-map "\\t"
  (dired-common-rename-marked dired-lterm-string lterm-string))
(define-key dired-mode-map "\\u"
  (dired-common-rename-marked dired-untag-filename untag-filename))

;; magit, work for git
(ignore-errors
  (require 'magit)
  (define-key dired-mode-map "\\f" 'magit-fetch)
  (define-key dired-mode-map "\\l" 'magit-log)
  (define-key dired-mode-map "\\p" 'magit-pull)
  (define-key dired-mode-map "\\P" 'magit-push)
  (define-key dired-mode-map "\\s" 'magit-status))

;;; mydired.el ends here