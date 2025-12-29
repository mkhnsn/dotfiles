" .vimrc - Vim configuration

" ============================================================================
" General Settings
" ============================================================================
set nocompatible              " Use Vim defaults (not Vi)
filetype plugin indent on     " Enable file type detection
syntax enable                 " Enable syntax highlighting

" ============================================================================
" Visual Settings
" ============================================================================
set number                    " Show line numbers
set relativenumber            " Show relative line numbers
set ruler                     " Show cursor position
set showcmd                   " Show command in bottom bar
set wildmenu                  " Visual autocomplete for command menu
set showmatch                 " Highlight matching [{()}]
set cursorline                " Highlight current line
set laststatus=2              " Always show status line
set visualbell                " Use visual bell instead of beeping
set title                     " Set terminal title

" ============================================================================
" Search Settings
" ============================================================================
set incsearch                 " Search as characters are entered
set hlsearch                  " Highlight search matches
set ignorecase                " Case insensitive searching
set smartcase                 " Override ignorecase if uppercase is used

" ============================================================================
" Indentation Settings
" ============================================================================
set autoindent                " Copy indent from current line when starting new line
set smartindent               " Smart autoindenting on new line
set tabstop=4                 " Number of visual spaces per TAB
set softtabstop=4             " Number of spaces in tab when editing
set shiftwidth=4              " Number of spaces to use for autoindent
set expandtab                 " Tabs are spaces
set smarttab                  " Be smart about tabs

" ============================================================================
" Editor Behavior
" ============================================================================
set backspace=indent,eol,start " Make backspace work as expected
set clipboard=unnamed          " Use system clipboard
set mouse=a                    " Enable mouse support
set encoding=utf-8             " Set encoding
set fileencoding=utf-8         " Set file encoding
set hidden                     " Allow hidden buffers
set autoread                   " Auto reload files changed outside vim
set history=1000               " Remember more commands
set undolevels=1000            " More undo levels
set scrolloff=3                " Keep 3 lines visible above/below cursor
set sidescrolloff=5            " Keep 5 columns visible left/right of cursor

" ============================================================================
" File Handling
" ============================================================================
set nobackup                  " Don't create backup files
set nowritebackup             " Don't create backup before overwriting
set noswapfile                " Don't create swap files

" ============================================================================
" Key Mappings
" ============================================================================

" Set leader key to space
let mapleader = " "

" Quick save
nnoremap <leader>w :w<CR>

" Quick quit
nnoremap <leader>q :q<CR>

" Quick save and quit
nnoremap <leader>x :wq<CR>

" Clear search highlighting
nnoremap <leader><space> :nohlsearch<CR>

" Move between windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Move lines up and down
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

" Better indenting
vnoremap < <gv
vnoremap > >gv

" ============================================================================
" File Type Specific Settings
" ============================================================================

" JavaScript/TypeScript
autocmd FileType javascript,typescript,javascriptreact,typescriptreact setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType json setlocal tabstop=2 shiftwidth=2 softtabstop=2

" HTML/CSS
autocmd FileType html,css,scss,sass setlocal tabstop=2 shiftwidth=2 softtabstop=2

" Python
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4

" Ruby
autocmd FileType ruby setlocal tabstop=2 shiftwidth=2 softtabstop=2

" Go
autocmd FileType go setlocal tabstop=4 shiftwidth=4 softtabstop=4 noexpandtab

" YAML
autocmd FileType yaml setlocal tabstop=2 shiftwidth=2 softtabstop=2

" ============================================================================
" Status Line
" ============================================================================
set statusline=%f                           " File name
set statusline+=\ %m                        " Modified flag
set statusline+=\ %r                        " Read-only flag
set statusline+=\ %y                        " File type
set statusline+=%=                          " Right align
set statusline+=\ %l:%c                     " Line:Column
set statusline+=\ %p%%                      " Percentage through file
set statusline+=\ [%L]                      " Total lines

" ============================================================================
" Load local vimrc if it exists
" ============================================================================
if filereadable(expand("~/.vimrc.local"))
    source ~/.vimrc.local
endif
