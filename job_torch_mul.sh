#!/bin/torch_f
cd /share/project/zuyao/src && . ~/torch_env/env.sh && th train2_multi.lua --factor 1 > ../log/f_1.txt
cd /share/project/zuyao/src && . ~/torch_env/env.sh && th train2_multi.lua --factor 2 > ../log/f_2.txt
cd /share/project/zuyao/src && . ~/torch_env/env.sh && th train2_multi.lua --factor 4 > ../log/f_4.txt
cd /share/project/zuyao/src && . ~/torch_env/env.sh && th train2_multi.lua --factor 5 > ../log/f_5.txt
cd /share/project/zuyao/src && . ~/torch_env/env.sh && th train2_multi.lua --factor 10 > ../log/f_10.txt