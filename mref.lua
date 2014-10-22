-- Usage: 

-- input: *.ooo.log
-- output: 

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

local miss_delay = 4

function exe_blocks(core_num) -- , rob_exe_log, miss_log)

   local clkcount = 0
   local addr, current_core = 0, 1
   local icount_sb = 0
   local accesstype, daddr, dsize
   local misscnt_sb = 0

   local core = {}
   for i=1, core_num do
      core[i] = {icount = 0, delay_count = 0, clk_pend = 0, ref_count = 0}
      d4lua.do_cache_init(i-1);
   end

   for line in io.lines() do
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
	    c.delay_count = c.delay_count  + misscnt_sb * miss_delay
	    c.clk_pend = c.clk_pend + icount_sb  + misscnt_sb * miss_delay

	    -- 
	    _, current_core, _icount = string.match(line:sub(4), "(%x+) (%d+) (%d+)")
	    icount_sb = tonumber(_icount)

	 else
	    local pc, atype, reg, addr = string.match(line, "(%d+): (%a+) (%w+) (%w+)")
	    if atype == 'L' or atype == 'S' then
	       r.accesstype = atype=="L" and 0 or 1 -- L=0, S=1
	       r.address = tonumber(addr:sub(2), 16)
	       r.size = 4
	       
	       local c = core[tonumber(current_core)]
	       
	       local miss = d4lua.do_cache_ref(tonumber(current_core), r)
	    
	       -- encounter a miss 
	       if miss > 0 and tonumber(pc) > icount_sb - miss_delay then
		  -- print('MISS:', pc, icount_sb, miss)
		  misscnt_sb = misscnt_sb + miss
	       end
	    end			-- atype == 'L' or atype == 'S'

	 end
      end
      
   end				-- for line in io.lines()

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
-- exe_blocks(4, open_traces("./date.ooo.log"))
-- exe_blocks(4, open_traces(arg[1], arg[2], arg[3], arg[4], arg[5]))

-- exe_blocks(4)


function micro(m)
--   if atype == 'L' or atype == 'S' then
      r.accesstype = m.op == "L" and 0 or 1 -- L=0, S=1
      r.address = m.addr
      r.size = 4
      
      local c = core[tonumber(current_core)]
      
      local miss = d4lua.do_cache_ref(tonumber(current_core), r)
      
      -- encounter a miss 
      if miss > 0 and tonumber(pc) > icount_sb - miss_delay then
	 -- print('MISS:', pc, icount_sb, miss)
	 misscnt_sb = misscnt_sb + miss
      end
--   end			-- atype == 'L' or atype == 'S'   
end

function begin_sb(sb)
   current_core = sb.core
   icount_sb = sb.weight
end

function end_sb()
   -- summarize the current SB
   local c = core[tonumber(current_core)]
   c.icount = c.icount + icount_sb
   c.delay_count = c.delay_count  + misscnt_sb * miss_delay
   c.clk_pend = c.clk_pend + icount_sb  + misscnt_sb * miss_delay
end

function begin_issue(issue)
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
end
