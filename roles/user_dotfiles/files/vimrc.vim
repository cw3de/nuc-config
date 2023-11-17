" .vimrc for cw@nuc
version 5.0

set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent
set smartindent

set modeline

autocmd Filetype python setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab autoindent smartindent

set number
set incsearch
set ignorecase
set fileencoding=utf-8
set encoding=utf-8

if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

let mapleader = ","
nmap <Leader><Leader> :e #<CR>
nmap <Leader>e :e #
nmap <Leader>f :files<CR>
