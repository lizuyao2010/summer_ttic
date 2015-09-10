# encode_question.py
import json
from nltk.tokenize import word_tokenize
fd="../data/word2ind_ws_soft.json"
f=open(fd)
dic=json.load(f)
f.close()

def encode_file(fn):
    f=open(fn)
    data=json.load(f)
    for item in data:
        words=word_tokenize(item['utterance'].decode('utf-8').lower().strip().rstrip('?'))
        q=item['utterance'].strip('?').split()
        print '_'.join(q)
        print ' '.join([str(dic[word]) for word in words if word in dic])
    f.close()

fn="../data/webquestions.examples.train.json"
encode_file(fn)
fn="../data/webquestions.examples.test.json"
encode_file(fn)
