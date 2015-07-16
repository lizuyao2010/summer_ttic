prefix='../data/train_sim_soft'
with open(prefix+'.txt') as fr, open(prefix+'_train.txt','w') as train, open(prefix+'_val.txt','w') as val, open(prefix+'_test.txt','w') as test:
	count=1
	for line in fr:
		line=line.strip()
		if count<=979791:
			print >> test,line
		if count>=979792 and count<=4409833:
			print >> train,line
		if count>=4409834:
			print >> val,line
		count+=1