import json, urllib, re,random,sys
subgraphDic={}

def query(questionEntity, answerEntity,flag):
    #print(questionEntity+'#'+answerEntity)
    #try:
        service_url = 'https://www.googleapis.com/freebase/v1/topic'
        topic_id ='/en/'+ questionEntity
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
                            return list(set([property, p,questionEntity,answerEntity]))
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
    #except Exception:
    #    return []
    #    pass
def queryWithId(questionEntity, answerEntity,flag):
    #print(questionEntity+'#'+answerEntity)
    service_url = 'https://www.googleapis.com/freebase/v1/topic'
    topic_id =questionEntity
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
                        return list(set([property, p,questionEntity,answerEntity]))
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
with open(sys.argv[1]) as data_file:    
    data = data_file.readlines()
    
dic = {}
N =8930

def queryWithDic(entity,answer,candidate):
#    try:
        if entity+answer in subgraphDic:
            subgraph=subgraphDic[entity+answer][:]
        else:
            subgraph = query(entity, answer,candidate)
            subgraphDic[entity+answer]=subgraph[:]
        return subgraph
   # except Exception:
#        return ''
#        pass
    
index=0
sampleNum=0
voca=open('voca.txt','w')
for i in range(N):
    data[i]=data[i].replace('?','').lower()
    out=''
    count=0
    data[i]=data[i].replace('  ',' ')
    question=data[i].split(" # ")[0]
    answerEntity= data[i].split(" # ")[1]
    questionEntity= data[i].split(" # ")[2][:-1]
    words = question.split(' ')
    for word in words:
        if word not in dic:
            dic[word]=index
            index+=1
    # get relation type
    path = queryWithDic(questionEntity, answerEntity,'')
    # get answerEntity subgraph
    subgraph = queryWithDic(answerEntity,'','')
    # Get questionEntity subgraph
    qSubgraph= queryWithDic(questionEntity,'','candidate')
    for key in list(set(path+subgraph+qSubgraph+[questionEntity])):
        if key not in dic:
            dic[key]=index
            index+=1
    for key in list(set(subgraph)):
        print(dic[key]),
    # Answer
    for key in list(set(path+subgraph+[questionEntity])):        
        out+=(str(dic[key])+' ')
    out+='\n'
    #Question
    for key in words:        
        out+=(str(dic[key])+' ')
    out+='\n'
    #incorrect
    flag=1
    for entity in qSubgraph:
        text=''
        if count>=2:
            break
        if entity not in subgraph:
            if entity=='':
                continue
            entity=entity.encode('UTF-8')
            inSubgraph=queryWithId(entity,'','')
            if len(inSubgraph)==0:
                continue
            else:
                count+=1
            try:
                inPath=queryWithDic(questionEntity, entity,'')
            except Exception:
                pass
            
            for key in list(set(inPath+inSubgraph)):
                if key not in dic:
                    dic[key]=index
                    index+=1
            text+=(str(dic[questionEntity])+' ')
            text+=(str(dic[entity])+' ')
            for key in list(set(inPath+inSubgraph)):
                text+=(str(dic[key])+' ')
            text+='\n'
        if len(path)+len(subgraph)==0 or len(qSubgraph)==0 or count==0 :
            flag=0
            continue
        else:
            out+=text
    if flag==1 and len(qSubgraph)!=0:
        print out
        sampleNum+=1
json.dump(dic,voca)
print '\n'+str(sampleNum)
print str(len(dic))
voca.close()


