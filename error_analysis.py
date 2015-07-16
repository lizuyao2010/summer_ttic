#!/usr/bin/python
# -*- coding: utf-8 -*-
import random
import sys
filename=sys.argv[1]
f=open(filename)
errors=[]
for line in f:
	line=line.strip()
	q,g,p=line.split('\t')
	if set(g)!=set(p):
		errors.append(line)
random.shuffle(errors)
errors_classified={}
errors_classified['golds is subset of predicts']=[]
errors_classified['predicts is subset of golds']=[]
errors_classified['otherwise']=[]
for line in errors[:len(errors)/10]:
	q,g,p=line.split('\t')
	if set(g).issubset(set(p)):
		errors_classified['golds is subset of predicts'].append(line)
	elif set(p).issubset(set(g)):
		errors_classified['predicts is subset of golds'].append(line)
	else:
		errors_classified['otherwise'].append(line)
for key in errors_classified:
	print key,":"
	for line in errors_classified[key]:
		print line
	print "-"*50
f.close()