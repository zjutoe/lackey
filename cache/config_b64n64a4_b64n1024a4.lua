local cache = require "cache"

local L2 = cache:new{
   name = "L2",			-- L2 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 1024,		-- n_blks, 2^10
   assoc = 4,			-- assoc
   read_hit_delay = 4,		-- read delay
   write_hit_delay = 8,		-- write delay
   coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write back
   next_level = nil}		-- next level

local L1a = cache:new{
   name = "L1a",		-- L1 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 64,			-- n_blks, 2^6
   assoc = 4,			-- assoc
   read_hit_delay = 1,		-- read_delay
   write_hit_delay = 2,		-- write_delay
   coherent_delay = 2,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

local L1b = cache:new{
   name = "L1b",		-- L1 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 64,			-- n_blks, 2^6
   assoc = 4,			-- assoc
   read_hit_delay = 1,		-- read_delay
   write_hit_delay = 2,		-- write_delay
   coherent_delay = 2,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

local L1c = cache:new{
   name = "L1c",		-- L1 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 64,			-- n_blks, 2^6
   assoc = 4,			-- assoc
   read_hit_delay = 1,		-- read_delay
   write_hit_delay = 2,		-- write_delay
   coherent_delay = 2,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

local L1d = cache:new{
   name = "L1d",		-- L1 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 64,			-- n_blks, 2^6
   assoc = 4,			-- assoc
   read_hit_delay = 1,		-- read_delay
   write_hit_delay = 2,		-- write_delay
   coherent_delay = 2,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

L1a:set_peers({L1b, L1c, L1d})
L1b:set_peers({L1a, L1c, L1d})
L1c:set_peers({L1a, L1b, L1d})
L1d:set_peers({L1a, L1b, L1c})

return {L1a, L1b, L1c, L1d}
