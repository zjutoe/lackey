require ("ca_swb")

-- local Core = {}

-- for i=1, 4 do
--    Core[i] = 
-- end

-- local cores = {
--    [1] = {cid=1,pc=0},
--    [2] = {cid=2,pc=0},
--    [3] = {cid=3,pc=0},
--    [4] = {cid=4,pc=0},
-- }

-- function block_proceed()
   
-- end

local Core = require("core")

local NUM_CORE = 4
local cores = {}
for cid = 1, NUM_CORE do
   cores[cid] = Core:new{id = cid, swb = SWB, L1_cache = ls_cache_list}
end


function issue(blks)
   -- assume the blks are sequentially (with core id) organized
   for cid, blk in ipairs(blks) do
      cores[cid]:issue_code_block(blk)
   end

   local pc = 0
   -- the leading core is non-speculative
   cores[1].spec = false
   -- now execute the blocks until all cores finish
   local finished = false
   while not finished do
      for cid = 1, #blks do
	 finished = true
	 local core = cores[cid]
	 if core.active then
	    local new_pc = core:proceed()
	    if pc < new_pc then pc = new_pc end
	    if core.active then finished = false end
	 end
      end
   end
end



local delay_cnt, access_cnt = 0,0

-- function issue(iss)
--    local max_b_sz = 0
--    for _, b in ipairs(iss) do
--       if max_b_sz < #b then max_b_sz = #b end
--    end
   
--    for i = 1, max_b_sz do
--       local delay, hit
--       -- round robin with the cores, to simulate the parallel execution
--       for _, b in ipairs(iss) do
-- 	 line = b[i]
-- 	 if line then	 	-- if not nil
-- 	    local rw, addr, cid = string.match(line, "(%a) 0x(%x+) (%d)")
-- 	    logd (line, rw, addr, cid)
-- 	    delay = 0
-- 	    local L1 = l1_cache_list[tonumber(cid)]
-- 	    if rw == 'W' then
-- 	       logd("---W----")
-- 	       delay, hit = SWB:write(tonumber(addr, 16), 0, tonumber(cid))
-- 	       logd("---W----")
-- 	    elseif rw == 'R' then
-- 	       logd("---R----")
-- 	       delay, hit = SWB:read(tonumber(addr, 16), tonumber(cid)) 
-- 	       if not hit then
-- 		  delay = L1:read(tonumber(addr, 16), tonumber(cid))	  
-- 	       end
-- 	       -- issue a read to L1 anyway, but do not count in the delay
-- 	       L1:read(tonumber(addr, 16), tonumber(cid))
-- 	       logd("---R----")
-- 	    end
	    
-- 	    logd('delay', delay)
-- 	    if rw == 'W' or rw == 'R' then
-- 	       delay_cnt = delay_cnt + delay
-- 	       access_cnt = access_cnt + 1
-- 	    end
-- 	 end
--       end
--    end
-- end

local BUFSIZE = 2^15		-- 32K
local f = io.input(arg[1])	-- open input file

while true do
   local lines, rest = f:read(BUFSIZE, "*line")
   if not lines then break end
   if rest then lines = lines .. rest .. "\n" end

   assert(loadstring(lines))()
end

local read_hit_total, read_miss_total, write_hit_total, write_miss_total, clk_total = 0,0,0,0,0

function summarize(cache_list)
   for _, c in pairs(cache_list) do
      c:print_summary()

      read_hit_total = read_hit_total + c.read_hit
      read_miss_total = read_miss_total + c.read_miss
      write_hit_total = write_hit_total + c.write_hit
      write_miss_total = write_miss_total + c.write_miss
      clk_total = clk_total + c._clk
   end
end

clist = {}
for k, v in pairs(l1_cache_list) do
   clist[#clist + 1] = v
end
clist[#clist + 1] = SWB
-- clist[#clist + 1] = L2

summarize(clist)

print("Total read hit/miss:", read_hit_total, read_miss_total, "hit rate:", read_hit_total / (read_hit_total + read_miss_total))
print("Total write hit/miss:", write_hit_total, write_miss_total, "hit rate:", write_hit_total / (write_hit_total + write_miss_total))
print("Total clk/access:", clk_total, read_hit_total + write_hit_total, clk_total/(read_hit_total + write_hit_total))
print("Delay/Access:", delay_cnt, access_cnt, delay_cnt/access_cnt)
print("Inter Core Share/Access:", SWB.inter_core_share, SWB.inter_core_share_captured,
      SWB.inter_core_share / access_cnt,
      SWB.inter_core_share_captured / access_cnt)
