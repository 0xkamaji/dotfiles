"        _
" __   _(_)_ __ ___  _ __ ___
" \ \ / / | '_ ` _ \| '__/ __|
"  \ V /| | | | | | | | | (__
"   \_/ |_|_| |_| |_|_|  \___|

syntax on                       " Enable syntax highlighting
set number                      " Show line numbers
set wildmenu                    " Better tab completion in normal mode
set ignorecase                  " Ignore case in searches...
set smartcase                   " ...unless there are capital letters
set incsearch                   " Show search results while searching
"set dir=~/.vim/tmp//            " Store swap files in dedicated directory
set tabstop=4
set expandtab


" ----------
" Hybrid Number Auto Switch
" ----------
set relativenumber              " Show numbers relate to current line

augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup END
