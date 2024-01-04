# .bashrc

if [ -n "$PS1" ]
then
    export EDITOR=vim

    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

    alias soba='source ~/.bashrc'
    alias viba='vi ~/.bashrc'
    alias sub='sudo -i'
    alias vi='vim'
    alias ll='ls -al'

    alias ydf="df -x tmpfs -x devtmpfs -x efivarfs -T -h"
    alias ydu="du -xhd1"
    alias yupdateall="sudo pacman -Syu" # Sync, refresh, update
    alias ykeyupdate="sudo pacman -Sy archlinux-keyring && sudo pacman -Su"
fi
