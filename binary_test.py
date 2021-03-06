#!/usr/bin/python
import json
from nltk.tokenize import word_tokenize
word2ind={}
relation2ind={}
flag=1
# count number of questions
count=0

def encode(text,dic):
    codes=[]
    for word in text:
        if word in dic:
            codes.append(str(dic[word]))
    return codes
    # print >> fw, ' '.join(codes)

with open('../data/word2ind_sim_soft.json','r') as fw1, open('../data/relation2ind_sim_soft.json','r') as fw2:
    word2ind=json.load(fw1)
    relation2ind=json.load(fw2)

with open('../data/val_sim_soft.txt','r') as fr, open('../data/val_sim_soft_code.txt','w') as fw:
    for line in fr:
        line=line.strip()
        # new question
        if line=="":
            flag=1
            # print empty line
            print>>fw
            continue
        # question and answer
        if flag==1:
            # print >> fw, line
            q,a=line.split(' # ')
            if '[' not in a and ']' not in a:
                a=json.dumps([a])
            print >> fw, ' # '.join([q,a])
            q=word_tokenize(q.decode('utf-8').lower().strip().rstrip('?'))
            qcode=encode(q,word2ind)
            print >> fw, ' '.join(qcode)
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
                rcode=encode(r,relation2ind)
                if rcode:
                    print >> fw, mya,'#',' '.join(rcode)
                
            continue


# with open('../data/test_web_soft.txt','r') as fr, open('../data/test_web_soft_code.txt','w') as fw, open('../data/state.test_web_soft.txt','r') as state:
#     vocab,num_answered,total=state.readline().strip().split()
#     for i in xrange(int(num_answered)):
#         # new question
#         line=fr.readline().strip()
#         print >> fw, line
#         q,a=line.split(' # ')
#         q=word_tokenize(q.lower().strip().rstrip('?'))
#         encode(q,word2ind,fw)
#         count+=1
#         while True:
#             line=fr.readline().strip()
#             # next question
#             if line=="":
#                 break
#             # my answer and relation 
#             line=line.split(' # ')
#             if len(line)==2:
#                 mya,r=line
#                 r=r.split(' ')
#                 assert len(r)<3
#                 print >> fw, mya,'#',
#                 encode(r,relation2ind,fw)

print 'finish',count

