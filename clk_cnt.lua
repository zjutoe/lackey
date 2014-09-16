local miss_delay = 4

function clk_add_delay(f_rob_exe_log, 
		       f_miss_log1, 
		       f_miss_log2,
		       f_miss_log3, 
		       f_miss_log4)

   local rob_exe_log = assert(io.open(f_rob_exe_log, "r"))

   local miss_log = {}
   miss_log[1] = assert(io.open(f_miss_log1, "r"))
   miss_log[2] = assert(io.open(f_miss_log2, "r"))
   miss_log[3] = assert(io.open(f_miss_log3, "r"))
   miss_log[4] = assert(io.open(f_miss_log4, "r"))

   local clkcount = 0
   local addr, current_core = 0, 1
   local icount_sb = 0
   local accesstype, daddr, dsize
   local misscnt_sb = 0
   local core = {}
   core[1] = {icount = 0, delay_count = 0, clk_pend = 0}
   core[2] = {icount = 0, delay_count = 0, clk_pend = 0}
   core[3] = {icount = 0, delay_count = 0, clk_pend = 0}
   core[4] = {icount = 0, delay_count = 0, clk_pend = 0}

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
	    addr, current_core, _icount = string.match(line:sub(4), "(%d+) (%d+) (%d+)")
	    icount_sb = tonumber(_icount)
	 else
	    -- now it is a memory reference, let's check the miss log
	    -- and see how much latency it causes
	    print("access by core", current_core)
	    local mlog = miss_log[tonumber(current_core)]
	    local miss_record = mlog:read("*line")
	    while miss_record:sub(1,4) ~= "miss" do
	        miss_record = mlog:read("*line")
	    end
	    misscnt_sb = misscnt_sb + tonumber(miss_record:sub(6))
	 end
      end
      
   end				-- for exe in rob_exe_log.lines()

   local icount, delaycount

   for k, v in pairs(core) do
      icount = icount + v.icount
      delaycount = delaycount + v.delay_count
   end
   print(string.format("executed %d insts in %d clks", icount, clkcount))   

end

clk_add_delay("./test/date_rob.log", "./test/cpu1.dinero", "./test/cpu2.dinero", "./test/cpu3.dinero", "./test/cpu4.dinero")

