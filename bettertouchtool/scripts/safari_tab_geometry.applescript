-- Writes the position of every tab row in Safari's vertical tab column (front browser window) for edge-sidebar's
-- tab scrubbing, to ~/.config/safari-tab-geometry. One line per tab, in Safari's tab order: "x y width height"
-- in screen points (origin top left).
set f to (POSIX path of (path to home folder)) & ".config/safari-tab-geometry"
set o to ""
tell application "System Events" to tell process "Safari"
 repeat with win in windows
  try
   set g to UI element 2 of splitter group 1 of win
   set ps to position of every UI element of g
   set ss to size of every UI element of g
   repeat with i from 1 to count of ps
    set p to item i of ps
    set s to item i of ss
    set o to o & ((item 1 of p) as integer) & " " & ((item 2 of p) as integer) & " " & ((item 1 of s) as integer) & " " & ((item 2 of s) as integer) & linefeed
   end repeat
   exit repeat
  end try
 end repeat
end tell
do shell script "printf %s " & quoted form of o & " > " & quoted form of f
