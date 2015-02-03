-- Usage: 

-- input: *.meta_rob.log
-- output: 

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local g_cid = 0

function micro(m)   
   if m.op == 'L' then
      print (string.format('R 0x%08x %d', m.i, g_cid))
   elseif m.op == 'S' then
      print (string.format('W 0x%08x %d', m.o, g_cid))
   end
end

function begin_sb(sb)
   g_cid = sb.cid - 1
end

function end_sb()
end

function begin_issue(issue)   
end

function end_issue()
end


local BUFSIZE = 2^15		-- 32K
local f = io.input(arg[1])	-- open input file
local cc, lc, wc = 0, 0, 0	-- char, line, and word counts
while true do
   local lines, rest = f:read(BUFSIZE, "*line")
   if not lines then break end
   if rest then lines = lines .. rest .. "\n" end

   assert(loadstring(lines))()
end


