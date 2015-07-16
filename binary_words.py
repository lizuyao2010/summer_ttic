#!/usr/bin/python
import json
from nltk.tokenize import word_tokenize
word2ind={}
relation2ind={}
flag=1
# count number of questions
count=0
max_sent_len=0


def encode(text,dic,fw):
    global max_sent_len
    codes=[]
    for word in text:
        if word not in dic:
            dic[word]=len(dic)+1
        codes.append(str(dic[word]))
    if len(codes)>max_sent_len:
        max_sent_len=len(codes)
    print >> fw, ' '.join(codes)

with open('../data/train_sim_soft_train.txt','r') as fr, open('../data/train_sim_soft_train_code.txt','w') as fw:
    for line in fr:
        line=line.strip()
        # new question
        if line=="":
            flag=1
            print >> fw
            continue
        # question and answer
        if flag==1:
            qa=line.split(' # ')
            a=qa[-1]
            q=' # '.join(qa[:-1])
            q=word_tokenize(q.decode('utf-8').lower().strip().rstrip('?'))
            encode(q,word2ind,fw)
            count+=1
            flag+=1
            continue
        # my answer and relation 
        elif flag==2:
            line=line.split(' # ')
            if len(line)==2:
                mya,r=line
                r=r.split(' ')
                assert len(r)<3
                encode(r,relation2ind,fw)
            continue

# with open('../data/train_sim_soft_train.txt','r') as fr, open('../data/train_sim_soft_train_code.txt','w') as fw, open('../data/state.train_sim_soft_train.txt','r') as state:
#     vocab,num_answered,total=state.readline().strip().split()
#     for i in xrange(int(num_answered)):
#         # new question
#         line=fr.readline().strip()
#         q,a=line.split(' # ')
#         print q
#         q=word_tokenize(q.lower().strip().rstrip('?').decode('utf-8'))
#         encode(q,word2ind,fw)
#         count+=1
#         while True:
#             line=fr.readline().strip()
#             # next question
#             if line=="":
#                 print >> fw
#                 break
#             # my answer and relation 
#             line=line.split(' # ')
#             if len(line)==2:
#                 mya,r=line
#                 r=r.split(' ')
#                 assert len(r)<3
#                 encode(r,relation2ind,fw)

print "finish",count


with open('../data/word2ind_sim_soft.json','w') as fw1, open('../data/relation2ind_sim_soft.json','w') as fw2, open('../data/state_sim_soft.txt','w') as fw3:
    json.dump(word2ind,fw1)
    json.dump(relation2ind,fw2)
    print >> fw3, max_sent_len,len(word2ind), len(relation2ind), count 