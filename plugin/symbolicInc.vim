" ============================================================================
" Repo: kaile256/vim-symbolic-incrementor
" File: plugin/symbolicInc.vim
" Author: kaile256
" License: MIT license {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" ============================================================================

if exists('g:loaded_symbolic_incrementor') | finish | endif "{{{
let g:loaded_symbolic_incrementor = 1

" save 'cpoptions'
let s:save_cpo = &cpo
set cpo&vim
"}}}

let g:symbolicInc#disable_integration_repeat_undojoin =
      \ get(g:, 'symbolicInc#disable_integration_repeat_undojoin', 0)
let g:symbolicInc#disable_integration_switch =
      \ get(g:, 'symbolicInc#disable_integration_switch', 0)

function! s:symbolicInc(map_name) abort
  let map_name = substitute(a:map_name, '-', '_', 'g')
  call symbolicInc#{map_name}(v:count1)
  call s:set_repeat(a:map_name)
endfunction

function! s:set_repeat(map_name) abort
  let map_name = g:symbolicInc#disable_integration_repeat_undojoin
        \ ? a:map_name
        \ : a:map_name .'-undojoin'
  let sequence = "\<Plug>(symbolicInc-". map_name .')'
  silent! call repeat#set(sequence)
endfunction

function! s:undojoinable(map_name) abort
  " TODO: make it dot repeatable even after <undo>.

  let ut = undotree()
  if ut.seq_cur == ut.seq_last
    undojoin
  endif

  let modify = substitute(a:map_name, '-', '_', 'g')
  call symbolicInc#{modify}(v:count1)
  call s:set_repeat(a:map_name)
endfunction

nnoremap <silent> <Plug>(symbolicInc-increment)
      \ :<C-u>call <SID>symbolicInc('increment')<CR>
nnoremap <silent> <Plug>(symbolicInc-decrement)
      \ :<C-u>call <SID>symbolicInc('decrement')<CR>

nnoremap <silent> <Plug>(symbolicInc-increment-sync)
      \ :<C-u>call <SID>symbolicInc('increment-sync')<CR>
nnoremap <silent> <Plug>(symbolicInc-decrement-sync)
      \ :<C-u>call <SID>symbolicInc('decrement-sync')<CR>


" These mappings <Plug>(foo-undojoin) below are only for internal usage.
nnoremap <silent> <Plug>(symbolicInc-increment-undojoin)
      \ :<C-u>call <SID>undojoinable('increment')<CR>
nnoremap <silent> <Plug>(symbolicInc-decrement-undojoin)
      \ :<C-u>call <SID>undojoinable('decrement')<CR>

nnoremap <silent> <Plug>(symbolicInc-increment-sync-undojoin)
      \ :<C-u>call <SID>undojoinable('increment-sync')<CR>
nnoremap <silent> <Plug>(symbolicInc-decrement-sync-undojoin)
      \ :<C-u>call <SID>undojoinable('decrement-sync')<CR>

if !get(g:, 'symbolicInc#no_default_mappings')
  nmap <C-a> <Plug>(symbolicInc-increment)
  nmap <C-x> <Plug>(symbolicInc-decrement)
  nmap g<C-a> <Plug>(symbolicInc-increment-sync)
  nmap g<C-x> <Plug>(symbolicInc-decrement-sync)
endif

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline {{{1
" vim: et ts=2 sts=2 sw=2 fdm=marker tw=79
