;;; init.el -*- lexical-binding: t; -*-

;; Copyright 2024 Google LLC
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

;; Extra initialization code for nix-doom-emacs-unstraightened.
;;
;; Loaded from the profile init file.

(defadvice! nix-doom-skip-core-packages (&rest _)
  "HACK: don't install straight and core packages.

`doom-initialize-core-packages' would no-op out if
`straight-recipe-repositories' is set, but we do not want to set
it. Just skip it entirely."
  :override #'doom-initialize-core-packages
  (doom-log "nix-doom-emacs-unstraightened overriding core package init")
  ;; doom-initialize-core-packages normally registers recipes, which loads the
  ;; build cache by side effect, which leaves straight--build-cache available
  ;; afterwards. Doom assumes this cache is available, so force a load here.
  (require 'straight)  ;; straight-load-build-cache is not autoloaded.
  (straight--load-build-cache))

(after! doom-straight
  (setq straight-base-dir
        (file-name-directory (directory-file-name doom-user-dir))))

;; Doom adds a minor mode that makes flycheck-mode's emacs subprocess initialize
;; Doom. Extend this to run the profile loader first: what Doom does here is
;; similar enough to its normal startup it needs the same fixes.
;;
;; Note this assumes DOOMPROFILELOADFILE and DOOMPROFILE leak into child
;; processes (the loader does nothing if DOOMPROFILE is unset).
(setq-hook! +emacs-lisp--flycheck-non-package-mode
  flycheck-emacs-lisp-check-form
  (prin1-to-string `(progn
                      (load (getenv "DOOMPROFILELOADFILE") nil 'nomessage)
                      ,(read flycheck-emacs-lisp-check-form))))

;; The restart-emacs package redefines the restart-emacs function provided by
;; Emacs (which takes no arguments) with a replacement that takes an "args"
;; argument. We need to define our advice after the correct function has been
;; loaded: advice-add would normally handle autoloads but does not handle this.
(after! restart-emacs
  (defadvice! nix-doom-restart-emacs (fargs)
    "Add --init-directory argument necessary to start Doom."
    :filter-args #'restart-emacs
    (cl-destructuring-bind (&optional args) fargs
      (let* ((init-arg (format "--init-directory=%s" doom-emacs-dir))
             (fixed-args (cons init-arg args)))
        (list fixed-args)))))
