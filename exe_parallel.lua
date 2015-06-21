-- Usage: 

-- input: *.meta_rob.log
-- output: 

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local logd = print
-- local logd = function(...) end

require("ca_swb")
local spec_read_record = { read = {}, kill = {} }

local Core = require("core")

local NUM_CORE = 4
local cores = {}
for cid = 1, NUM_CORE do
   cores[cid] = Core:new{id = cid, swb = SWB, srr = spec_read_record,
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
   -- execute all cores in Round-Robin
   local leading_core = 1
   repeat
      logd('----')
      local exe_end = true
      for cid = 1, NUM_CORE do
	 local c = cores[cid]
	 if c.active then
	    -- only the 1st active core is non-speculative
	    local spec = cid ~= leading_core
	    c:exe_inst(spec)

	    -- at least we had one active core
	    exe_end = false
	 end

	 -- the leading core c finishes exeuction, commit it.
	 -- FIXME we could commit it earlier, e.g. when the
	 -- predecessor finishes, the current core could commit all
	 -- its earlier output.
	 if cid == leading_core and not c.active then
	    SWB:commit(cid)
	    leading_core = leading_core + 1
	 end
      end

      logd('srr:')
      for cid, _ in pairs(spec_read_record.kill) do
	 logd('  ', cid, _)
      end
      -- in case a predecessor writes to an addr, which a successor
      -- speculatively read, the successor should be killed (discard
      -- its execution results and context). The spec_read_record.kill
      -- is updated in core.lua
      for cid, _ in pairs(spec_read_record.kill) do
	 -- invalidate/reset the core
	 -- Discard all the core[cid] output in SWB
	 SWB:discard(cid)
	 cores[cid].iidx = 1
	 cores[cid].active = true

	 -- now we have more active cores
	 exe_end = false
      end
      spec_read_record.kill = {}
   until exe_end

   spec_read_record.read = {}
   spec_read_record.kill = {}

   SWB:clear_rename_buffer()
   
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
