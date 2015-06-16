import json
ind2word={}
# with open('../data/vocab_643459.txt') as f:
# 	word2ind=json.load(f)
# 	ind2word = {v: k for k, v in word2ind.items()}
# 	# print ind2word[575307]
word2ind={}
with open('../data/vocab_2025750.txt') as f:
	word2ind=json.load(f)
	ind2word = {v: k for k, v in word2ind.items()}


with open('../data/train_triples.txt') as fr:
	flag=True
	for line in fr:
		line=line.strip()
		if line=='':
			flag=True
			print line
			continue
		if flag:
			wordinxs=line.split()
			sent=[]
			for (i,indOfword) in enumerate(wordinxs):
				word=ind2word[int(indOfword)]
				sent.append(word)
				if i==len(wordinxs)-1 and (word=='on' or word=='in' or word=='at' or word=='near' or word=='beside' or word=='from'): 
					wordinxs[0]=str(word2ind['where'])
			print ' '.join(wordinxs)
			flag=False
		else:
			print line
			None