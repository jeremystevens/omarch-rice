;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;;; Python ------------------------------------------------------------------
;; Language server: basedpyright (completions, hover docs, go-to-definition,
;; type checking) through eglot. Installed with `uv tool install basedpyright'.
;; Formatting and lint: ruff (from mise). Virtual envs: uv projects' .venv is
;; picked up by the +uv flag; basedpyright also finds .venv on its own.

(after! python
  (set-eglot-client! '(python-mode python-ts-mode) '("basedpyright-langserver" "--stdio"))
  (set-formatter! 'ruff '("ruff" "format" "--stdin-filename" filepath "-") :modes '(python-mode python-ts-mode))
  (setq python-indent-guess-indent-offset-verbose nil))

;; basedpyright settings: "standard" checking is pyright's default strictness
;; (basedpyright's own default, "recommended", is much noisier).
(setq-default eglot-workspace-configuration
              '(:basedpyright (:typeCheckingMode "standard")
                :basedpyright.analysis (:autoImportCompletions t
                                        :diagnosticMode "openFilesOnly"
                                        :inlayHints (:callArgumentNames nil))))

;; ruff's lint warnings alongside basedpyright's diagnostics.
(after! flycheck-eglot
  (flycheck-add-next-checker 'eglot-check '(warning . python-ruff)))

;; Eglot: stay quiet and fast.
(after! eglot
  (setq eglot-events-buffer-config '(:size 0 :format full) ; no per-message logging
        eglot-autoshutdown t                               ; stop the server with its last buffer
        eglot-sync-connect nil))

;; Completion pops up after 2 characters, quickly.
(after! corfu
  (setq corfu-auto-delay 0.15
        corfu-auto-prefix 2))


;;; Chromebook keyboard ---------------------------------------------------------
;; This keyboard has no Delete, Home, End, PgUp/PgDn, Insert, F11 or F12, and
;; the top row is taken by the desktop (Search + a top-row key sends the real
;; F1-F10). Doom already covers most of it: C-a / C-e are Home / End in insert
;; mode, C-u / C-d / C-b / C-f page in normal mode, C-h (SPC h) is help, the
;; top-row back/forward keys switch buffers. Two gaps are filled here:

;; Delete forward in insert mode (evil's C-d "dedent" is `<<' in normal mode).
(map! :i "C-d" #'delete-char)

;; The ⟳ key: reload the file from disk (asks first if the buffer has changes).
(map! "<XF86Reload>" #'revert-buffer-quick)
