-- Usage: 

-- 0. prepare the traces: test/*_rob.log, test/cpu?-dinero. The
-- *_rob.log is the execution trace output by mrb_private_L1.lua, and
-- the cpu?-dinero are output from Dinero, which is invoked by
-- test_cache.sh

-- 1. luajit clk_cnt.lua


local miss_delay = 1

function clk_add_delay(rob_exe_log, miss_log)

   local clkcount = 0
   local addr, current_core = 0, 1
   local icount_sb = 0
   local accesstype, daddr, dsize
   local misscnt_sb = 0

   -- #core = #miss_log
   local core = {}
   for i=1, #miss_log do
      core[i] = {icount = 0, delay_count = 0, clk_pend = 0}
   end

   for line in rob_exe_log:lines() do
      if line:sub(1,2) ~= "#" then	 
	 if line:sub(1,5) == "ISSUE" then
	    -- a line of blocks get issued
	    local max_clk = 0
	    for k, v in pairs(core) do
	       if max_clk < v.clk_pend then max_clk = v.clk_pend end
	       v.clk_pend = 0
	    end
	    clkcount = clkcount + max_clk

	 elseif line:sub(1,2) == "SB" then
	    -- summarize the previous SB 1st
	    local c = core[tonumber(current_core)]
	    c.icount = c.icount + icount_sb
	    c.delay_count = c.delay_count + misscnt_sb * miss_delay
	    c.clk_pend = c.clk_pend + icount_sb + misscnt_sb * miss_delay

	    -- 
	    addr, current_core, _icount = string.match(line:sub(4), "(%x+) (%d+) (%d+)")
	    icount_sb = tonumber(_icount)
	 else
	    -- now it is a memory reference, let's check the miss log
	    -- and see how much latency it causes
	    
	    local mlog = miss_log[tonumber(current_core)]
	    local miss_record = mlog:read("*line")
	    if not miss_record then break end
	    misscnt_sb = misscnt_sb + tonumber(miss_record:sub(6))
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

clk_add_delay(open_traces("./test/date_rob.log", "./test/cpu1.dinero", "./test/cpu2.dinero", "./test/cpu3.dinero", "./test/cpu4.dinero"))

