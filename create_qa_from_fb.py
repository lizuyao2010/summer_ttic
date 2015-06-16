import json
with open('../data/fb15k.txt') as fr:
	for line in fr:
		sent=[]
		s,p,o=line.strip().split('\t')
		pr=p.split('/')
		type2=pr[1]
		predicate=pr[-1]
		sent.append('what is the')
		sent.append(predicate)
		sent.append('of the')
		sent.append(type2)
		sent.append(s)
		q = ' '.join(sent).replace('_',' ')
		qa=[]
		qa.append(q)
		qa.append(o)
		qa.append(s)
		print ' # '.join(qa)
