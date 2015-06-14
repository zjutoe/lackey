-- Usage: 

-- input: *.meta_rob.log
-- output: 

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

require("ca_swb")
local Core = require("core")

local NUM_CORE = 4
local cores = {}
for cid = 1, NUM_CORE do
   cores[cid] = Core:new{id = cid, swb = SWB, L1_cache = ls_cache_list, icache = {}, iidx = 1}
end

local g_cid = 0

function micro(m)
   local icache = cores[g_cid].icache
   icache[#icache + 1] = m
end

function begin_sb(sb)
   g_cid = sb.cid
   cores[g_cid].active = true
end

function end_sb()
end

function begin_issue(issue)   
   for _, c in ipairs(cores) do
      c.icache = {}
   end
end

function end_issue()

   -- execute all cores in round-robin way
   repeat 
      local exe_end = true
      for cid = 1, NUM_CORE do
	 local c = cores[cid]
	 if c.active then
	    c:exe_inst()
	    exe_end = false
	 end      
      end
   until exe_end

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
