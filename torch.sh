#!/bin/bash
./distribute.pl job_torch_grid_dropout.sh '-l medium -r y -l high -R y -pe serial 1 -l mem_total=20G'
