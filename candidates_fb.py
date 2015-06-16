import json, urllib, re,random,sys
from alchemyapi import AlchemyAPI
import cPickle as pickle


def query(questionEntity, answerEntity,flag):
    #print(questionEntity+'#'+answerEntity)
    service_url = 'https://www.googleapis.com/freebase/v1/topic'
    topic_id = questionEntity
    params = {
      'key': 'AIzaSyDhAXRl2LMTY4QoZFippElsUU21H5v74Bc',
      'filter': 'all'
    }
    url = service_url + topic_id + '?' + urllib.urlencode(params)
    topic = json.loads(urllib.urlopen(url).read())
    if answerEntity != '':
        for property in topic.get('property', []):
          for value in topic['property'][property]['values']:
            if value.get('text') == answerEntity:
                return [property]
            for p in value.get('property', []):
                for v in value['property'][p]['values']:
                    if v.get('text') == answerEntity:
                        return [property, p,questionEntity,answerEntity]
        return []
    else:
        entityList = []
        for property in topic.get('property', []):
          for value in topic['property'][property]['values']:
            if value.has_key('id') :
                if flag!='candidate':
                    entityList.append(property)
                entityList.append(value['id'])
        return entityList


def getSubgraph(candidateEntity,candidates):
    service_url = 'https://www.googleapis.com/freebase/v1/topic'
    topic_id = candidateEntity
    params = {
      'key': 'AIzaSyDhAXRl2LMTY4QoZFippElsUU21H5v74Bc',
      'filter': 'all'
    }
    url = service_url + topic_id + '?' + urllib.urlencode(params)
    if topic_id in cache:
        topic = cache[topic_id]
    else:
        topic = json.loads(urllib.urlopen(url).read())
        cache[topic_id]=topic
    for property in topic.get('property',[]):
        if property not in dic:
            dic[property]=len(dic)
        for value in topic['property'][property]['values']:
            if 'id' in value:
                if value['id'] not in dic:
                    dic[value['id']]=len(dic)
                if value['id'].startswith('/m/'):
                    path=[property,value['id']]
                    candidates[candidateEntity]+=path

def getCandidates(questionEntity,answer=""):
    candidates={}
    service_url = 'https://www.googleapis.com/freebase/v1/topic'
    topic_id = questionEntity
    params = {
      'key': 'AIzaSyDhAXRl2LMTY4QoZFippElsUU21H5v74Bc',
      'filter': 'all'
    }
    url = service_url + topic_id + '?' + urllib.urlencode(params)
    if topic_id in cache:
        topic = cache[topic_id]
    else:
        cache.clear()
        topic = json.loads(urllib.urlopen(url).read())
        cache[topic_id]=topic
    answer_id=''
    subject=''
    if 'id' not in topic:
        print >> sys.stderr, 'no id'
        return candidates,answer_id,subject
    if 'property' not in topic and '/type/object/name' not in topic['property']:
        print >> sys.stderr, 'no name'
        return candidates,answer_id,subject
    subject=topic['property']['/type/object/name']['values'][0]['text'].encode('utf-8')
    if topic['id'] not in dic:
        dic[topic['id']]=len(dic)
    for property in topic.get('property',[]):
        if property not in dic:
            dic[property]=len(dic)
        for value in topic['property'][property]['values']:
            if 'id' in value and 'text' in value:
                if value['id'] not in dic:
                    dic[value['id']]=len(dic)
                if value['id']!=questionEntity and value['id'].startswith('/m/'):
                    path=[topic['id'],property,value['id']]
                    candidates[value['id']]=path
                    if answer.startswith('/m/'):
                        if value['id']==answer:
                            answer_id=value['id']
                    if answer.startswith('/en/'):
                        if value['text'] and value['text'].lower()==answer.split('/en/')[1].replace('_',' '):
                            answer_id=value['id']
            for p in value.get('property',[]):
                if p not in dic:
                    dic[p]=len(dic)
                for v in value['property'][p]['values']:
                    if 'id' in v and 'text' in v:
                        if v['id'] not in dic:
                            dic[v['id']]=len(dic)
                        if v['id']!=questionEntity and v['id'].startswith('/m/'):
                            path=[topic['id'],property,p,v['id']]
                            candidates[v['id']]=path
                            if answer.startswith('/m/'):
                                if v['id']==answer:
                                    answer_id=v['id']
                            if answer.startswith('/en/'):
                                if v['text'] and v['text'].lower()==answer.split('/en/')[1].replace('_',' '):
                                    answer_id=v['id']
                            # getSubgraph(v['id'],candidates)
    return candidates,answer_id,subject

