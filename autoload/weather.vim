scriptencoding cp932

let s:title = '------------------------  WEATHER-VIM  ------------------------'
let s:toAll = '>>�S��'
let s:locations = []
let [s:WIN_ALL, s:WIN_CITY] = range(2)

function! s:nr2byte(nr)
  if a:nr < 0x80
    return nr2char(a:nr)
  elseif a:nr < 0x800
    return nr2char(a:nr/64+192).nr2char(a:nr%64+128)
  else
    return nr2char(a:nr/4096%16+224).nr2char(a:nr/64%64+128).nr2char(a:nr%64+128)
  endif
endfunction

function! s:nr2enc_char(charcode)
  if &encoding == 'utf-8'
    return nr2char(a:charcode)
  endif
  let char = s:nr2byte(a:charcode)
  if strlen(char) > 1
    let char = strtrans(iconv(char, 'utf-8', &encoding))
  endif
  return char
endfunction

function! s:decode(json)
  let json = iconv(a:json, "utf-8", &encoding)
  let json = substitute(json, '\\n', '', 'g')
  let json = substitute(json, 'null', '""', 'g')
  let json = substitute(json, '\\u34;', '\\"', 'g')
  try
    let json = iconv(substitute(json, '\\u\(\x\x\x\x\)', '\=nr2char("0x".submatch(1), 1)', 'g'), 'utf-8', &enc)
  catch /.*/
    let json = substitute(json, '\\u\(\x\x\x\x\)', '\=s:nr2enc_char("0x".submatch(1))', 'g')
  endtry
  return eval(json)
endfunction

function! s:out(line)
  call setline(line('$')+1, a:line)
endfunction

function! weather#test()
  let g:json = s:decode(system('curl -L -s -k http://weather.livedoor.com/forecast/webservice/json/v1?city=110010'))
endfunction

function! weather#list(A, L, P)
  let items = []
  for item in g:weather#city_list
    if !has_key(item, 'id')
      continue
    endif
    if item.name =~ '^'.a:A
      call add(items, item.name)
    endif
  endfor
  return items
endfunction

