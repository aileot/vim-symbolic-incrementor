scriptencoding utf-8

" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

" List of special cases where the pattern regards a char as isolated, which
" is different from the simple pattern '\<.\>':
"     - one letter char beside underscore ('_') like `ptr_a` to `ptr_b`
"     - any kind of quoted unicode char like '"あ"'
"
" List of chars to be ignored even when they look isolated:
"     - escaped alphabet with a backslash ('\')
"     - modifier prefix like, 'C' in '<C-x>' or 'A' in <A-j>'
"     - prefix for variables' scope of Vimscript like g:, s:, l:
"     - alphabet after apostrophe like `don't` or `it's`, which is detected
"       by s:is_abbr() in s:find_in_line(
"
" Note: Evade such atoms as '\1' which could cause trouble joining somewhere.
" Note: Keep to add '\v' on the head of each patterns easier to check.
let s:unicode = '\v[^][./\?|<>;:''"-=_+`~!@#$%^&*(){}]'
let s:pat_isolated = '\v\d'
      \ .'|'. '\v(\v"\zs'.  s:unicode .'\ze")'
      \ .'|'. '\v(\v''\zs'. s:unicode .'\ze'')'
      \ .'|'. '\v((<([\<\\])@<!|_\zs)\a:@!(\ze_|>))'

function! symbolicInc#increment(cnt) abort
  let s:sync = 0
  call s:increment("\<C-a>", a:cnt)
endfunction

function! symbolicInc#decrement(cnt) abort
  let s:sync = 0
  call s:increment("\<C-x>", a:cnt)
endfunction

function! symbolicInc#increment_sync(cnt) abort
  let s:sync = 1
  call s:increment("\<C-a>", a:cnt)
endfunction

function! symbolicInc#decrement_sync(cnt) abort
  let s:sync = 1
  call s:increment("\<C-x>", a:cnt)
endfunction

function! s:increment(cmd, cnt) abort "{{{1
  let cnt = a:cnt
  let saveline = getline('.')
  call s:try_switch(a:cmd)
  if getline('.') !=# saveline | return | endif

  let op = s:set_operator(a:cmd)

  let target = s:find_target()
  if len(target) == 0 | return | endif
  if target =~# '\d\+'
    exe 'norm!' cnt . a:cmd
    return
  endif

  let save_eventignore = &eventignore
  set eventignore=
  set ei+=TextChanged

  let num = char2nr(target)
  " Ref: Increment any other characters than ascii.
  " https://github.com/monaqa/dotfiles/blob/32f70b3f92d75eaab07a33f8bf28ee17927476e8/.config/nvim/init.vim#L950-L960
  let new_char = nr2char(eval(num . op . cnt))
  let new_char = s:set_sane_new_char(target, new_char)

  if !s:sync
    exe 'norm! r'. new_char
  else
    call s:_increment_sync(target, new_char)
  endif

  let &eventignore = save_eventignore
endfunction

function! s:try_switch(cmd) abort "{{{2
  if g:symbolicInc#disable_integration_switch | return | endif

  try
    if a:cmd ==? "\<C-a>"
      Switch
    elseif a:cmd ==? "\<C-x>"
      SwitchReverse
    endif

  catch /^Vim\v%((\a+))?:E(464|492)/
    let g:symbolicInc#disable_integration_switch = 1
  endtry
endfunction

function! s:set_operator(cmd) abort "{{{2
  if a:cmd ==# "\<C-a>"
    return '+'
  elseif a:cmd ==# "\<C-x>"
    return '-'
  endif

  throw '[Symbolic Incrementor] Invalid argument: '. a:cmd
endfunction

function! s:find_target() abort "{{{2
  let save_view = winsaveview()
  " Return true if cursor is on the very position that escaped alphabet char.
  if searchpos('\\\zs\a', 'cWn') == [save_view['lnum'], save_view['col'] + 1]
    return getline('.')[col('.') - 1]
  endif

  let is_found = 0
  for direction in ['forward', 'backward']
    if s:find_in_line(s:pat_isolated, direction)
      let is_found = 1
      break
    endif
  endfor

  " Exclude characters after current column to get pattern.
  if is_found
    return s:get_cursor_char()
  endif

  return ''
endfunction

function! s:find_in_line(pat, direction) abort "{{{2
  let save_view = winsaveview()
  let flags = 'W'
  if a:direction ==# 'backward'
    let flags .= 'b'
  endif

  let s:is_abbr = {-> getline('.')[:col('.')] =~# '''[st] $'}
  " Set cursor to an id char/number if it's found in the cursor line;
  " otherwise, get back to the saved position.
  if search(a:pat, 'c'. flags) == save_view['lnum'] && !s:is_abbr()
    return 1
  endif

  while s:is_abbr()
    if search(a:pat, flags) != save_view['lnum']
      call winrestview(save_view)
      return 0
    endif
  endwhile

  if line('.') == save_view['lnum']
    return search(a:pat, 'nc'. flags) == save_view['lnum']
  endif

  call winrestview(save_view)
  return 0
endfunction

function! s:get_cursor_char() abort
  let cursor = matchstr(getline('.'), '.\%'. (col('.') + 1) .'c')
  if len(cursor) == 0
    " The '+2' is for unicode
    let cursor = matchstr(getline('.'), '.\%'. (col('.') + 3) .'c')
  endif

  return cursor
endfunction

function! s:set_sane_new_char(old_char, new_char) abort "{{{2
  let new_char = a:new_char

  " If target is smaller than a, new_char is 'a'; if just 'a', new_char is 'z'.
  " That is, 'a' decrements to 'z'; 'Z' increments to 'A'.
  if a:old_char =~# '\l' && new_char =~# '\L'
    let new_char = a:old_char ==# 'a' ? 'z' : 'a'
    if new_char > a:old_char
      let new_char = a:old_char ==# 'a' ? 'z' : 'a'
    endif

  elseif a:old_char =~# '\u' && new_char =~# '\U'
    let new_char = a:old_char ==# 'A' ? 'Z' : 'A'
    if new_char < a:old_char
      let new_char = a:old_char ==# 'A' ? 'A' : 'Z'
    endif
  endif

  return new_char
endfunction

function! s:_increment_sync(old_char, new_char) abort "{{{2
  let save_view = winsaveview()
  " Tips: Use '*' to get all the same letters in s:pat_isolated;
  " '\&', or '\v&', is useless to get 'A' in 'foo_A'.
  let pat = '\v('. s:pat_isolated .')' .'*'. a:old_char .'\C'
  exe 'keepjumps keeppatterns s/'. pat .'/'. a:new_char .'/g'
  call winrestview(save_view)
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline {{{1
" vim: et ts=2 sts=2 sw=2 fdm=marker tw=79
