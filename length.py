import sys
filename=sys.argv[1]
f=open(filename)
maxLeng=0
for line in f:
	line=line.strip()
	if line:
		l=line.split()
		leng=len(l)
		if leng>maxLeng:
			maxLeng=leng
print maxLeng
