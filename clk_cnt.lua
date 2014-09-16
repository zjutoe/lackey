function clk_add_delay(f_rob_exe_log, 
		       f_miss_log1, 
		       f_miss_log2,
		       f_miss_log3, 
		       f_miss_log4)

   local rob_exe_log = assert(io.open(f_rob_exe_log, "r"))
   local miss_logs = {}
   miss_log['1'] = assert(io.open(f_miss_log1, "r"))
   miss_log['2'] = assert(io.open(f_miss_log2, "r"))
   miss_log['3'] = assert(io.open(f_miss_log3, "r"))
   miss_log['4'] = assert(io.open(f_miss_log4, "r"))     
   

   local addr, current_core
   local icount = 0
   local accesstype, daddr, dsize
   local misscnt = 0
   local core = {}
   core['1'] = {clk_pend = 0, delay_pend = 0}

   for exe in rob_exe_log.lines() do
      if line:sub(1,2) ~= "#" then	 
	 if line:sub(1,5) == "ISSUE" then
	    -- a line of blocks get issued
	 elseif line:sub(1,2) == "SB" then
	    local c = core[current_core]
	    c.icount = c.icount + icount
	    c.clk_pend = c.clk_pend + icount
	    c.depay_pend = c.depay_pend + misscnt
	    
	    addr, current_core, _icount = string.match(line:sub(4), "(%d+) (%d+) (%d+)")
	    icount = tonumber(_icount)
	 else
	    -- now it is a memory reference, let check the miss log
	    -- and see how much latency it causes
	    local miss_record = miss_log[current_core].read("*line")
	    while miss_record:sub(1,4) ~= "miss" do
	        miss_record = miss_log[i].read("*line")
	    end
	    misscnt = misscnt + tonumber(miss_record:sub(6))
      end
   end
      
   end
   

end