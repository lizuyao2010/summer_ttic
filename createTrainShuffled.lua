require 'nn'
require 'math'
opt={}
opt.negativeSamples=80
torch.setdefaulttensortype('torch.FloatTensor')
sentLength=27

function createIndex( l )
  local t=torch.Tensor(sentLength):zero()
  t[1]=table.getn(l)
  for i=1,table.getn(l) do
      -- t[i+1]=l[i]+1
      t[i+1]=l[i]
  end
  return t
end


function loadTrainSet( state_file, train_file )
  local state=io.input(state_file)
  local l=io.read("*line"):split(" ")
  state:close()
  local Vocab_word=tonumber(l[1])
  local Vocab_relation=tonumber(l[2])
  local trainDataSize=tonumber(l[3])
  local trainData=torch.Tensor(trainDataSize*opt.negativeSamples,3,sentLength)
  local train=io.input(train_file)
  local j=1
  for i=1,trainDataSize do
      local l=io.read("*line"):split(" ")
      print(i)
      local x=createIndex(l)
      l=io.read("*line"):split(" ")
      local y=createIndex(l)
      local k=1
      local candidates={}
      while true do
        local line=io.read("*line")
        if line=="" or line==nil then
          break
        end
        l=line:split(" ")
        -- print(l)
        local z=createIndex(l)
        candidates[k]=z
        k=k+1
      end

      shuffle = torch.randperm(k-1)
      local sampleSize=math.min(k-1,opt.negativeSamples)
      for m=1,sampleSize do
        trainData[j][1]=x
        trainData[j][2]=y
        trainData[j][3]=candidates[shuffle[m]]
        j=j+1
      end
  end
  train:close()
  return trainData:sub(1,j-1)
end

-- trainData=loadTrainSet("../data/state_2025750.txt","../data/train_all_new.txt")
-- trainData=loadTrainSet("../data/state_web.txt","../data/train_web.txt")
trainData=loadTrainSet("../data/state_web_soft_0.8.glove.txt","../data/train_web_soft_0.8_code_glove.txt")
torch.save('../data/train_random_web_soft_0.8_index_glove.bin',trainData)

-- torch.save('../data/train_random.bin',trainData)

