;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

((org-mode . ((eval . (setq org-hugo-base-dir (project-root (project-current))))))
 ("content-org/" . ((org-mode . ((eval org-hugo-auto-export-mode))))))
