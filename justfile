# List available recipes
help:
    @just --list

# Run ERT tests
test:
    emacs --batch -L . -l fm-ruff-tests.el -f ert-run-tests-batch-and-exit

# Install cask dependencies
cask-install:
    cask install

# Run package-lint
lint: cask-install
    cask exec emacs --batch -L . -l package-lint -f package-lint-batch-and-exit fm-ruff.el

# Update nix flake inputs
update:
    nix flake update

# Run tests with emacs 29 inside nix dev shell
nix-test-29:
    nix develop .#emacs29 -c just test

# Run tests with emacs 30 inside nix dev shell
nix-test:
    nix develop . -c just test

# Run tests with Emacs 29
nix-test-all: nix-test-29 nix-test

# Run lint inside nix dev shell
nix-lint:
    nix develop . -c just lint

