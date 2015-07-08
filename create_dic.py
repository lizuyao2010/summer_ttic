import sys,json
filename=sys.argv[1]
dic={}
count=1
with open(filename,'r') as fr, open('../data/word2ind_web_soft_0.8.glove.json','w') as fw:
	for line in fr:
		line=line.strip().split()
		print "finish",count
		dic[line[0]]=count
		count+=1
	json.dump(dic,fw)
