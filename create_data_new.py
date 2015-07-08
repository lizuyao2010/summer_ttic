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

def convert_date(value_text):
    date=value_text.split('-')
    new_date=[]
    for (i,item) in enumerate(date):
        if i>0:
            new_date.append(item.lstrip('0'))
    new_date.append(date[0])
    return '/'.join(new_date)

def getCandidates(questionEntity,answers=[]):
    candidates=[]
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
    myanswers=[]
    for property in topic.get('property',[]):
        for value in topic['property'][property]['values']:
            if 'text' in value:
                value_text=value['text'].lower()
                if topic['property'][property]['valuetype']=="datetime":
                    value_text=convert_date(value_text)
                # candidates[value_text]=[property]
                candidates.append((value_text,[property]))
                if value_text in answers and value_text not in myanswers:
                    myanswers.append(value_text)
            for p in value.get('property',[]):
                for v in value['property'][p]['values']:
                    if 'text' in v:
                        v_text=v['text'].lower()
                        if value['property'][p]['valuetype']=="datetime":
                            v_text= convert_date(v_text)
                        # candidates[v_text]=[property,p]
                        candidates.append((v_text,[property,p]))
                        if v_text in answers and v_text not in myanswers:
                            myanswers.append(v_text)
            # if 'id' in value and 'text' in value:
            #     value_text='/en/'+value['text'].lower().replace(' ','_')
            #     candidates[value['id']]=[property]
            #     if value_text in answers and value['id'] not in myanswers:
            #         myanswers.append(value['id'])
            #     if value['id'] in answers and value['id'] not in myanswers:
            #         myanswers.append(value['id'])
            # for p in value.get('property',[]):
            #     for v in value['property'][p]['values']:
            #         if 'text' in v and 'id' in v:
            #             v_text='/en/'+v['text'].lower().replace(' ','_')
            #             candidates[v['id']]=[property,p]
            #             if v_text in answers and v['id'] not in myanswers:
            #                 myanswers.append(v['id'])
            #             if v['id'] in answers and v['id'] not in myanswers:
            #                 myanswers.append(v['id'])
    return candidates,myanswers

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
        if w in dic:
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
    #with open('data/vocab.txt','w') as data_file:
        #json.dump(dic,data_file)

if __name__=="__main__":
    mode=sys.argv[1]
    cache={}
    if mode=="test":
        dic={}
        # with open("../data/webquestions.dev.txt",'r') as fr, open('../data/dev_web_soft_list.txt','w') as fw, open('../data/dev_web_no_answer_soft_list.txt','w')\
        #  as fw2, open('../data/state.dev_web_soft_list.txt','w') as state:
        # with open("../data/webquestions.train_0.8.txt",'r') as fr, open('../data/train_web_soft_0.8.txt','w') as fw, open('../data/train_web_no_answer_soft_0.8.txt','w')\
        #  as fw2, open('../data/state.train_web_soft_0.8.txt','w') as state:
        # with open("../data/QA_triples.txt",'r') as fr, open('../data/train_rev_soft.txt','w') as fw, open('../data/train_rev_no_answer_soft.txt','w')\
        #  as fw2, open('../data/state.train_rev_soft.txt','w') as state:
        with open("../data/webquestions.test.txt",'r') as fr, open('../data/test_web_soft_list_low.txt','w') as fw, open('../data/test_web_no_answer_soft_list_low.txt','w')\
         as fw2, open('../data/state.test_web_soft_list_low.txt','w') as state:
            i=1
            count_has_answers=0
            count_candidates=0
            for line in fr:
                print >> sys.stderr,i
                question,answers_text,questionEntity=line.strip().split(' # ')
                answers=json.loads(answers_text.lower().decode('utf-8'))
                # answers=[answers_text.lower().decode('utf-8').replace('_',' ')]
                # answers=['/'+answers_text.split('fb:')[1].replace('.','/')]
                newanswers=[]
                for answer in answers:
                    newanswers.append(answer.lower())
                answers=newanswers
                try:
                    # questionEntity='/'+questionEntity.split('fb:')[1].replace('.','/')
                    questionEntity='/en/'+questionEntity
                    candidates,myanswers=getCandidates(questionEntity,answers)
                except Exception as inst:
                    print type(inst)
                    print inst
                text=[]
                if candidates:
                    count_candidates+=1
                    if myanswers:
                        print question,'#',questionEntity.split('/en/')[1]
                        canid=1
                        count_has_answers+=1
                        text.append(question)
                        text.append(json.dumps(answers))
                        # text.append(str(canid))
                        print >> fw, ' # '.join(text).encode('utf8')
                        # print correct answers
                        # for key in myanswers:
                        #     code=[]
                        #     for item in candidates[key]:
                        #         code.append(item)
                        #     if code:
                        #         Qcode=[]
                        #         Qcode.append(key)
                        #         # Qcode.append(str(canid))
                        #         Qcode.append(' '.join(code))
                        #         print >> fw, ' # '.join(Qcode).encode('utf8')
                        #     canid+=1

                        # print wrong answers
                        for key in candidates:
                            # if key[0] in myanswers:
                            #     continue
                            code=[]
                            for item in key[1]:
                                code.append(item)
                            if code:
                                Qcode=[]
                                Qcode.append(key[0])
                                # Qcode.append(str(canid))
                                Qcode.append(' '.join(code))
                                print >> fw, ' # '.join(Qcode).encode('utf8')
                            canid+=1
                        # print empty line
                        print >>fw
                if not text:
                    text.append(question)
                    text.append(json.dumps(answers))
                    text.append(json.dumps([]))
                    print >> fw2, '\t'.join(text)
                i+=1
            print >> state, len(dic), count_has_answers, count_candidates
