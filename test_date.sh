#!/bin/bash

valgrind --log-file=date.log --tool=lackey --trace-mem=yes --trace-superblocks=yes --detailed-counts=yes date


