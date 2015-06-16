cache=set()
with open('data/linked-arg2-binary-extractions.txt') as fr:
	for line in fr:
		sub_id,pre,obj,obj_id=line.strip().split('\t')
		sub=sub_id.split('fb:en.')[1].replace('_',' ')
		q=[]
		q.append('what')
		q.append(sub)
		q.append(pre)
		#print ' '.join(q)
		a=obj_id
		anchor=sub_id
		text=[]
		text.append(' '.join(q))
		text.append(a)
		text.append(anchor)
		if (a,anchor) in cache:
			continue
		if obj.startswith('TIME:'):
			continue
		print ' # '.join(text)
		cache.add((a,anchor))