function! weather#all(...)
  if !executable('curl')
    echoerr "cURL is not exist. Please install it."
    return
  endif

  if len(a:000) > 0
    let location = filter(copy(g:weather#city_list), 'v:val.name == a:000[0]')
    if len(location) > 0
      call weather#city(location[0].id)
    endif
    return
  endif

  " open window
  call s:open_win()
  let b:weather_win = s:WIN_ALL

  setl modifiable
  % delete _

  let cities = ''
  let first = 1
  for city in g:weather#city_list
    if !has_key(city, 'id')
      if cities != ''
        call s:out('  ' . cities)
        let cities = ''
      endif
      if first == 1
        call setline(1, s:title)
        let first = 0
      else
        call s:out('')
      endif
      call s:out(city.name)
    else
      let cities .= city.name . ' '
    endif
  endfor
  if cities != ''
    call s:out('  ' . cities)
  endif
  call s:out('')

  setl nomodifiable
  call cursor(b:cline[s:WIN_ALL], 3)

endfunction

function! weather#city(city)
  " request
  try
    let json = s:decode(system('curl -L -s -k http://weather.livedoor.com/forecast/webservice/json/v1?city=' . a:city))
  catch /.*/
    echoerr "get weather data error."
    return
  endtry

  if len(json.forecasts) < 3
    call add(json.forecasts, {'date':'', 'dateLabel':'', 'telop':'', 'temperature':{}})
  endif

  " open window
  call s:open_win()
  let b:weather_win = s:WIN_CITY
  setl modifiable
  % delete _

  " title
  call setline(1, s:title)

  " weather
  call s:out(printf('| (%10s)  | (%10s)  | (%10s)  | %s',    json.forecasts[0].date, json.forecasts[1].date, json.forecasts[2].date, json.location.area))
  call s:out(printf('| %-10s    | %-10s    | %-10s    | %s', json.forecasts[0].dateLabel, json.forecasts[1].dateLabel, json.forecasts[2].dateLabel, json.location.prefecture))
  call s:out(printf('| %-10s    | %-10s    | %-10s    | %s', json.forecasts[0].telop, json.forecasts[1].telop, json.forecasts[2].telop, json.location.city))
  let templ = ''
  for idx in range(len(json.forecasts))
    if has_key(json.forecasts[idx].temperature, 'min')
      try
        let templ .= printf('| %-10s    ', json.forecasts[idx].temperature.min.celsius . ' �` ' . json.forecasts[idx].temperature.max.celsius . '��')
      catch /.*/
        let templ .= '|               '
      endtry
    else
      let templ .= '|               '
    endif
  endfor
  call s:out(templ . '| ')

  " �ڍ�
  call s:out('---------------------------------------------------------------')
  call s:out(map(split(json.description.text, '�B \{0,1\}'), 'v:val . "�B"'))
  call s:out('')
  call s:out(s:toAll)
  call s:out('')

  " copyright
  call s:out('---------------------------------------------------------------')
  call s:out(json.copyright.title)
  call s:out(json.copyright.provider[0].name . ' ' . json.copyright.provider[0].link)
  call s:out('')
  setl nomodifiable

  let s:locations = json.pinpointLocations
endfunction

function! s:open_win()
  if !exists('b:weather_win')
    new
    silent edit weather
    setl bt=nofile noswf wrap hidden nolist nomodifiable ft=weather
    nnoremap <buffer><Plug>(weather-click) :<C-u>call weather#click()<CR>
    nnoremap <buffer><Plug>(weather-back) :<C-u>call weather#back()<CR>
    nmap <buffer><CR> <Plug>(weather-click)
    nmap <buffer><BS> <Plug>(weather-back)
    let b:weather_win = 0
    let b:cline = [0, 0]
  endif
endfunction

function! weather#click()
  let word = expand('<cWORD>')
  let b:cline[b:weather_win] = line('.')
  if b:weather_win == s:WIN_CITY
    if word == s:toAll
      call weather#all()
    endif
  elseif b:weather_win == s:WIN_ALL
    let location = filter(copy(g:weather#city_list), 'v:val.name == word')
    if len(location) > 0 && has_key(location[0], 'id')
      call weather#city(location[0].id)
    endif
  endif
endfunction

function! weather#back()
  call weather#all()
endfunction

" --- city lit ---

let g:weather#city_list = [
  \ { "name":"���k"},
  \ { "name":"�t��", "id":"011000"},
  \ { "name":"����", "id":"012010"},
  \ { "name":"���G", "id":"012020"},
  \ { "name":"����"},
  \ { "name":"�ԑ�", "id":"013010"},
  \ { "name":"�k��", "id":"013020"},
  \ { "name":"���", "id":"013030"},
  \ { "name":"����", "id":"014010"},
  \ { "name":"���H", "id":"014020"},
  \ { "name":"�эL", "id":"014030"},
  \ { "name":"����"},
  \ { "name":"����", "id":"015010"},
  \ { "name":"�Y��", "id":"015020"},
  \ { "name":"����"},
  \ { "name":"�D�y", "id":"016010"},
  \ { "name":"�〈��", "id":"016020"},
  \ { "name":"��m��", "id":"016030"},
  \ { "name":"����"},
  \ { "name":"����", "id":"017010"},
  \ { "name":"�]��", "id":"017020"},
  \ { "name":"�X��"},
  \ { "name":"�X", "id":"020010"},
  \ { "name":"�ނ�", "id":"020020"},
  \ { "name":"����", "id":"020030"},
  \ { "name":"��茧"},
  \ { "name":"����", "id":"030010"},
  \ { "name":"�{��", "id":"030020"},
  \ { "name":"��D�n", "id":"030030"},
  \ { "name":"�{�錧"},
  \ { "name":"���", "id":"040010"},
  \ { "name":"����", "id":"040020"},
  \ { "name":"�H�c��"},
  \ { "name":"�H�c", "id":"050010"},
  \ { "name":"����", "id":"050020"},
  \ { "name":"�R�`��"},
  \ { "name":"�R�`", "id":"060010"},
  \ { "name":"�đ�", "id":"060020"},
  \ { "name":"��c", "id":"060030"},
  \ { "name":"�V��", "id":"060040"},
  \ { "name":"������"},
  \ { "name":"����", "id":"070010"},
  \ { "name":"�����l", "id":"070020"},
  \ { "name":"�ᏼ", "id":"070030"},
  \ { "name":"��錧"},
  \ { "name":"����", "id":"080010"},
  \ { "name":"�y�Y", "id":"080020"},
  \ { "name":"�Ȗ،�"},
  \ { "name":"�F�s�{", "id":"090010"},
  \ { "name":"��c��", "id":"090020"},
  \ { "name":"�Q�n��"},
  \ { "name":"�O��", "id":"100010"},
  \ { "name":"�݂Ȃ���", "id":"100020"},
  \ { "name":"��ʌ�"},
  \ { "name":"��������", "id":"110010"},
  \ { "name":"�F�J", "id":"110020"},
  \ { "name":"����", "id":"110030"},
  \ { "name":"��t��"},
  \ { "name":"��t", "id":"120010"},
  \ { "name":"���q", "id":"120020"},
  \ { "name":"�َR", "id":"120030"},
  \ { "name":"�����s"},
  \ { "name":"����", "id":"130010"},
  \ { "name":"�哇", "id":"130020"},
  \ { "name":"���䓇", "id":"130030"},
  \ { "name":"����", "id":"130040"},
  \ { "name":"�_�ސ쌧"},
  \ { "name":"���l", "id":"140010"},
  \ { "name":"���c��", "id":"140020"},
  \ { "name":"�V����"},
  \ { "name":"�V��", "id":"150010"},
  \ { "name":"����", "id":"150020"},
  \ { "name":"���c", "id":"150030"},
  \ { "name":"����", "id":"150040"},
  \ { "name":"�x�R��"},
  \ { "name":"�x�R", "id":"160010"},
  \ { "name":"����", "id":"160020"},
  \ { "name":"�ΐ쌧"},
  \ { "name":"����", "id":"170010"},
  \ { "name":"�֓�", "id":"170020"},
  \ { "name":"���䌧"},
  \ { "name":"����", "id":"180010"},
  \ { "name":"�։�", "id":"180020"},
  \ { "name":"�R����"},
  \ { "name":"�b�{", "id":"190010"},
  \ { "name":"�͌���", "id":"190020"},
  \ { "name":"���쌧"},
  \ { "name":"����", "id":"200010"},
  \ { "name":"���{", "id":"200020"},
  \ { "name":"�ѓc", "id":"200030"},
  \ { "name":"�򕌌�"},
  \ { "name":"��", "id":"210010"},
  \ { "name":"���R", "id":"210020"},
  \ { "name":"�É���"},
  \ { "name":"�É�", "id":"220010"},
  \ { "name":"�ԑ�", "id":"220020"},
  \ { "name":"�O��", "id":"220030"},
  \ { "name":"�l��", "id":"220040"},
  \ { "name":"���m��"},
  \ { "name":"���É�", "id":"230010"},
  \ { "name":"�L��", "id":"230020"},
  \ { "name":"�O�d��"},
  \ { "name":"��", "id":"240010"},
  \ { "name":"���h", "id":"240020"},
  \ { "name":"���ꌧ"},
  \ { "name":"���", "id":"250010"},
  \ { "name":"�F��", "id":"250020"},
  \ { "name":"���s�{"},
  \ { "name":"���s", "id":"260010"},
  \ { "name":"����", "id":"260020"},
  \ { "name":"���{"},
  \ { "name":"���", "id":"270000"},
  \ { "name":"���Ɍ�"},
  \ { "name":"�_��", "id":"280010"},
  \ { "name":"�L��", "id":"280020"},
  \ { "name":"�ޗǌ�"},
  \ { "name":"�ޗ�", "id":"290010"},
  \ { "name":"����", "id":"290020"},
  \ { "name":"�a�̎R��"},
  \ { "name":"�a�̎R", "id":"300010"},
  \ { "name":"����", "id":"300020"},
  \ { "name":"���挧"},
  \ { "name":"����", "id":"310010"},
  \ { "name":"�Ďq", "id":"310020"},
  \ { "name":"������"},
  \ { "name":"���]", "id":"320010"},
  \ { "name":"�l�c", "id":"320020"},
  \ { "name":"����", "id":"320030"},
  \ { "name":"���R��"},
  \ { "name":"���R", "id":"330010"},
  \ { "name":"�ÎR", "id":"330020"},
  \ { "name":"�L����"},
  \ { "name":"�L��", "id":"340010"},
  \ { "name":"����", "id":"340020"},
  \ { "name":"�R����"},
  \ { "name":"����", "id":"350010"},
  \ { "name":"�R��", "id":"350020"},
  \ { "name":"����", "id":"350030"},
  \ { "name":"��", "id":"350040"},
  \ { "name":"������"},
  \ { "name":"����", "id":"360010"},
  \ { "name":"���a��", "id":"360020"},
  \ { "name":"���쌧"},
  \ { "name":"����", "id":"370000"},
  \ { "name":"���Q��"},
  \ { "name":"���R", "id":"380010"},
  \ { "name":"�V���l", "id":"380020"},
  \ { "name":"�F�a��", "id":"380030"},
  \ { "name":"���m��"},
  \ { "name":"���m", "id":"390010"},
  \ { "name":"���˖�", "id":"390020"},
  \ { "name":"����", "id":"390030"},
  \ { "name":"������"},
  \ { "name":"����", "id":"400010"},
  \ { "name":"����", "id":"400020"},
  \ { "name":"�ђ�", "id":"400030"},
  \ { "name":"�v����", "id":"400040"},
  \ { "name":"���ꌧ"},
  \ { "name":"����", "id":"410010"},
  \ { "name":"�ɖ���", "id":"410020"},
  \ { "name":"���茧"},
  \ { "name":"����", "id":"420010"},
  \ { "name":"������", "id":"420020"},
  \ { "name":"����", "id":"420030"},
  \ { "name":"���]", "id":"420040"},
  \ { "name":"�F�{��"},
  \ { "name":"�F�{", "id":"430010"},
  \ { "name":"���h���P", "id":"430020"},
  \ { "name":"���[", "id":"430030"},
  \ { "name":"�l�g", "id":"430040"},
  \ { "name":"�啪��"},
  \ { "name":"�啪", "id":"440010"},
  \ { "name":"����", "id":"440020"},
  \ { "name":"���c", "id":"440030"},
  \ { "name":"����", "id":"440040"},
  \ { "name":"�{�茧"},
  \ { "name":"�{��", "id":"450010"},
  \ { "name":"����", "id":"450020"},
  \ { "name":"�s��", "id":"450030"},
  \ { "name":"�����", "id":"450040"},
  \ { "name":"��������"},
  \ { "name":"������", "id":"460010"},
  \ { "name":"����", "id":"460020"},
  \ { "name":"��q��", "id":"460030"},
  \ { "name":"����", "id":"460040"},
  \ { "name":"���ꌧ"},
  \ { "name":"�ߔe", "id":"471010"},
  \ { "name":"����", "id":"471020"},
  \ { "name":"�v�ē�", "id":"471030"},
  \ { "name":"��哌", "id":"472000"},
  \ { "name":"�{�Ó�", "id":"473000"},
  \ { "name":"�Ί_��", "id":"474010"},
  \ { "name":"�^�ߍ���", "id":"474020"},
  \ ]

