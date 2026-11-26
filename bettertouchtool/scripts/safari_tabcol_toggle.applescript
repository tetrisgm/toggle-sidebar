-- Safari vertical tabs: the tab column is "splitter 2" of the window's split group; its value is the column width.
-- Below ~53 px Safari shows the icon-only strip. The last expanded width is kept in ~/.config/safari-tabcol-width.
set f to (POSIX path of (path to home folder)) & ".config/safari-tabcol-width"
tell application "System Events" to tell process "Safari"
 set s to splitter 2 of splitter group 1 of window 1
 set v to (value of s) as real
 if v > 80 then
  do shell script "printf %s " & (round v) & " > " & quoted form of f
  set value of s to 40
 else
  set w to 210
  try
   set w to (do shell script "cat " & quoted form of f) as integer
  end try
  if w < 120 then set w to 210
  set value of s to w
 end if
end tell
