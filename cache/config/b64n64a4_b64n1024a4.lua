local cache = require "cache"

local L2 = cache:new{
   name = "L2",			-- L2 of 512KB
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 4096,		-- n_blks, 2^10
   -- assoc = 8,			-- assoc
   read_hit_delay = 10,		-- read delay
   write_hit_delay = 10,	-- write delay
   miss_delay = 40,		-- L3 hit delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write back
   next_level = nil}		-- next level

local L1a = cache:new{
   name = "L1a",		-- L1 of 16KB
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 256,		-- n_blks, 2^8
   -- assoc = 8,			-- assoc
   -- read_hit_delay = 4,		-- read_delay
   -- write_hit_delay = 4,		-- write_delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

local L1b = cache:new{
   name = "L1b",		-- L1 of 8KB
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 256,		-- n_blks, 2^8
   -- assoc = 8,			-- assoc
   -- read_hit_delay = 4,		-- read_delay
   -- write_hit_delay = 4,		-- write_delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

local L1c = cache:new{
   name = "L1c",		-- L1 of 8KB
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 256,		-- n_blks, 2^8
   -- assoc = 8,			-- assoc
   -- read_hit_delay = 4,		-- read_delay
   -- write_hit_delay = 4,		-- write_delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

local L1d = cache:new{
   name = "L1d",		-- L1 of 8KB
   -- word_size = 4,		-- word size in bytes
   -- blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 256,		-- n_blks, 2^8
   -- assoc = 8,			-- assoc
   -- read_hit_delay = 4,		-- read_delay
   -- write_hit_delay = 4,		-- write_delay
   -- coherent_delay = 8,		-- coherent delay
   write_back = true,		-- write_back
   next_level = L2}		-- next_level

L1a:set_peers({L1b, L1c, L1d})
L1b:set_peers({L1a, L1c, L1d})
L1c:set_peers({L1a, L1b, L1d})
L1d:set_peers({L1a, L1b, L1c})

return {L1a, L1b, L1c, L1d}
