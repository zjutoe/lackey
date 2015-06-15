-- Usage: 

-- input: *.meta_rob.log
-- output: 

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

-- local logd = print
local logd = function(...) end

require("ca_swb")
local Core = require("core")

local NUM_CORE = 4
local cores = {}
for cid = 1, NUM_CORE do
   cores[cid] = Core:new{id = cid, swb = SWB,
			 L1_cache = SWB.l1_cache_list[cid],
			 icache = {}, iidx = 1}
end

local g_cid = 0

function micro(m)
   cores[g_cid]:add_inst(m)
end

function begin_sb(sb)
   g_cid = sb.cid
   cores[g_cid].active = true
   cores[g_cid].iidx = 1
end

function end_sb()
end

function begin_issue(issue)   
   for _, c in ipairs(cores) do
      c.icache = {}
   end
end

function end_issue()
   -- logd(cores[1].s_cnt, cores[2].s_cnt, cores[3].s_cnt, cores[4].s_cnt)
   -- logd(cores[1].s_exe, cores[2].s_exe, cores[3].s_exe, cores[4].s_exe)
   -- logd(cores[1].l_cnt, cores[2].l_cnt, cores[3].l_cnt, cores[4].l_cnt)

   -- execute all cores in Round-Robin
   repeat 
      local exe_end = true
      local spec = false
      for cid = 1, NUM_CORE do
	 local c = cores[cid]
	 if c.active then
	    c:exe_inst(spec)
	    exe_end = false
	    spec = true		-- only the 1st active core is non-speculative
	 end      
      end
   until exe_end

   -- logd(string.format("%d/%d : %d/%d",
   -- 		      SWB.write_hit, SWB.write_miss,
   -- 		      SWB.read_hit, SWB.read_miss))
end

require "utils"

exec_big_file(arg[1])

local read_hit_total, read_miss_total, write_hit_total, write_miss_total, clk_total = 0,0,0,0,0
local access_cnt = 0

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

access_cnt = read_hit_total + read_miss_total + write_hit_total + write_miss_total

print("Total read hit/miss:", read_hit_total, read_miss_total, "hit rate:", read_hit_total / (read_hit_total + read_miss_total))
print("Total write hit/miss:", write_hit_total, write_miss_total, "hit rate:", write_hit_total / (write_hit_total + write_miss_total))
print("Total clk/access:", clk_total, read_hit_total + write_hit_total, clk_total/(read_hit_total + write_hit_total))
-- print("Delay/Access:", delay_cnt, access_cnt, delay_cnt/access_cnt)
print("Inter Core Share/Access:", SWB.inter_core_share, SWB.inter_core_share_captured,
      SWB.inter_core_share / access_cnt,
      SWB.inter_core_share_captured / access_cnt)
print("Line Duplicate/Access:", SWB.line_dup, access_cnt, SWB.line_dup / access_cnt)
