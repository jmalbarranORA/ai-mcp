#!/usr/bin/env bash
pyenv global 3.12

echo "Python version"
python --version

echo "PIP version"
pip --version
pip install --upgrade pip

echo "Create virtual environment"
rm -rf .venv
python -m venv .venv
source .venv/bin/activate

pip install -r requirements



