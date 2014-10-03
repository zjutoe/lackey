#!/usr/bin/env lua

-- OOO (Out Of Order) core simulation

-- input: trace of code block reordering/scheduling, i.e. meta_rob.lua

-- output: trace of code blocks, instructions inside super blocks are
-- reordered


local List = require "list"

function logd(...)
   -- print(...)
end

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

-- we are entering a new superblock
function start_sb(addr)
   -- print("SB "..addr)
   sb_addr = addr
end

-- place the superblock in the rob
function place_sb(rob, sb)

   -- the sb should be placed after all of its depending sb's
   local buf = rob.buf
   -- d is the depth, i.e. in which level/line of the rob the sb should be put
   local d = buf.first
   local i = 0
   for k, v in pairs(deps) do
      i = i + 1
      if d <= v.d then d = v.d end
   end

   -- look for a non-full line which can hold the sb
   found_slot = false
   local l
   for i=d+1, buf.last do
      l = buf[i]
      -- if #l < rob.WIDTH then 
      if List.size(l) < rob.WIDTH then
	 found_slot = true 
	 d = i
	 break
      end
   end

   if not found_slot then
      List.pushright(buf, List.new())
      --List.pushright(buf, {})
      d = buf.last
      l = buf[d]
   end

   -- place the sb in the proper level of the rob
   sb['d'] = d 
   -- l[#l + 1] = sb		-- the line is a List
   List.pushright(l, sb)
   logd('place:', sb.addr, d)

end				-- function place_sb(rob, sb)

-- issue a line of sb's from the rob when necessary
function issue_sb(rob)
   local buf = rob.buf
   -- if List.size(buf) > rob.MAX then
   while List.size(buf) > rob.MAX do
      local l = List.popleft(buf)
      local w_sum = 0
      local w_max = 0
      local width = 0

      -- TODO add a switch verbose or terse
      print('ISSUE', List.size(l))
      
      local cid = 1
      while List.size(l) > 0 do
	 v = List.popleft(l)
	 --for k, v in ipairs(l) do
	 width = width + 1
	 w_sum = w_sum + v.w
	 if w_max < 0 + v.w then
	    w_max = 0 + v.w
	 end

	 print(string.format('SB %s %d %d', v.addr, cid, v.w))
	 cid = cid + 1

	 for _, ins in ipairs(v.inst) do
	    print(string.format("%s %s", ins.tag, ins.addr))
	 end
	 -- for _, mem_rw in ipairs(v.mem_access) do
	 --    print(string.format('MEM %d %x', mem_rw.type, mem_rw.addr))
	 -- end	 

	 sbs_run[v.addr] = sbs[v.addr]
	 sbs[v.addr] = nil
      end      

      -- TODO add a switch verbose or terse
      -- logd(Core.clocks, w_sum, w_max, width, w_sum/w_max)
   end
end


-- the current superblock ends, we'll analyze it here
function end_sb()
   -- build the superblock
   local sb = {}

   sb.seq = blk_seq
   blk_seq = blk_seq + 1

   sb['inst'] = inst
   sb['addr'] = sb_addr
   sb['w'] = sb_weight
   sb['deps'] = deps
   sb['mem_access'] = mem_access

   local dep_mem_cnt, dep_reg_cnt = 0, 0
   for k, v in pairs(mem_input) do
      dep_mem_cnt = dep_mem_cnt + v
   end
   for k, v in pairs(reg_input) do
      dep_reg_cnt = dep_reg_cnt + v
   end   

   sb.dep_mem_cnt = dep_mem_cnt
   sb.dep_reg_cnt = dep_reg_cnt

   sb.reg_out_offset = reg_out_offset
   sb.reg_in_offset = reg_in_offset
   sb.reg_io = reg_io

   sbs[sb_addr] = sb
   -- io.write(sb_addr.."<=")
   -- for k, v in pairs(deps) do
   --    io.write(k.." ")
   -- end
   -- print(' M:'..dep_mem_cnt..' R:'..dep_reg_cnt)
   place_sb(rob, sb)
   issue_sb(rob)

   -- FIXME do this in the init_sb()
   inst = {}
   deps = {}
   mem_input = {}
   mem_access = {}
   reg_input = {}
   reg_out_offset = {}
   reg_in_offset = {}
   reg_io = {}

end				-- function end_sb()

-- the table deps is a set, we use addr as key, so searching it is
-- efficient
function add_depended(addr)
   deps[addr] = sbs[addr]
   -- print('add_depended:', addr)
end

function set_sb_weight(w)
   sb_weight = w
end

local issue = {}
issue.sb = {}

local sb = {}
sb.addr = 0
sb.ins = {}
sb.ins_hash = {}

-- local ins = {}
-- ins.addr = 0
-- ins.mref = {}
-- ins.dep = {}
-- ins.tag = 0			-- nil
-- ins.ops = {}

function new_ins(addr)
   local ins = {}
   ins.mref = {}
   ins.dep = {}
   ins.addr = addr
   ins.ops = {}
   return ins
end

local ins = new_ins(0)

-- recursively traverse all the dependees of ins, and mark them (if
-- not previously marked yet)
function mark_deps(sb, ins)
   local q = List.new()
   for _, d in ipairs(ins.dep) do
      List.pushright(q, d)
   end

   while List.size(q) > 0 do
      local d = List.popleft(q)
      local dep_ins = sb.ins_hash[d]
      if dep_ins and not dep_ins.mark then -- dep_ins.mark == nil
	 dep_ins.mark = 1

	 for _, dep in ipairs(dep_ins.dep) do --  recursion
	    List.pushright(q, dep)
	 end
      end
   end
end

function copy_marked_deps(sb, ins_ooo)
   for _, ins in ipairs(sb.ins) do
      if ins.mark and ins.mark == 1 then
	 ins_ooo[#ins_ooo + 1] = ins
	 ins.mark = 0
      end
   end
end

function parse_input(sb_size, sb_merge)
   local i = 0
   local weight_accu = 0
   for line in io.lines() do
      if line:sub(1,2) ~= '==' then
	 i = i + 1
	 local k = line:sub(1,2)
	 
	 if k == 'SB' then
	    issue.sb[#issue.sb + 1] = sb

	    local addr, core, weight = string.match(line:sub(4), "(%x+) (%d) (%d)")
	    -- print('[D]line/addr', line, tonumber(addr), 16)
	    sb = {}	    
	    sb.addr = tonumber(addr, 16)
	    sb.ins = {}
	    sb.ins_hash = {}
	    
	    -- FIXME make them member of sb, i.e. sb.mem_writer,
	    -- sb.reg_writer
	    mem_writer = {}
	    reg_writer = {}

	    -- assume the SB also starts an ins
	    sb.ins[#sb.ins + 1] = ins
	    sb.ins_hash[ins.addr] = ins

	    -- ins = {}
	    -- ins.mref = {}
	    -- ins.dep = {}
	    -- ins.addr = tonumber(addr, 16)
	    -- ins.ops = {}
	    ins = new_ins(tonumber(addr,16))

	 elseif k == 'I ' then
	    local addr = line:sub(3)

	    sb.ins[#sb.ins + 1] = ins
	    sb.ins_hash[ins.addr] = ins

	    -- ins = {}
	    -- ins.mref = {}
	    -- ins.dep = {}
	    -- ins.addr = tonumber(addr, 16)
	    -- ins.ops = {}
	    ins = new_ins(tonumber(addr,16))

	 elseif k == 'S ' then
	    local addr = tonumber(line:sub(3), 16)
	    ins.mref[#ins.mref + 1] = {flag='S', addr=addr}
	    mem_writer[addr] = ins.addr
	    ins.ops[#ins.ops + 1] = {flag='S', addr=line:sub(3)}

	 elseif k == 'L ' then
	    local addr = tonumber(line:sub(3), 16)
	    ins.mref[#ins.mref + 1] = {flag='L', addr=addr}
	    local dep_addr = mem_writer[addr]
	    if dep_addr and dep_addr ~= ins.addr then
	       ins.dep[#ins.dep + 1] = dep_addr
	    end
	    ins.ops[#ins.ops + 1] = {flag='L', addr=line:sub(3)}

	 elseif k == 'P ' then
	    local addr = tonumber(line:sub(3))
	    -- print("[D] line/addr:", line, addr)
	    reg_writer[addr] = ins.addr
	    ins.ops[#ins.ops + 1] = {flag='P', addr=line:sub(3)}

	 elseif k == 'G ' then
	    local addr = tonumber(line:sub(3))
	    local dep_addr = reg_writer[addr]
	    if dep_addr and dep_addr ~= ins.addr then
	       ins.dep[#ins.dep + 1] = dep_addr
	    end
	    ins.ops[#ins.ops + 1] = {flag='G', addr=line:sub(3)}

	 elseif line:sub(1,5) == 'ISSUE' then
	    print(string.format("ISSUE %d", #issue.sb))
	    for core, blk in ipairs(issue.sb) do
	       local ins_inorder = {}
	       for pc, ins in ipairs(blk.ins) do
		  ins_inorder[pc] = ins
	       end

	       local ins_ooo = {}
	       local q = List.new()
	       for pc, ins in ipairs(blk.ins) do
		  if #ins.mref > 0 then
		     -- a memory access instruction, try to move it earlier
		     mark_deps(sb, ins)
		     copy_marked_deps(sb, ins_ooo)
		  end
	       end

	       for _, ins in ipairs(blk.ins) do
	       	  if not ins.mark then
	       	     ins_ooo[#ins_ooo + 1] = ins
	       	  end
	       end

	       print(string.format("SB %x", sb.addr))
	       for _, ins in ipairs(ins_ooo) do		  
		  print(string.format("I %x", ins.addr))
		  for _, op in ipairs(ins.ops) do
		     print(string.format("%s %s", op.flag, op.addr))
		  end
	       end
	    end			-- loop over issue.sb

	    issue.sb = {}
	 end			-- 'ISSUE'
      end			-- ~= '=='
   end
   -- TODO add a switch verbose or terse
   -- logd(i)
end				--  function parse_lackey_log()

rob_w = core_num
init_rob(rob, rob_d, rob_w)
parse_input(sb_size, sb_merge)
