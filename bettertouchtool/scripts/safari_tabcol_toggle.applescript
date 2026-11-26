-- Safari vertical tabs: the tab column is "splitter 2" of a browser window's split group; its value is the column width.
-- Below ~53 px Safari shows the icon-only strip. The last expanded width is kept in ~/.config/safari-tabcol-width.
-- "window 1" is not always the browser window (a tab preview or popover can be in front), so every window is tried.
set f to (POSIX path of (path to home folder)) & ".config/safari-tabcol-width"
set w to 210
try
 set w to (do shell script "cat " & quoted form of f) as integer
end try
if w < 120 then set w to 210
tell application "System Events" to tell process "Safari"
 repeat with win in windows
  try
   set s to splitter 2 of splitter group 1 of win
   set v to (value of s) as real
   if v > 80 then
    do shell script "printf %s " & (round v) & " > " & quoted form of f
    set value of s to 40
   else
    set value of s to w
   end if
   exit repeat
  end try
 end repeat
end tell
