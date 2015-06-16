import json,random
with open("../data/webquestions.examples.train.json") as f,open("../data/webquestions.dev.txt",'w') as dev,open("../data/webquestions.train_0.8.txt",'w') as train:
    items=json.load(f)
    lines=[]
    for item in items:
    	answers=[]
        for answer in item['targetValue'].split("(description ")[1:]:
            line=[]
            line.append(item['utterance'])
            answer=answer.strip().strip(")").strip("\"")
            answers.append(answer)
        # line.append(json.dumps(answers))
        line.append(answers)
        line.append(item['url'].split('en/')[1])
        lines.append(line)
        # lines.append(u" # ".join(line).encode('utf-8'))
    random.shuffle(lines)
    n=len(lines)
    n1=int(n*0.2)
    for line in lines[:n1]:
        line[1]=json.dumps(line[1])
        line=u" # ".join(line).encode('utf-8')
        print >> dev,line
    for line in lines[n1:]:
        for answer in line[1]:
            newline=[line[0],answer,line[2]]
            print >> train,u" # ".join(newline).encode('utf-8')
