#!/bin/bash
# install.sh — install gitkp as a global command (openmain style).
#
#   Clones the repo to ~/.gitkeep-init, adds the line to ~/.bashrc,
#   sources the script and leaves the gitkp command available
#   from any directory, with tab autocompletion.

REPO_URL="https://github.com/aonisoft/gitkeep-init.git"

install_path=~/.gitkeep-init

echo "Downloading gitkeep-init in $install_path..."

[[ ! -d $install_path ]] || rm -fr $install_path

git clone "$REPO_URL" "$install_path/tmp" > /dev/null 2>&1

mv $install_path/tmp/* $install_path/

rm -fr $install_path/tmp

echo "It's done."

[[ -n $( grep ${install_path}/gitkeep-init.sh ~/.bashrc ) ]] || \
{
  echo "Update bashrc..."

  echo ". $install_path/gitkeep-init.sh" >> ~/.bashrc
}

source $install_path/gitkeep-init.sh

echo "The command to manage the .gitkeep structure is gitkp. Use tab the key to see subcommands."
