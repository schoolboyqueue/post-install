#!/bin/bash
# -*- Mode: sh; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
#
# Authors:
#   Jeremy Carter
#
# Description:
#   A post-installation bash script for OSX

# tab width
tabs 4
clear

#----- Setup -----#

# Make sure umask is sane
umask 022

# Set up a default search path.
PATH="/usr/local/bin:/usr/local/share/npm/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
export PATH

# Get a sane screen width
[ -z "${COLUMNS:-}" ] && COLUMNS=80

# [ -z "${CONSOLETYPE:-}" ] && CONSOLETYPE="`/sbin/consoletype`"

if [ -f /etc/sysconfig/i18n -a -z "${NOLOCALE:-}" ] ; then
  . /etc/profile.d/lang.sh
fi

# Read in our configuration
if [ -z "${BOOTUP:-}" ]; then
  if [ -f /etc/sysconfig/init ]; then
      . /etc/sysconfig/init
  else
    # This all seem confusing? Look in /etc/sysconfig/init,
    # or in /usr/doc/initscripts-*/sysconfig.txt
    BOOTUP=color
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_INFO="echo -en \\033[1;37m"
    SETCOLOR_NORMAL="echo -en \\033[0;39m"
    LOGLEVEL=1
  fi
  if [ "$CONSOLETYPE" = "serial" ]; then
      BOOTUP=serial
      MOVE_TO_COL=
      SETCOLOR_SUCCESS=
      SETCOLOR_FAILURE=
      SETCOLOR_WARNING=
      SETCOLOR_NORMAL=
  fi
fi

if [ "${BOOTUP:-}" != "verbose" ]; then
   INITLOG_ARGS="-q"
else
   INITLOG_ARGS=
fi

#----- Fancy Messages -----#
function echo_success {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $"  OK  "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 0
}

function echo_failure {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
  echo -n $"FAILED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

function echo_passed {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"PASSED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

function echo_skipped {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_INFO
  echo -n $"SKIPPED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

function echo_warning {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"WARNING"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

function confirm {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 1; break;;
            [Nn]* ) return 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

function step {
    echo -n "$@"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}

function next {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    [[ $STEP_OK -ne 0 ]]  && exit $STEP_OK

    return $STEP_OK
}

function skip {
    [[ -f /tmp/step.$$ ]] && rm -f /tmp/step.$$
    echo_skipped
    echo
}


if [[ `type -a brew | wc -l` -eq 0 ]]; then
    echo "To continue, we require Homebrew and whiptail, a package management tool for OSX. If you already have it, great,"
    echo "if not we will install it for you"
    echo
    confirm "Continue?"
    CONTINUE=$?

    if [[ $CONTINUE -eq 1 ]]; then

        step "Installing Homebrew: "
        if [ ! -f /usr/local/bin/brew ]; then
            try ruby -e "$(\curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
            next
        else
            skip
        fi

        step "Installing Whiptail (pretty menu): "
        if [ ! -f /usr/local/bin/whiptail ]; then
            try brew install newt
            next
        else
            # Test if whiptail broken
            whiptail -v > /dev/null 2>/dev/null
            if [[ $? -ne 0 ]]; then
                try brew reinstall newt
                next
            else
                skip
            fi
        fi

        else
            echo "Aborting."
            exit 0
    fi
fi

menu=(whiptail --separate-output --title "Install Options" --checklist "\nSelect the dev options you want (I recommend having all):\n\n[spacebar] = toggle on/off" 0 0 0)
options=(
        1 "Python with pip" on
        2 "NodeJS with nvm (version manager) and npm" off
        3 "Ruby" off
        4 "Java 8 JDK" off
        5 "Common libraries from Homebrew" on
        6 "OH-MY-ZSH & Prezto w/ color schemes and aliases" on
        7 "Sublime Text 3 w/ custom settings" on
        8 "Vim w/ vundle and custom settings" on
        9 "Iterm2 w/ custom scheme" on
        10 "Go with development environment set to ~/Go" on
        11 ".NET development tools" off)
choices=$("${menu[@]}" "${options[@]}" 2>&1 > /dev/tty)

if [[ $? -ne 0 ]]; then
  echo "Aborting..."
  exit 1
fi

choice_count=$(echo "$choices" | grep -v '^$' | wc -l)
if [ $choice_count -eq 0 ]; then
  echo "Nothing selected."
  exit 0
fi

for choice in $choices
do
    case $choice in
        1)
            SETUP_PYTHON=0
        ;;
        2)
            SETUP_NODEJS=0
        ;;
        3)
            SETUP_RUBY=0
        ;;
        4)
            SETUP_JDK8=0
        ;;
        5)
            SETUP_HOMEBREW_COMMONS=0
        ;;
        6)
            SETUP_OHMYZSH=0
        ;;
        7)
            SETUP_SUBLIME=0
        ;;
        8)
            SETUP_VIM=0
        ;;
        9)
            SETUP_IERM2=0
        ;;
        10)
            SETUP_GO=0
        ;;
        11)
            SETUP_DOTNET=0
        ;;
    esac
