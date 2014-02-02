#!/bin/bash

valgrind --log-file="$1".log --tool=lackey --trace-mem=yes --trace-superblocks=yes $@

