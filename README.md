lackey
======

valgrind tool to trace code execution

TODO
====

refactor the whole system to pipeline/file stream connected components:

1. execution trace from Valgrind or Qemu

2. RoB scheduler to schedule the blocks

3. cores to simulate the execution, i.e. the pipeline, the cache access, inter-core register sync, etc.

To collect data for 3 different strategies of inter-core register value sharing:

1. to sync up all updated registers among rounds of execution:

   a. how many register reads among cores in each sync up? 
   b. how's that value averaged for each superblock? 
   c. how does this value changes along execution?

2. lazy read from other cores when run into an updated registers (updated by another core):

   a. how many register reads among cores for each round of execution?
   b. how many register read conflictions for reach superblock? (affects how many read ports are needed for the register files)
   c. how're those values change along execution?
   d. the delay caused by inter-core register access? compare with the 1st strategy?

3. shared register file + private register files for each core

   a. how many register writes/reads for each round of execution?
   b. how many register read conflictions for reach superblock? (compare with 2nd strategy)
   c. how're those values change along execution?
   d. the delay caused by inter-core register access? compare with the 1st & 2nd strategy?

4. shared register file + private register files + sync up all updated registers among rounds of execution
   ...



