#!/usr/bin/python
import json
from nltk.tokenize import word_tokenize
relation2ind={}
flag=1
# count number of questions
count=0

max_sent_len=0


def encode_question(text,fw):
    global max_sent_len
    codes=[]
    for word in text:
        for char in word:
            if char.isdigit():
                codes.append(str(ord(char)-ord('0')+27))
            elif char.isalpha():
                codes.append(str(ord(char)-ord('a')+1))
            else:
                print char
        codes.append(str(37)) # add space
    if len(codes)>max_sent_len:
        max_sent_len=len(codes)
    print >> fw, ' '.join(codes)

def encode_relation(text,dic,fw):
    codes=[]
    for word in text:
        if word not in dic:
            dic[word]=len(dic)+1
        codes.append(str(dic[word]))
    print >> fw, ' '.join(codes)

with open('../data/train_web_soft_0.8.txt','r') as fr, open('../data/train_web_soft_0.8_code_char.txt','w') as fw:
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
            encode_question(q,fw)
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
                encode_relation(r,relation2ind,fw)
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


with open('../data/relation2ind_web_soft_0.8_char.json','w') as fw2, open('../data/state_web_soft_0.8_char.txt','w') as fw3:
    json.dump(relation2ind,fw2)
    print >> fw3, max_sent_len,26+10+1,len(relation2ind), count 