done

step "Installing Python"
if [[ $SETUP_PYTHON ]]; then
    # Only the system python is installed
    if [[ `type -a python | wc -l` -eq 1 ]]; then
        try brew install python > /dev/null 2>/tmp/dev-strap.err
        try sudo easy_install pip > /dev/null 2> tmp/dev-strap.err
        try pip install --upgrade pip > /dev/null 2> tmp/dev-strap.err
        if [[ $? -ne 0 ]]; then
            cat /tmp/dev-strap.err
            rm /tmp/dev-strap.err
        fi
    fi
    next
else
    skip
fi

step "Installing NodeJS"
if [[ $SETUP_NODEJS ]]; then
    try brew install node > /dev/null 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi

step "Installing Ruby"
if [[ $SETUP_RUBY ]]; then
    try brew install ruby > /dev/null 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi

step "Installing Java 8 JDK"
if [[ $SETUP_JDK8 ]]; then
    try brew cask install java > /dev/null 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi

step "Installing common required libraries: "
if [[ $SETUP_HOMEBREW_COMMONS ]]; then
    try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then brew $in || true; fi; fi; done < $PWD/brew > /dev/null 2>/tmp/dev-strap.err)
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
  skip
fi

step "Installing OH-MY-ZSH / Prezto"
if [[ $SETUP_JDK8 ]]; then
    if [[ `type -a zsh | wc -l` -ne 2 ]]; then
        try brew install zsh > /dev/null 2>/tmp/dev-strap.err
        try zsh > /dev/null 2>/tmp/dev-strap.err
        try git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
        try $(setopt EXTENDED_GLOB; for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"; done if [[ $? -ne 0 ]]; then cat /tmp/dev-strap.err; rm /tmp/dev-strap.err; fi;)
        try cp $PWD/.zpreztorc ~/
        try chsh -s /bin/zsh > /dev/null 2>/tmp/dev-strap.err
        try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then echo $in >> ~/.zshrc || true; fi; fi; done < $PWD/aliases > /dev/null 2>/tmp/dev-strap.err)
        if [[ $? -ne 0 ]]; then
            cat /tmp/dev-strap.err
            rm /tmp/dev-strap.err
        fi
    fi
    next
else
    skip
fi

step "Installing Vim w/ vundle"
if [[ $SETUP_VIM ]]; then
    try brew install vim > /dev/null 2>/tmp/dev-strap.err
    try git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim > /dev/null 2>/tmp/dev-strap.err
    cp $PWD/.vimrc ~/
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi

step "Installing Iterm2 nightly"
if [[ $SETUP_VIM ]]; then
    try brew cask install iterm2-nightly > /dev/null 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi

step "Installing Go and setting up environment"
if [[ $SETUP_VIM ]]; then
    try brew install go > /dev/null 2>/tmp/dev-strap.err
    try brew install mercurial > /dev/null 2>/tmp/dev-strap.err
    try mkdir ~/Go > /dev/null 2>/tmp/dev-strap.err
    try read -p "Enter github username: " username
    try mkdir -p ~/Go/src/github.com/$username
    try echo 'export GOPATH=$HOME/Go' >> ~/.zshrc
    try echo 'export GOROOT=/usr/local/opt/go/libexec' >> ~/.zshrc
    try echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
    try echo 'export PATH=$PATH:$GOROOT/bin' >> ~/.zshrc
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi

step "Installing .NET development tools"
if [[ $SETUP_DOTNET ]]; then
    try brew tap aspnet/dnx > /dev/null 2>/tmp/dev-strap.err
    try brew update > /dev/null 2>/tmp/dev-strap.err
    try brew install dnvm > /dev/null 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
    fi
    next
else
    skip
fi


# END OF SCRIPT
