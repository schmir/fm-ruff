# fm-ruff

This is a flymake backend for python. It's using [ruff](https://astral.sh/ruff)
with json output to generate warnings asynchronously.  Using the json output
allows fm-ruff to mark the exact location of warnings.

## Installation

fm-ruff is not yet available on melpa.

### emacs 29
``` emacs-lisp
(unless (package-installed-p 'fm-ruff)
  (package-vc-install "https://github.com/schmir/fm-ruff"))

(use-package fm-ruff
  :hook (python-mode . fm-ruff-setup))
```

### emacs 30
``` emacs-lisp
(use-package fm-ruff
  :vc (:fetcher github :repo schmir/fm-ruff)
  :hook (python-mode . fm-ruff-setup))
```
