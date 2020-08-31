fu! esearch#out#win#appearance#cursor_linenr#soft_stop(esearch) abort
  call esearch#out#win#appearance#cursor_linenr#uninit(a:esearch)
endfu

if has('nvim')
    " vim methods like matchadd have problems when leaving the the
  fu! esearch#out#win#appearance#cursor_linenr#init(esearch) abort
    let a:esearch.linenr_ns_id = luaeval('esearch.appearance.CURSOR_LINENR_NS')

    aug esearch_win_hl_cursor_linenr
      au CompleteChanged,CursorMoved,CursorMovedI <buffer> call s:highlight_cursor_line_number()
      au BufLeave <buffer> call s:clear_cursor_line_number()
    aug END
  endfu

  fu! esearch#out#win#appearance#cursor_linenr#uninit(esearch) abort
    aug esearch_win_hl_cursor_linenr
      au! * <buffer>
    aug END

    if has_key(a:esearch, 'linenr_ns_id')
      call s:clear_cursor_line_number()
    endif
  endfu

  fu! s:highlight_cursor_line_number() abort
    call luaeval('esearch.appearance.highlight_cursor_linenr()')
  endfu

  fu! s:clear_cursor_line_number() abort
    call nvim_buf_clear_namespace(0, b:esearch.linenr_ns_id, 0, -1)
  endfu

  finish
endif

fu! esearch#out#win#appearance#cursor_linenr#init(esearch) abort
  let a:esearch.linenr_hl_id = 0

  aug esearch_win_hl_cursor_linenr
    au CursorMoved,CursorMovedI <buffer> call s:highlight_cursor_line_number()
    " TODO has bugs when splitting using capital S
    au BufLeave <buffer> call s:clear_cursor_line_number()
  aug END
endfu

fu! esearch#out#win#appearance#cursor_linenr#uninit(esearch) abort
  aug esearch_win_hl_cursor_linenr
    au! * <buffer>
  aug END

  if has_key(a:esearch, 'linenr_hl_id')
    call s:clear_cursor_line_number()
  endif
endfu

fu! s:highlight_cursor_line_number() abort
  call esearch#util#safe_matchdelete(b:esearch.linenr_hl_id)
  let b:esearch.linenr_hl_id = matchadd('esearchCursorLineNr',
        \ '^\s\+\d\+\s\%' . line('.') . 'l', -1)
endfu

fu! s:clear_cursor_line_number() abort
  call esearch#util#safe_matchdelete(b:esearch.linenr_hl_id)
endfu