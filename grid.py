def drange(start, stop, step):
	r=start
	result=[]
	while r<stop:
		result.append(r)
		r+=step
	return result
dimensions=drange(100,1001,100)
margins=drange(0.5,5.5,0.5)
dropouts=drange(0,1.25,0.25)
for dimension in dimensions:
	for margin in margins:
		for dropout in dropouts:
		    args=" --dimension "+str(dimension)+" --margin "+str(margin)+" --dropout "+str(dropout)
		    out="dimension_"+str(dimension)+"margin_"+str(margin)+"dropout_"+str(dropout)
		    print "cd /share/project/zuyao/src && . ~/torch_env/env.sh && th train2_multi.lua"+args+" > ../log/"+out+".txt"
