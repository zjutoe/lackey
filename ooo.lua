#!/usr/bin/env lua

-- OOO (Out Of Order) core simulation

-- input: trace of code block reordering/scheduling, i.e. meta_rob.lua

-- output: trace of code blocks, instructions inside super blocks are
-- reordered


local List = require "list"
require "pepperfish"

function logd(...)
   -- print(...)
end

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

-- the parameters that affects the parallelism 
local core_num = 4
local rob_w = 4
local rob_d = 64
local sb_size = 50
local sb_merge = false
local quit_at = 300000
local reg_sync_delay = 4

for i, v in ipairs(arg) do
   --print(type(v))
   if (v:sub(1,2) == "-c") then
      --print("core number:")
      core_num = tonumber(v:sub(3))
   -- elseif (v:sub(1,2) == "-w") then
   --    --print("ROB width:")
   --    rob_w = tonumber(v:sub(3))
   elseif (v:sub(1,2) == "-d") then
      --print("ROB depth:")
      rob_d = tonumber(v:sub(3))
   elseif (v:sub(1,2) == "-s") then
      --print("minimum superblock size:")
      sb_size = tonumber(v:sub(3))
   elseif (v:sub(1,2) == "-q") then
      --print("minimum superblock size:")
      quit_at = tonumber(v:sub(3))
   elseif (v:sub(1,2) == "-mg") then
      --print("minimum superblock size:")
      sb_merge = true
   end
end

-- collection of all the buffered sb's, key is the addr, val is the sb
local sbs = {}
local sbs_run = {}

-- re-order buffer that contains the super blocks awaiting for issuing
local rob = {}

function init_rob(rob, MAX, WIDTH)
   -- the rob.buf is a list of list, as each level of the rob shall
   -- contain several sb's that with the same depth
   -- E.g. with MAX=3 and WIDTH=2, it looks like
   -- {{l00,l01},{l10,l11},{l20,l21}}
   rob.buf = List.new()
   rob.MAX = MAX
   rob.WIDTH = WIDTH
end


local inst = {}
-- to record which SB writes to a specific memory address
local mem_writer = {}
-- to record which SB writes to a specific register
local reg_writer = {}
-- the memory access sequence
local mem_access = {}

-- data input of the current SB
local mem_input = {}
local reg_input = {}


local sb_addr = 0
-- the SB on which the current sb depends
local deps = {}
local sb_weight = 0

local reg_out_offset = {}
local reg_in_offset = {}
local reg_io = {}

local blk_seq = 0


function new_issue()
   local issue = {}
   issue.sbs = {}
   return issue
end

function new_sb(addr, core, weight)
   local sb = {}
   sb.addr = addr
   sb.ins = {}
   sb.ins_hash = {}
   sb.core = core
   sb.weight = weight
   sb.micro = {}
   sb.ooo = {}			-- the reorder of the micro
   sb.mref = {}
   sb.m_writer = {}
   sb.t_writer = {}
   sb.g_writer = {}
   sb.dep = {}

   return sb
end

local issue = new_issue()
local sb = new_sb('0', '1', 0)

function log_micro(sb, pc, show_dep)
   show_dep = show_dep or false
   show_pc = show_pc or false

   local micro = sb.micro[pc]
   io.write(micro.flag..' ' .. micro.o)
   if type(micro.i) == 'table' then
      for _, t in ipairs(micro.i) do
	 io.write(' '..t)
      end
   else
      io.write(' ' .. (micro.i or ''))
   end   

   if show_dep and sb.dep[i] then
      io.write(':\t')
      if type(sb.dep[i]) == 'table'	then
	 for _, d in ipairs(sb.dep[i]) do
	    io.write(' '..d)
	 end
      else
	 io.write(' '..sb.dep[i])
      end
   end

   io.write('\n')
end

