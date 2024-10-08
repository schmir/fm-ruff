# fm-ruff

This is a flymake backend for python. It's using [ruff](https://astral.sh/ruff)
with json output to generate warnings asynchronously.  Using the json output
allows fm-ruff to mark the exact location of warnings.

## Installation

fm-ruff is not yet available on melpa.

### emacs 28

With emacs 28, clone the `fm-ruff` repository:

``` shellsession
git clone https://github.com/schmir/fm-ruff
```

Call `M-x package-install-file` and choose the directory where you cloned the
repository. Add the following to your init file:

``` emacs-lisp
(add-hook 'python-mode-hook #'fm-ruff-setup)
```

### emacs 29

You can use package-vc-install to download and install the package
automatically:

``` emacs-lisp
(unless (package-installed-p 'fm-ruff)
  (package-vc-install "https://github.com/schmir/fm-ruff"))

(use-package fm-ruff
  :hook (python-mode . fm-ruff-setup))
```

### emacs 30

With emacs 30, add the following to your init file:

``` emacs-lisp
(use-package fm-ruff
  :vc (:fetcher github :repo schmir/fm-ruff)
  :hook (python-mode . fm-ruff-setup))
```
