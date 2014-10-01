-- Usage: 

-- 0. prepare the traces: test/*_rob.log, test/cpu?-dinero. The
-- *_rob.log is the execution trace output by mrb_private_L1.lua, and
-- the cpu?-dinero are output from Dinero, which is invoked by
-- test_cache.sh

-- 1. luajit clk_cnt.lua

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local ffi = require 'ffi'

ffi.cdef[[

      typedef struct {
	 unsigned int	address;
	 char		accesstype;
	 unsigned short	size;		/* of memory referenced, in bytes */
      } d4memref;

      int do_cache_init(int core_id);
      int do_cache_ref(int core_id, d4memref r);
]]

d4lua = ffi.load('../../DineroIV/d4-7/libd4lua.so')

d4lua.do_cache_init(1)
d4lua.do_cache_init(2)
d4lua.do_cache_init(3)
d4lua.do_cache_init(4)

-- d4lua.do_cache_init()

local r = ffi.new("d4memref")

local miss_delay = 1

function exe_blocks(core_num, rob_exe_log, miss_log)

   local clkcount = 0
   local addr, current_core = 0, 1
   local icount_sb = 0
   local accesstype, daddr, dsize
   local misscnt_sb = 0

   -- #core = #miss_log
   local core = {}
   for i=1, core_num do
      print("toe i=", i)
      core[i] = {icount = 0, delay_count = 0, clk_pend = 0, ref_count = 0}
      print("toe", __LINE__())
      d4lua.do_cache_init(i-1);
   end

   for line in rob_exe_log:lines() do
      if line:sub(1,2) ~= "#" then	 
	 if line:sub(1,5) == "ISSUE" then
	    -- a line of blocks get issued
	    local max_clk = 0
	    -- io.write("EXE ")
	    for _, c in ipairs(core) do
	       if max_clk < c.clk_pend then max_clk = c.clk_pend end
	       -- io.write(string.format("%d ", c.clk_pend))
	       c.clk_pend = 0
	    end
	    clkcount = clkcount + max_clk
	    -- print(' CLK', max_clk)

	 elseif line:sub(1,2) == "SB" then
	    -- summarize the previous SB 1st
	    local c = core[tonumber(current_core)]
	    c.icount = c.icount + icount_sb
	    c.delay_count = c.delay_count + misscnt_sb * miss_delay
	    c.clk_pend = c.clk_pend + icount_sb + misscnt_sb * miss_delay

	    -- 
	    addr, current_core, _icount = string.match(line:sub(4), "(%x+) (%d+) (%d+)")
	    icount_sb = tonumber(_icount)

	 elseif line:sub(1,3) == "MEM" then
	    accesstype, daddr = string.match(line:sub(5), "(%d) (%x+)")
	    r.accesstype = tonumber(accesstype)
	    r.address = tonumber(daddr, 16)
	    r.size = 4
	    
	    local c = core[tonumber(current_core)]
	    
	    local miss = d4lua.do_cache_ref(tonumber(current_core), r)
	    
	    if miss > 0 then
	       misscnt_sb = misscnt_sb + miss
	    end

	    -- elseif miss_log and #miss_log > 0 then
	    --    -- now it is a memory reference, let's check the miss log
	    --    -- and see how much latency it causes
	    
	    --    local mlog = miss_log[tonumber(current_core)]
	    --    local miss_record = mlog:read("*line")
	    --    if not miss_record then break end
	    --    misscnt_sb = misscnt_sb + tonumber(miss_record:sub(6))
	 end
      end
      
   end				-- for exe in rob_exe_log.lines()

   local icount, delaycount = 0, 0

   for k, v in pairs(core) do
      icount = icount + v.icount
      delaycount = delaycount + v.delay_count
   end
   print(string.format("executed %d insts in %d clks: CPI=", icount, clkcount), clkcount/icount)   

end



function open_traces(sched, ...)
   local _sched = assert(io.open(sched, "r"))
   
   local _mref = {}
   for i, v in ipairs{...} do
      _mref[i] = assert(io.open(v, "r"))
   end

   return _sched, _mref
end

-- clk_add_delay(4, open_traces("./test/date_rob.log", "./test/cpu1.dinero", "./test/cpu2.dinero", "./test/cpu3.dinero", "./test/cpu4.dinero"))
exe_blocks(4, open_traces("./date.meta_rob.log"))
-- exe_blocks(4, open_traces(arg[1], arg[2], arg[3], arg[4], arg[5]))

