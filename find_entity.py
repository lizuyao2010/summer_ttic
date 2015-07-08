#!/usr/bin/python
from nltk.tokenize import word_tokenize
with open('qa_found.txt') as fr:
	for line in fr:
		q,anchor=line.strip().split(' # ')
		q=word_tokenize(q.lower().strip().rstrip('?'))
		find=[]
		for (i,w1) in enumerate(q):
			find=[]
			find.append(w1)
			for (j,w2) in enumerate(q[i+1:]):
				find.append(w2)
				if '_'.join(find)==anchor:
					print "find",anchor
