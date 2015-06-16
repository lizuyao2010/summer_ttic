#!/usr/bin/python
import json
from nltk.tokenize import word_tokenize
word2ind={}
relation2ind={}
flag=1
# count number of questions
count=0

def encode(text,dic,fw):
    codes=[]
    for word in text:
        if word not in dic:
            dic[word]=len(dic)+1
        codes.append(str(dic[word]))
    print >> fw, ' '.join(codes)

# with open('../data/train_ws_soft.txt','r') as fr, open('../data/train_ws_soft_code.txt','w') as fw, open('../data/state.train_ws_soft.txt','r') as state:
#     for line in fr:
#         line=line.strip()
#         # new question
#         if line=="":
#             flag=1
#             print >> fw
#             continue
#         # question and answer
#         if flag==1:
#             q,a=line.split(' # ')
#             q=word_tokenize(q.lower().strip().rstrip('?'))
#             encode(q,word2ind,fw)
#             count+=1
#             flag+=1
#             continue
#         # my answer and relation 
#         elif flag==2:
#             line=line.split(' # ')
#             if len(line)==2:
#                 mya,r=line
#                 r=r.split(' ')
#                 assert len(r)<3
#                 encode(r,relation2ind,fw)
#             continue

with open('../data/train_web_soft_0.8.txt','r') as fr, open('../data/train_web_soft_0.8_code.txt','w') as fw, open('../data/state.train_web_soft_0.8.txt','r') as state:
    vocab,num_answered,total=state.readline().strip().split()
    for i in xrange(int(num_answered)):
        # new question
        line=fr.readline().strip()
        q,a=line.split(' # ')
        print q
        q=word_tokenize(q.lower().strip().rstrip('?').decode('utf-8'))
        encode(q,word2ind,fw)
        count+=1
        while True:
            line=fr.readline().strip()
            # next question
            if line=="":
                print >> fw
                break
            # my answer and relation 
            line=line.split(' # ')
            if len(line)==2:
                mya,r=line
                r=r.split(' ')
                assert len(r)<3
                encode(r,relation2ind,fw)

print "finish",count


with open('../data/word2ind_web_soft_0.8.json','w') as fw1, open('../data/relation2ind_web_soft_0.8.json','w') as fw2, open('../data/state_web_soft_0.8.txt','w') as fw3:
    json.dump(word2ind,fw1)
    json.dump(relation2ind,fw2)
    print >> fw3, len(word2ind), len(relation2ind), count 