;;; ox-quip.el -- Publish from org-mode to Quip.

;;; Commentary:
;; Publisher from org-mode to Quip.  (Export as markdown, push as a new
;; thread or amend to existing quip thread.)

;;; Code:
(require 'cl-extra)
(require 'ox-md)
(require 'whitespace)
(require 'quip)


(defun org-quip--cleanup-quip-html ()
  "Remove things that convert badly."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "<div data-section-style='[0-9]+'>" nil t)
      (replace-match "")
      (if (re-search-forward "</div>" nil t) (replace-match "")))

    (goto-char (point-min))
    (while (re-search-forward "<span id='[A-Za-z0-9]+'>" nil t)
      (replace-match "")
      (if (re-search-forward "</span>" nil t) (replace-match "")))

    (goto-char (point-min))
    (while (re-search-forward "<li id='[A-Za-z0-9]+'" nil t)
      (replace-match "<li"))

    ))

(defun org-quip--cleanup-org-buffer ()
  "Run a whole bunch of cleanup on the pandoc-generated org buffer."
  (save-excursion
    ;; Remove the dumb non-breaking spaces.
    (goto-char (point-min))
    (while (re-search-forward (char-to-string 160) nil t)
      (replace-match " "))

    ;; Remove these things that pandoc puts in.
    (goto-char (point-min))
    (while (re-search-forward "\\\\" nil t)
      (replace-match ""))

    ;; Remove zero-width spaces. (Why are they even there?)
    (goto-char (point-min))
    (while (re-search-forward (char-to-string #x200B) nil t)
      (replace-match ""))

    (when org-odd-levels-only
      ;; Move all the sub-headlines one over (because the normal demote
      ;; commands move by two stars not just one). This code is taken from
      ;; org-convert-to-odd-levels, with the interactive yes/no removed.
      ;;
      (let ((outline-level 'org-outline-level)
            (org-odd-levels-only nil) n)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward "^\\*\\*+ " nil t)
            (setq n (- (length (match-string 0)) 2))
            (while (>= (setq n (1- n)) 0)
              (org-demote))
            (end-of-line 1)))))

    ;; Indent before whitespace cleanup so that blank lines are still blank.
    ;; (If you indent after whitespace cleanup, indentation adds whitespace
    ;; to align with the paragraph level.)
    ;;
    (indent-region (point-min) (point-max))

    ;; Indent lists to match their enclosing headlines. These don't get
    ;; auto-indented by the following indentation code, but must be done
    ;; after the indentation pass to align with preceeding paragraphs.
    (goto-char (point-min))
    (while (re-search-forward "^[-+] " nil t)
      (move-beginning-of-line nil)
      (while (<= (1+ (current-indentation)) (org-outline-level))
          (org-indent-item-tree)))

    ;; (Indent again; to get all the leftover paragraphs.)
    (indent-region (point-min) (point-max))
    (whitespace-cleanup)

    ;; Fill all the paragraphs, but only the paragraphs. (Filling code blocks
    ;; and tables does bizarre things, and filling headlines breaks them.)
    (org-element-map (org-element-parse-buffer) 'paragraph
      (lambda (paragraph)
        (goto-char (org-element-property :begin paragraph))
        (fill-paragraph nil)
        ))

    ;; Remove consecutive white lines.
    (goto-char (point-min))
    (while (re-search-forward "\\(^\\s-*$\\)\n" nil t)
      (replace-match "\n")
      (forward-char 1))

    ;; Tidy up all the property drawers.
    (org-element-map (org-element-parse-buffer) 'property-drawer
      (lambda (drawer)
        (goto-char (org-element-property :begin drawer))
        (org-cycle)
        ))
    ))

(defun org-quip--get-org-buffer-from-quip (thread-id buffer)
  "Fetch the quip thread with THREAD-ID and convert it to org markup in BUFFER.

We do this by (a) downloading the thread from quip, (b) cleaning
up the HTML in the buffer (a little bit), (c) running the HTML
through pandoc to convert it into acceptable org, and (d) running
a cleanup pass over the generated org markup.

The end result is fairly clean 'org-mode' markup."
  (let ((quip-html (alist-get 'html (quip-get-thread thread-id))))
    (with-current-buffer buffer
      (erase-buffer)
      (with-temp-buffer
        (insert quip-html)
        (org-quip--cleanup-quip-html)
        (call-process-region (point-min) (point-max)
                             "pandoc" nil buffer nil
                             "-f" "html"
                             "-t" "org"
                             "--normalize"
                             "--smart"
                             ))
      (goto-char (point-min))
      (org-mode)
      (org-show-subtree)
      (org-quip--cleanup-org-buffer)

      ;; HAX
      (goto-char (point-min))
      (org-entry-put nil "QUIP_ID" thread-id)

      (goto-char (point-min))
      (insert "#+options: num:nil\n\n")


      )))

(defun org-quip--get-thread-identifier ()
  "Get the Quip thread identifier from the doc in the current buffer, if any."
  (org-entry-get nil "QUIP_ID" t))

(defun org-quip--put-thread-identifier (identifier)
  "Put the Quip thread identifier in IDENTIFIER into the doc."
  (save-excursion
    (while (org-up-heading-safe))
    (org-entry-put nil "QUIP_ID" identifier)))

(defun org-quip--publish-quip (content)
  "Publish CONTENT as a new Quip document.  Return the ID of the new document."
  (let ((response (quip-new-document content)))
    (cdr (assoc 'id (cdr (assoc 'thread response))))))

(defun org-quip-publish-to-quip ()
  "Publish the current buffer to Quip."
  (interactive)
  (let
      ((quip-id (org-quip--get-thread-identifier))
       (content (org-export-as 'md)))
    (if quip-id
        (org-quip-update-quip quip-id content)
      (let ((new-quip-id (org-quip--publish-quip content)))
        (org-quip--put-thread-identifier new-quip-id)))))

(defun org-quip-refresh ()
  "Refresh the current document from quip.

This replaces what's in the buffer so I hope you're OK with that."
  (interactive)
  (let ((thread-id (org-quip--get-thread-identifier)))
    (unless thread-id (error "This org doc hasn't been published to quip"))
    (org-quip--get-org-buffer-from-quip thread-id (current-buffer))))

(provide 'ox-quip)
;;; ox-quip.el ends here
