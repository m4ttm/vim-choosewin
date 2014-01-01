let s:supported_chars = join(map(range(33, 126), 'nr2char(v:val)'), '')

" Util:
function! s:intrpl(string, vars) "{{{1
  let mark = '\v\{(.{-})\}'
  let r = []
  for expr in s:scan(a:string, mark)
    call add(r, substitute(expr, '\v([a-z][a-z$0]*)', '\=a:vars[submatch(1)]', 'g'))
  endfor
  call map(r, 'eval(v:val)')
  return substitute(a:string, mark,'\=remove(r, 0)', 'g')
endfunction

function! s:str_split(str) "{{{1
  return split(a:str, '\zs')
endfunction

function! s:scan(str, pattern) "{{{1
  let ret = []
  let nth = 1
  while 1
    let m = matchlist(a:str, a:pattern, 0, nth)
    if empty(m)
      break
    endif
    call add(ret, m[1])
    let nth += 1
  endwhile
  return ret
endfunction
function! s:getwinline(win, ...) "{{{1
  " getbufline() wrapper
  let args = [ winbufnr(a:win) ] + a:000
  return call(function('getbufline'), args)
endfunction

function! s:setbufline(expr, lnum, text) "{{{1
  " from tyru's gist
  " https://gist.github.com/tyru/571746/c98b31859760c6d0ccb41d4ee210ac32913ecc8e
  let oldnr = winnr()
  let winnr = bufwinnr(a:expr)
  try
    if oldnr == winnr
      silent! call setline(a:lnum, a:text)
    elseif winnr ==# -1
      silent split
      silent execute bufnr(a:expr) 'buffer'
      silent call setline(a:lnum, a:text)
      silent hide
    else
      execute winnr 'wincmd w'
      silent call setline(a:lnum, a:text)
    endif
  finally
    execute oldnr 'wincmd w'
  endtry
endfunction

function! s:append_space(str, maxlen) "{{{1
  let pad = a:maxlen - len(a:str)
  return (pad > 0) ? a:str . repeat(' ', pad) : a:str
endfunction

function! s:tab2space(str, tabstop) "{{{1
  return substitute(a:str, "\t", repeat(" ", a:tabstop), 'g')
endfunction

function! s:fill_space(list, tabstop, maxwidth) "{{{1
  return map(deepcopy(a:list), 's:append_space(s:tab2space(v:val, a:tabstop), a:maxwidth)')
endfunction
"}}}

" Overlay:
let s:overlay = {}
function! s:overlay.init() "{{{1
  let self.hlter = choosewin#highlighter#get()
  let self.color = self.hlter.color
  let self._font_table = choosewin#font#table()
endfunction

function! s:overlay.fill_space(line_s, line_e, width) "{{{1
  let lines_new = s:fill_space(
        \ getline(a:line_s, a:line_e), &tabstop, a:width)
  silent! undojoin
  call setline(a:line_s, lines_new)
endfunction

function! s:overlay.lines_restore(store) "{{{1
  for [lnum, content]  in items(a:store)
    call setline(lnum, content)
  endfor
endfunction

function! s:overlay.lines_preserve(line_s, line_e, store) "{{{1
  for line in range(a:line_s, a:line_e)
    if has_key(a:store, line)
      continue
    endif
    let a:store[line] = getline(line)
  endfor
endfunction

function! s:overlay.main(wins) "{{{1
  let overlay_height = 10
  let overlay_width  = 80
  let winnr_org      = winnr()
  let lines_org      = {}
  let self.wins = a:wins
  for winnum in a:wins
    let lines_org[winnum] = {}
  endfor

  let captions = s:str_split(g:choosewin_label)
  " Setup rendering area:
  try
    for winnr in a:wins
      execute winnr 'wincmd w'
      let font = self._font_table[remove(captions, 0)]
      let line_s = line('w0') + (winheight(0) - font.height)/2
      let col = (winwidth(0) - font.width)/2
      let line_e = line_s + overlay_height
      call self.lines_preserve(line_s, line_e, lines_org[winnum])
      call self.fill_space(line_s, line_e, overlay_width)
      call self.shade()
      call self.overlay([line_s, col ], font.pattern)
    endfor
  finally
    execute winnr_org 'wincmd w'
  endtry

  " Read input:
  redraw
  echon 'continue?'
  call getchar()

  " Take action:

  " Revert
  try
    for winnr in a:wins
      execute winnr 'wincmd w'
      call clearmatches()
      call self.lines_restore(lines_org[winnr])
    endfor
  finally
    execute winnr_org 'wincmd w'
  endtry
endfunction

function! s:overlay.shade() "{{{1
  let vars = {
        \ 'w0': line('w0'),
        \ 'w$': line('w$'),
        \ }
  let pat = s:intrpl('%{w0}l\_.*%{w$}l', vars)
  call matchadd(self.color.Shade, '\v'. pat )
endfunction

function! s:overlay.overlay(pos, pattern) "{{{1
  let vars = {
        \ 'line': a:pos[0],
        \ 'col':  a:pos[1],
        \ }
  let pattern = s:intrpl(a:pattern, vars)
  " call matchadd('SmallsCurrent' , pattern, 1000)
  call matchadd(self.color.OverlayCurrent , pattern, 1000)
endfunction
"}}}
function! choosewin#overlay#main(...)
  call call(s:overlay.main, a:000, s:overlay)
endfunction

call s:overlay.init()
if expand("%:p") !=# expand("<sfile>:p")
  finish
endif
let g:choosewin_label = ';@ABCDEFGHIJKLMNOPQRSTUVWXYZ'
command! OverLay call s:overlay.main(range(1, winnr('$')))
" vim: foldmethod=marker
