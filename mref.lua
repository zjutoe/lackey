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

local r = ffi.new("d4memref")

local miss_delay = 4
local core_num = 4

local clkcount = 0
local addr, current_core = 0, 1
local icount_sb = 0
local accesstype, daddr, dsize
local misscnt_sb = 0

local core = {}
for i=1, core_num do
   core[i] = {icount = 0, delay_count = 0, clk_pend = 0, ref_count = 0}
   d4lua.do_cache_init(i);
end

function micro(m)
   
   if m.op == "L" then
      r.accesstype = 0
      r.address = m.i
   else
      r.accesstype = 1
      r.address = m.o
   end
   r.size = 4
   
   local c = core[current_core]
   
   local miss = d4lua.do_cache_ref(current_core, r)
      
   -- encounter a miss 
   if miss > 0 and m.pc > icount_sb - miss_delay then
      -- print('MISS:', pc, icount_sb, miss)
      misscnt_sb = misscnt_sb + miss
   end
end

function begin_sb(sb)
   current_core = sb.core
   icount_sb = sb.weight
end

function end_sb()
   -- summarize the current SB
   local c = core[current_core]
   c.icount = c.icount + icount_sb
   c.delay_count = c.delay_count  + misscnt_sb * miss_delay
   c.clk_pend = c.clk_pend + icount_sb  + misscnt_sb * miss_delay
end

function begin_issue(issue)
   
end

function end_issue()
   -- a line of blocks get issued
   local max_clk = 0
   -- io.write("EXE ")
   for _, c in ipairs(core) do
      if max_clk < c.clk_pend then max_clk = c.clk_pend end
      -- io.write(string.format("%d ", c.clk_pend))
      c.clk_pend = 0
   end
   clkcount = clkcount + max_clk
end

function summary()
   local icount, delaycount = 0, 0

   for k, v in pairs(core) do
      icount = icount + v.icount
      delaycount = delaycount + v.delay_count
   end
   print(string.format("executed %d insts in %d clks: CPI=", icount, clkcount), clkcount/icount)
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

summary()
