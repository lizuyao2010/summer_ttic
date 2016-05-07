require "nn"
sent=torch.load("../models/multi_sent_emb_100_epoch_2")
testFile="../data/encoded_questions.txt"
opt={}
outPutFileName="../models/sent_multi.emb"
testDataSize=11620/2
-- test function
function test2 ( testDataFileName,outPutFileName )
  function createSparseVector( l )
    for i=1,table.getn(l) do
      l[i]=l[i]
    end
    return torch.Tensor(l)
  end
  local json = require ("dkjson")
  function compare(a,b)
    return a[2] > b[2]
  end
  outPutFile = io.open(outPutFileName, "w")
  local test=io.open(testDataFileName)
  for i=1,testDataSize do
      local Q_text=test:read("*line")
      local question_code=test:read("*line"):split(" ")
      if table.getn(question_code)>=2 then
          local x=createSparseVector(question_code)
          local x_emb=sent:forward(x)
          outPutFile:write(Q_text," ")
          for i=1,x_emb:size()[1]-1 do
            outPutFile:write(x_emb[i]," ")    
          end
          outPutFile:write(x_emb[x_emb:size()[1]],"\n")
      else
        print(Q_text,question_code)
      end  
  end
  -- close output file
  inputFileName="../models/multi_relation_emb_100_epoch_2"
  emb=torch.load(inputFileName)
  dictionFileName='../data/ind2relation_ws_soft.json'
  local dic=io.input(dictionFileName)
  local str=io.read("*all")
  local obj, pos, err = json.decode (str, 1, nil)
  if err then
    print ("Error:", err)
  else
    print ("finish loading dictionary")
  end
  -- outPutFile:write(table.concat({emb:size()[1],emb:size()[2]}," "),"\n")
  for i=1,emb:size()[1] do
      outPutFile:write(obj[tostring(i)]," ")
      for j=1,emb:size()[2]-1 do
          outPutFile:write(emb[i][j]," ")
      end
      outPutFile:write(emb[i][emb:size()[2]],"\n")
  end

  outPutFile:close()
end

test2(testFile,outPutFileName)