function log_sb_ooo(sb)
   print(string.format("  begin_sb { addr=0x%08x, core=%d,  weight=%s }", sb.addr, sb.core, #sb.micro))

   for i, v in ipairs(sb.ooo) do
      --io.write(i..': ')
      local mic = sb.micro[v]
      -- log_micro(sb, v)
      if mic.flag == "S" then	 
	 print(string.format("    micro { pc=%d, op='S', i=%s, o=0x%s }", i, mic.i and mic.i:sub(2) or 'nil', mic.o:sub(2)))
      elseif mic.flag == "L" then
	 print(string.format("    micro { pc=%d, op='L', o=%s, i=0x%s }", i, mic.o and mic.o:sub(2) or 'nil', mic.i:sub(2)))
      end
   end

   print('  end_sb()')
end

function log_sb(sb, show_dep)
   print(string.format("SB %s", sb.core, #sb.micro))

   for i, v in ipairs(sb.micro) do
      log_micro(sb, i, show_dep)
   end

end

function mark_dep(sb, pc, mark)

      local d = sb.dep[pc]
      local q = List.new()
      local stack = List.new()

      while d ~= nil do
	 if type(d) == 'table' then
	    for _, d1 in ipairs(d) do
	       if not mark[d1] then
		  mark[d1] = 1
		  List.pushright(stack, d1)
		  if sb.dep[d1] then List.pushright(q, sb.dep[d1]) end
	       end
	    end
	 else
	    if not mark[d] then
	       mark[d] = 1
	       List.pushright(stack, d)
	       if sb.dep[d] then List.pushright(q, sb.dep[d]) end
	    end
	 end
	 d = List.popleft(q)
      end

      return stack
end

function reorder_sb(sb)
   local mark = {}

   -- TODO: the mrefs are not re-ordered yet. Further optimization may
   -- help.

   for i, v in ipairs(sb.mref) do
      mark[v] = 1
      local stack = mark_dep(sb, v, mark)
      while List.size(stack) > 0 do
	 sb.ooo[#sb.ooo + 1] = List.popright(stack)
      end
      sb.ooo[#sb.ooo + 1] = v
   end

   -- collect the rest (not marked)
   for i, v in ipairs(sb.micro) do
      if not mark[i] then sb.ooo[#sb.ooo + 1] = i end
   end
end

function parse_input(sb_size, sb_merge)
   local i = 0
   local weight_accu = 0

   profiler = newProfiler()
   profiler:start()

   for line in io.lines() do
      if line:sub(1,2) ~= '==' then
	 i = i + 1

	 if line:sub(1,2) == 'SB' then
	    -- print( __LINE__())
	    if sb then
	       issue.sb[#issue.sb + 1] = sb
	    end

	    local addr, core, weight = string.match(line:sub(4), "(%x+) (%d) (%d)")
	    -- print('[D]line/addr', line, tonumber(addr), 16)
	    sb = new_sb(addr, core, weight)
	    
	    -- FIXME make them member of sb, i.e. sb.mem_writer,
	    -- sb.reg_writer
	    mem_writer = {}
	    reg_writer = {}

	 elseif line:sub(1,5) == 'ISSUE' then
	    issue.sb[#issue.sb + 1] = sb
	    sb = nil		-- TODO: end_sb()
	    -- sb = new_sb(addr, core, weight)
	    print(string.format("begin_issue{ num_sb=%d }", #issue.sb))

	    for core, blk in ipairs(issue.sb) do
	       -- log_sb(blk)
	       reorder_sb(blk)
	       log_sb_ooo(blk)
	    end

	    print("end_issue()")
	    -- issue.sb = {}
	    issue = new_issue()

	 else			-- not SB nor ISSUE

	    local pc, k, t, gmt = string.match(line, "(%d+): (%a) (%w+) (%w+)")
	    -- eprint (pc, k, t, gmt)

	    if k == 'S' then
	       -- print( __LINE__())
	       local m = gmt -- local t, m = string.match(line:sub(3), "(%w+) (%w+)")
	       if t == 'T' then t = nil end
	       -- local d_addr = tonumber(m:sub(2), 16)
	       sb.micro[#sb.micro + 1] = {flag='S', i=t, o=m}
	       sb.mref[#sb.mref + 1] = #sb.micro
	       sb.writer[m] = #sb.micro
	       if t ~= nil then sb.dep[#sb.micro] = sb.writer[t] end
	       
	    elseif k == 'L' then
	       -- print( __LINE__())
	       local m = gmt -- local t, m = string.match(line:sub(3), "(%w+) (%w+)")
	       -- local d_addr = tonumber(m:sub(2), 16)
	       sb.micro[#sb.micro + 1] = {flag='L', i=m, o=t}
	       sb.mref[#sb.mref + 1] = #sb.micro
	       if t ~= nil then sb.writer[t] = #sb.micro end
	       sb.dep[#sb.micro] = sb.writer[m]
	       

	    elseif k == 'P' then
	       -- print( __LINE__())
	       local g = gmt -- local t, g = string.match(line:sub(3), "(%w+) (%w+)")
	       if t == 'T' then t = nil end
	       sb.micro[#sb.micro + 1] = {flag='P', i=t, o=g}
	       sb.writer[g] = #sb.micro 
	       if t ~= nil then sb.dep[#sb.micro] = sb.writer[t] end

	    elseif k == 'G' then
	       -- print( __LINE__())
	       local g = gmt -- local t, g = string.match(line:sub(3), "(%w+) (%w+)")
	       -- local reg_o = g:sub(2)
	       sb.micro[#sb.micro + 1] = {flag='G', i=g, o=t}
	       sb.writer[t] = #sb.micro
	       sb.dep[#sb.micro] = sb.writer[g]

	    elseif k == 'OP' then
	       -- print( __LINE__())
	       local b, e = string.find(line, 'T%d+')
	       local d = nil
	       local s = {}
	       if b ~= nil then
		  d = line:sub(b, e)
	       end
	       b, e = string.find(line, 'T%d+', e)
	       while b ~= nil do
		  s[#s + 1] = line:sub(b, e)
		  b, e = string.find(line, 'T%d+', e)
	       end
	       sb.micro[#sb.micro + 1] = {flag='OP', i=s, o=d}

	       if d ~= nil then
		  sb.writer[d] = #sb.micro
	       end
	       if #s > 0 then
		  local dep = {}
		  for i, v in ipairs(s) do
		     dep[#dep + 1] = sb.writer[v]
		  end
		  sb.dep[#sb.micro] = dep
	       end
	    end			-- k == 'OP'
	 end			-- not SB nor ISSUE
      end			-- ~= '=='
   end				-- for ... do

   -- TODO add a switch verbose or terse
   -- logd(i)

   profiler:stop()

   local outfile = io.open( "profile.txt", "w+" )
   profiler:report( outfile )
   outfile:close()

end				--  function parse_lackey_log()

-- print( __LINE__())
rob_w = core_num
-- print( __LINE__())
init_rob(rob, rob_d, rob_w)
-- print( __LINE__())
-- parse_input(sb_size, sb_merge)


function begin_sb(sb_meta)
   -- print(__LINE__())
   -- print(string.format("# sb.addr=0x%08x, cid=%d, weight=%d", sb_meta.addr, sb_meta.cid, sb_meta.weight))
   sb = new_sb(sb_meta.addr, sb_meta.cid, sb_meta.weight)
   
   -- FIXME make them member of sb, i.e. sb.mem_writer,
   -- sb.reg_writer
   mem_writer = {}
   reg_writer = {}
end

function end_sb()
   -- print( __LINE__())
   if sb then
      issue.sbs[#issue.sbs + 1] = sb
   end
end

function begin_issue(issue_meta)
   -- print(__LINE__())
   -- sb = new_sb(addr, core, weight)
   print(string.format("begin_issue{ num_sb=%d }", issue_meta.size))
end

function end_issue()
   -- print(__LINE__())
   -- issue.sbs[#issue.sbs + 1] = sb

   for core, blk in ipairs(issue.sbs) do
      -- log_sb(blk)
      reorder_sb(blk)
      log_sb_ooo(blk)
   end

   print("end_issue()")
   -- issue.sbs = {}
   issue = new_issue()
end

function micro(mic)
   -- print(__LINE__(), mic.pc, mic.op)
   --local pc, k, t, gmt = string.match(line, "(%d+): (%a) (%w+) (%w+)")
   -- print (pc, k, t, gmt)

   sb.micro[#sb.micro + 1] = mic
   local k = mic.op

   if k == 'S' then
      sb.mref[#sb.mref + 1] = #sb.micro
      sb.m_writer[mic.o] = #sb.micro
      if mic.i then sb.dep[#sb.micro] = sb.t_writer[mic.i] end

   elseif k == 'L' then      
      sb.mref[#sb.mref + 1] = #sb.micro
      sb.t_writer[mic.o] = #sb.micro
      sb.dep[#sb.micro] = sb.m_writer[mic.i]      
      
   elseif k == 'P' then
      sb.g_writer[mic.o] = #sb.micro
      if mic.i then sb.dep[#sb.micro] = sb.t_writer[mic.i] end

   elseif k == 'G' then
      sb.t_writer[mic.o] = #sb.micro
      sb.dep[#sb.micro] = sb.g_writer[mic.i]

   elseif k == 'OP' then
      sb.t_writer[mic.o] = #sb.micro
      local dep = {}
      if mic.i ~= nil then
	 for _, d in pairs(mic.i) do
	    dep[#dep + 1] = sb.t_writer[d]
	 end
      end
      sb.dep[#sb.micro] = dep

      -- -- print( __LINE__())
      -- local b, e = string.find(line, 'T%d+')
      -- local d = nil
      -- local s = {}
      -- if b ~= nil then
      -- 	 d = line:sub(b, e)
      -- end
      -- b, e = string.find(line, 'T%d+', e)
      -- while b ~= nil do
      -- 	 s[#s + 1] = line:sub(b, e)
      -- 	 b, e = string.find(line, 'T%d+', e)
      -- end
      -- sb.micro[#sb.micro + 1] = {flag='OP', i=s, o=d}

      -- if d ~= nil then
      -- 	 sb.writer[d] = #sb.micro
      -- end
      -- if #s > 0 then
      -- 	 local dep = {}
      -- 	 for i, v in ipairs(s) do
      -- 	    dep[#dep + 1] = sb.writer[v]
      -- 	 end
      -- 	 sb.dep[#sb.micro] = dep
      -- end
   end			-- k == 'OP'   

end

-- print(__LINE__())

local BUFSIZE = 2^8		-- 32K
local f = io.input(arg[1])	-- open input file
local cc, lc, wc = 0, 0, 0	-- char, line, and word counts
while true do
   -- print(__LINE__())
   local lines, rest = f:read(BUFSIZE, "*line")
   if not lines then break end
   if rest then lines = lines .. rest .. "\n" end

   assert(loadstring(lines))()
end
