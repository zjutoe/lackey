#!/usr/bin/env lua

-- input: trace from lackey tool of valgrind

-- output: trace of code block reordering/scheduling 


local List = require "list"

function logd(...)
   -- print(...)
end

-- the parameters that affects the parallelism 
local core_num = 4
local rob_w = 4
local rob_d = 4
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
	    if ins.tag == 'OP' then
	       io.write('OP ', ins.to)
	       if ins.ti1 ~=nil then io.write(' ', ins.ti1) end
	       if ins.ti2 ~=nil then io.write(' ', ins.ti2) end
	       if ins.ti3 ~=nil then io.write(' ', ins.ti3) end
	       print('')
	    elseif ins.tag == 'I' then
	       print(string.format("%s %s", ins.tag, ins.addr))
	    else
	       print(string.format("%s %s %s", ins.tag, ins.addr, ins.tmp))
	    end
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

   -- io.write("== ")
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

function parse_lackey_log(sb_size, sb_merge)
   local i = 0
   local weight_accu = 0
   for line in io.lines() do
      if line:sub(1,2) ~= '==' then
	 i = i + 1
	 local k = line:sub(1,2)
	 if k == 'SB' then
	    -- if not sb_merge or
	    if weight_accu >= sb_size then
	       set_sb_weight(weight_accu)
	       end_sb()
	       local addr = line:sub(4)
	       start_sb(addr)	       
	       weight_accu = 0
	       -- inst[#inst + 1] = {tag="SB", addr=addr}
	    end
	 elseif k == 'I ' then	    
	    local addr, sz = string.match(line:sub(3), "(%x+),(%d+)")
	    inst[#inst + 1] = {tag="I", addr=addr}
	 elseif k == 'S ' then
	    local t, m = string.match(line:sub(3), "(%w+) (%w+)")
	    local d_addr = tonumber(m:sub(2), 16)
	    mem_writer[d_addr] = sb_addr
	    mem_access[#mem_access + 1] = {type=1, addr=d_addr}
	    inst[#inst + 1] = {tag="S", addr=m:sub(2), tmp=t:sub(2)}
	 elseif k == 'L ' then
	    local t, m = string.match(line:sub(3), "(%w+) (%w+)")
	    local d_addr = tonumber(m:sub(2), 16)
	    -- local d_addr = tonumber(line:sub(4,11), 16)
	    mem_access[#mem_access + 1] = {type=0, addr=d_addr}

	    local dep = mem_writer[d_addr]
	    if dep and dep ~= sb_addr then 
	       -- io.write("L "..line:sub(4,11).." ")
	       -- add_depended(dep) 
	       mem_input[d_addr] = tonumber(line:sub(13))
	    end
	    inst[#inst + 1] = {tag="L", addr=m:sub(2), tmp=t:sub(2)}
	 elseif k == 'P ' then
	    --local reg_o, offset_sb = string.match(line:sub(4), "(%d+) (%d+)")
	    local t, g = string.match(line:sub(3), "(%w+) (%w+)")
	    local reg_o = g:sub(2)
	    
	    reg_writer[tonumber(reg_o)] = sb_addr
	    -- reg_writer_seq[tonumber(reg_o)] = blk_seq
	    -- reg_out_offset[reg_o] = offset_sb
	    reg_io[#reg_io + 1] = {io='o', reg=reg_o}
	    logd("P", sb_addr, reg_o, offset_sb)
	    inst[#inst + 1] = {tag="P", addr=reg_o, tmp=t:sub(2)}
	 elseif k == 'G ' then
	    -- reg_i, offset_sb = string.match(line:sub(4), "(%d+) (%d+)")
	    local t, g = string.match(line:sub(3), "(%w+) (%w+)")
	    local reg_i = g:sub(2)
	    local d_addr = tonumber(reg_i)
	    local dep = reg_writer[d_addr]
	    -- if dep and dep ~= sb_addr and blk_seq ~= reg_writer_seq[d_addr] then
	    if dep and dep ~= sb_addr then 
	       -- io.write("G "..line:sub(4).." ")
	       add_depended(dep) 
	       reg_input[d_addr] = 1
	       --reg_in_offset[reg_i] = offset_sb
	       reg_io[#reg_io + 1] = {io='i', reg=reg_i, dep=dep}
	       logd("G", sb_addr, reg_i, dep)
	    end
	    inst[#inst + 1] = {tag="G", addr=reg_i, tmp=t:sub(2)}
	 -- elseif k == ' D' then
	 --    add_depended(line:sub(4))
	 elseif k == 'W ' then
	    weight_accu = weight_accu + tonumber(line:sub(3))
	 elseif k == 'OP' then
	    local n_op = line:sub(3,3)
	    local to, ti1, ti2, ti3
	    if n_op == '3' then
	       to, ti1, ti2, ti3 = string.match(line:sub(5), "(%w+) = (%w+) (%w+) (%w+)")
	    elseif n_op == '2' then
	       to, ti1, ti2 = string.match(line:sub(5), "(%w+) = (%w+) (%w+)")
	    elseif n_op == '1' then
	       to, ti1 = string.match(line:sub(5), "(%w+) = (%w+)")
	    elseif n_op == '0' then
	       to = string.match(line:sub(5), "(%w+) =")
	    else
	       print('ERROR: invalid OP')
	    end
	    print(line:sub(5), to, ti1, ti2, ti3)
	    inst[#inst + 1] = {tag="OP", to=to, ti1=ti1, ti2=ti2, ti3=ti3}
	 end
      end
   end
   -- TODO add a switch verbose or terse
   -- logd(i)
end				--  function parse_lackey_log()

rob_w = core_num
init_rob(rob, rob_d, rob_w)
parse_lackey_log(sb_size, sb_merge)
