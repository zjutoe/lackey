-- Usage: 
-- refer to exe_parallel.sh

-- input: *.meta_rob.log
-- output: SWB and L1 performance statistics

-- the benefit of SWB (Shared Write Buffer), SRR (Speculative Read
-- Record) and RNB (ReName Buffer). Data to collect:

-- SWB: reduced inter-core data coherence and passing; increased logical capacity (reduced dupilication);
-- SRR + RNB: memory renaming, speculative write & read (avoided stall, i.e. overlapped execution), and other benefits the paper ARB mentioned;


function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

-- local logd = print
local logd = function(...) end

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
local issue_size = 0

function micro(m)
   cores[g_cid]:add_inst(m)
end

function begin_sb(sb)
   g_cid = sb.cid
   cores[g_cid]:reset()
   -- cores[g_cid].active = true
   -- cores[g_cid].iidx = 1
end

function end_sb()
end

function begin_issue(issue)   
   for _, c in ipairs(cores) do
      c.icache = {}
   end
   issue_size = issue.size
end

local sum_cycles = 0
local sum_insts = 0
local sum_cycles_discarded = 0
local sum_spec_read_fail = 0
local sum_spec_read_succ = 0
local sum_load = 0


function end_issue()
   -- execute all cores in Round-Robin
   local leading_core = 1
   local all_committed = false
   local cycles = 0
   local cycles_discarded = 0

   for cid = 1, issue_size do
      sum_insts = sum_insts + cores[cid]:get_blk_size()
   end
   
   repeat
      cycles = cycles + 1
      logd('--para exe--')

      for cid = 1, issue_size do
	 local c = cores[cid]
	 if c.active then
	    -- only the 1st active core is non-speculative
	    local spec = cid ~= leading_core
	    c:exe_inst(spec)
	 end
      end

      -- in case a predecessor writes to an addr, which a successor
      -- speculatively read, the successor should be killed (discard
      -- its execution results and context). The spec_read_record.kill
      -- is updated in core.lua
      for cid, _ in pairs(spec_read_record.kill) do
	 -- invalidate/reset the core
	 -- Discard all the core[cid] output in SWB
	 SWB:discard(cid)
	 local core = cores[cid]
	 cycles_discarded = cycles_discarded + core:get_pc() - 1
	 sum_spec_read_fail = sum_spec_read_fail + core.spec_read_cnt
	 core:reset()

	 -- now we have more active cores
	 exe_end = false
      end
      spec_read_record.kill = {}

      -- the leading core c finishes exeuction, commit it.
      -- TODO we could commit it earlier, e.g. when the
      -- predecessor finishes, the current core could commit all
      -- its earlier output.
      if leading_core <= issue_size and not cores[leading_core].active then
	 SWB:commit(leading_core)
	 if leading_core == issue_size then all_committed = true end
	 leading_core = leading_core + 1
      end
   until all_committed

   for cid = 1, issue_size do
      local c = cores[cid]
      sum_spec_read_succ = sum_spec_read_succ + c.spec_read_cnt
      sum_load = sum_load + c.l_cnt
   end

   spec_read_record.read = {}
   spec_read_record.kill = {}

   SWB:clear_rename_buffer()

   sum_cycles = sum_cycles + cycles
   sum_cycles_discarded = sum_cycles_discarded + cycles_discarded

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
print("insts:cycles:cycles_discarded", sum_insts, sum_cycles, sum_cycles_discarded)
print("load: all/spec_read_succ/spec_read_fail", sum_load, sum_spec_read_succ, sum_spec_read_fail)
