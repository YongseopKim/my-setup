" ~/.vimrc
" Ubuntu vanilla Vim — final

" === 기본 ===
set nocompatible
filetype plugin indent on
syntax on
set encoding=utf-8
set fileencoding=utf-8
set backspace=indent,eol,start
set hidden
set autoread
set clipboard=unnamedplus
set formatoptions+=j

" === 타이밍 ===
set timeout
set ttimeout
set timeoutlen=500
set ttimeoutlen=10

" === 검색 ===
set incsearch
set hlsearch
set ignorecase
set smartcase
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

" === 들여쓰기 ===
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent

" === UI ===
set number
set relativenumber
set cursorline
set scrolloff=8
set sidescrolloff=5
set showmatch
set showcmd
set showmode
set wildmenu
set wildmode=longest:full,full
set laststatus=2

" === 공백 가시화 ===
set list
set listchars=tab:»·,trail:·,extends:›,precedes:‹,nbsp:␣

" === undo/backup ===
set undofile
set undodir=~/.vim/undodir
set noswapfile
set nobackup
set backupskip=/tmp/*
set updatetime=300

" === 상태바 ===
set statusline=%f\ %m%r%h%w\ [%{&ff}/%{&enc}]\ %=\ %l:%c\ [%p%%]

" === Leader ===
let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>e :Ex<CR>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprev<CR>

" === 창 이동 ===
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" === Visual 블록 이동 ===
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" === netrw ===
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_winsize = 25
