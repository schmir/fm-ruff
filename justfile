# List available recipes
help:
    @just --list

# Run ERT tests
test:
    emacs --batch -L . -l fm-ruff-tests.el -f ert-run-tests-batch-and-exit

# Run package-lint
lint:
    cask exec emacs --batch -L . -l package-lint -f package-lint-batch-and-exit fm-ruff.el
