"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Alessandro's vimrc configuration file         
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Uncomment the following to have Vim load indentation rules and plugins
" according to the detected filetype.
"if has("autocmd")
"  filetype plugin indent on
"endif

if v:version <= 802
    packadd! dracula
endif
syntax enable
colorscheme dracula

set encoding=utf-8
syntax enable               " Enables syntax highlighting by default.
colorscheme dracula         " Dracula color scheme.
set showcmd                 " Show (partial) command in status line.

set tabstop=2                   " Set Tab space
set expandtab                   " use spaces, not tabs (optional)
set backspace=indent,eol,start  " backspace through everything in insert mode

set showmatch               " Show matching brackets.
set ignorecase              " Do case insensitive matching
set smartcase               " Do smart case matching
set incsearch               " Incremental search
set autoindent              " Enable Autoindent
set visualbell              " Silence Enable the bell, use a flash instead

"set autowrite      " Automatically save before commands like :next and :make
"set hidden         " Hide buffers when they are abandoned
"set mouse=a        " Enable mouse usage (all modes) in terminals