def encode_candidates(question,ids,vecs):
    candidates,answer_id=getCandidates(question)
    for key in candidates:
        code=[]
        for item in candidates[key]:
            code.append(str(dic[item]))
        if code:
            print >> vecs, ' '.join(code)
            print >> ids, key
    return

subgraphDic={}
def queryWithDic(entity,answer,candidate):
    try:
        if entity+answer in subgraphDic:
            subgraph=subgraphDic[entity+answer][:]
        else:
            subgraph = query(entity, answer,candidate)
            subgraphDic[entity+answer]=subgraph[:]
        return subgraph
    except Exception:
        return ''
        pass
    


def candidate(question,ids,vecs):
    entityList=queryWithDic(question,'','candidate')
    for entity in set(entityList):
        if entity==question or not entity.startswith('/m/'):
            continue
        text=''
        if entity not in dic:
            continue
        else:
            subgraph=queryWithDic(entity,'','')
            for key in list(set(subgraph)):
                if  key in dic:
                    text+=(str(dic[key])+' ')
        if text!='':
            print >> vecs, text
            print >> ids, entity
    return

def encode_question(question,f):
    question=question.strip().lower().rstrip('?').split()
    v=[]
    for w in question:
        if w not in dic:
            dic[w]=len(dic)
        v.append(str(dic[w]))
    if v:
        print >>f, " ".join(v)

def get_entities(question):
    response = alchemyapi.entities('text', question)
    entities=[]
    if response['status'] == 'OK':
        for entity in response['entities']:
            entities.append(entity['text'].encode('utf-8'))
    else:
        print('Error in entity extraction call: ', response['statusInfo'])
    return entities

def answerQuestion(question):
    entity=get_entities(question)[0].replace(' ','_')
    entity_id=json.loads(urllib.urlopen("https://www.googleapis.com/freebase/v1/topic/en/"+entity).read())['id']
    print >> sys.stderr, entity,entity_id
    with open("data/q.txt",'w') as qw:
        encode_question(question,qw)
    with open("data/ids.txt",'w') as ids, open("data/vecs.txt",'w') as vecs:
        encode_candidates(entity_id,ids,vecs)

    with open('data/voca8930.txt','w') as data_file:
        json.dump(dic,data_file)

if __name__=="__main__":
    mode=sys.argv[1]
    if mode=="test":
        with open('../data/vocab.txt','r') as data_file:
            dic=json.load(data_file)
            print len(dic)
        alchemyapi = AlchemyAPI()
        question="who does joakim noah play for?"
        answerQuestion(question)
    if mode=="train":
        dic={}
        with open('../data/vocab.txt','r') as fr:
            dic=json.load(fr)
        cache={}
        with open("../data/fb15k.txt",'r') as fr, open('../data/train_fb15k.txt','w') as fw:
            i=1
            count=0
            for line in fr:
                print i
                sent=[]
                questionEntity,p,answer=line.strip().split('\t')
                pr=p.split('/')
                type2=pr[1]
                predicate=pr[-1]
                sent.append('what is the')
                sent.append(predicate)
                sent.append('of the')
                sent.append(type2)
                candidates={}

                try:
                    candidates,answer_id,subject=getCandidates(questionEntity,answer.decode('utf-8'))
                except Exception as inst:
                    print type(inst)
                    print inst
                    # json.dump(dic,vocab)
                    # print >> state, len(dic),count

                # if not candidates:
                    # continue
                # if not subject:
                    # continue
                if candidates and subject and answer_id:
                    count+=1
                    sent.append(subject)
                    question=' '.join(sent).replace('_',' ')
                    print question
                    encode_question(question,fw)
                    codes=[]
                    for key in candidates:
                        code=[]
                        for item in candidates[key]:
                            code.append(str(dic[item]))
                        if code:
                            if key==answer_id:
                                print >> fw, ' '.join(code)
                            else:
                                codes.append(code)
                    for code in codes:
                        print >> fw, ' '.join(code)
                    print >>fw
                if i%100000==0:
                    with open('../data/vocab_fb15k.txt','wb') as vocab, open('../data/state_fb15k.txt','w') as state:
                        pickle.dump( dic, vocab )
                        print >> state, len(dic), count 
                i+=1
            # json.dump(dic,vocab)
            # pickle.dump( dic, vocab )
            with open('../data/vocab_fb15k.txt','wb') as vocab, open('../data/state_fb15k.txt','w') as state:
                pickle.dump( dic, vocab )
                print >> state, len(dic), count 