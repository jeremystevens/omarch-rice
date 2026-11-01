;;; $DOOMDIR/packages.el -*- lexical-binding: t; no-byte-compile: t -*-

;; To install a package:
;;
;;   1. Declare them here in a `package!' statement,
;;   2. Run 'doom sync' in the shell,
;;   3. Restart Emacs.
;;
;; Use 'C-h f package\!' to look up documentation for the `package!' macro.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;; (package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;; (package! another-package
;;   :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;; (package! this-package
;;   :recipe (:host github :repo "username/repo"
;;            :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;; (package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;; (package! builtin-package :recipe (:nonrecursive t))
;; (package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;; (package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;; (package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;; (unpin! pinned-package)
;; ...or multiple packages
;; (unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;; (unpin! t)

;; ============================================
;; DEVELOPMENT PACKAGES
;; Python, React, Node.js, Pygame, SQLite
;; ============================================

;; Better code completion and documentation
(package! cape)
(package! kind-icon)
(package! eldoc-box)

;; Show function/class location
(package! breadcrumb)

;; Visual indentation guides
(package! highlight-indent-guides)

;; Highlight TODO, FIXME, BUG comments
(package! hl-todo)

;; Better project navigation
(package! treemacs)

;; Code structure / symbol outline
(package! imenu-list)

;; Python virtual environments
(package! pyvenv)

;; Python test integration
(package! python-pytest)

;; Python documentation lookup
(package! devdocs)

;; REST API testing inside Emacs
(package! restclient)

;; HTTP request files
(package! ob-restclient)

;; SQLite database browser
(package! sqlite-mode)

;; YAML configuration editing
(package! yaml-mode)

;; Dockerfile editing
(package! dockerfile-mode)

;; GitHub Copilot integration (optional)
;; Requires GitHub Copilot access
 (package! copilot
   :recipe (:host github :repo "copilot-emacs/copilot.el"
            :files ("*.el" "dist")))

