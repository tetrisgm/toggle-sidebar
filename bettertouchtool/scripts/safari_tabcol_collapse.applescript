-- Safari vertical tabs: collapse the tab column of every Safari window to the icon strip.
-- The last expanded width (front window) is kept in ~/.config/safari-tabcol-width for the expand script.
set f to (POSIX path of (path to home folder)) & ".config/safari-tabcol-width"
tell application "System Events" to tell process "Safari"
 repeat with w in windows
  try
   set s to splitter 2 of splitter group 1 of w
   set v to (value of s) as real
   if v > 80 then
    do shell script "printf %s " & (round v) & " > " & quoted form of f
    set value of s to 40
   end if
  end try
 end repeat
end tell
