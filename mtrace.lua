-- Usage: 

-- input: *.meta_rob.log
-- output: 

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local g_cid = 0

function micro(m)   
   if m.op == "L" then
      io.write('"R ' ..string.format('0x%08x', m.i).. ' ' .. g_cid .. ' ' .. m.pc .. '",')
   elseif m.op == "S" then
      io.write('"W ' ..string.format('0x%08x', m.o).. ' ' .. g_cid .. ' ' .. m.pc .. '",')
   end
end

function begin_sb(sb)
   g_cid = sb.cid
   io.write("{")
end

function end_sb()
   io.write("}, ")
end

function begin_issue(issue)   
   io.write('issue {')
end

function end_issue()
   print('}')
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
