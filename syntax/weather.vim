scriptencoding cp932

if version < 700
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match weatherTitle "------------------------  WEATHER-VIM  ------------------------"
syn keyword weatherToday ����
syn keyword weatherTommorow ����
syn keyword weatherDayAfterTommorow �����
syn match weatherSunny   "��"
syn match weatherCloudy  "��"
syn match weatherRain    "�J"
syn match weatherSnow    "��"
syn match weatherThunder "��"
syn match weatherAll     ">>�S��"
syn match weatherDate    "(\d\d\d\d-\d\d-\d\d)"
syn match weatherHL      "---------------------------------------------------------------"

hi default link weatherTitle Function
hi default link weatherToday Title
hi default link weatherTommorow Title
hi default link weatherDayAfterTommorow Title
hi default link weatherSunny Directory
hi default link weatherCloudy Underlined
hi default link weatherThunder Error
hi default link weatherRain Type
hi default link weatherSnow PreProc
hi default link weatherDate Visual
hi default link weatherHL Debug
hi default link weatherAll Underlined

let b:current_syntax = 'weather'
