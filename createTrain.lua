require 'nn'
opt={}
opt.negativeSamples=80
torch.setdefaulttensortype('torch.FloatTensor')
sentLength=26

function createIndex( l )
  local t=torch.Tensor(sentLength):zero()
  t[1]=table.getn(l)
  for i=1,table.getn(l) do
      t[i+1]=l[i]+1
  end
  return t
end


function loadTrainSet( state_file, train_file )
  local state=io.input(state_file)
  local l=io.read("*line"):split(" ")
  state:close()
  local Vocab=tonumber(l[1])
  local trainDataSize=tonumber(l[2])
  local trainData=torch.Tensor(trainDataSize*opt.negativeSamples,3,sentLength)
  local train=io.input(train_file)
  local j=1
  for i=1,trainDataSize do
      local l=io.read("*line"):split(" ")
      local x=createIndex(l)
      l=io.read("*line"):split(" ")
      local y=createIndex(l)
      local k=1
      while true do
        local line=io.read("*line")
        if line=="" then
          break
        end
        if k<=opt.negativeSamples then
          l=line:split(" ")
          local z=createIndex(l)
          trainData[j][1]=x
          trainData[j][2]=y
          trainData[j][3]=z
          j=j+1
        end
        k=k+1
      end
  end
  train:close()
  return trainData:sub(1,j-1)
end

-- trainData=loadTrainSet("../data/state_2025750.txt","../data/train_all_new_where.txt")
-- trainData=loadTrainSet("../data/state_web.txt","../data/train_web.txt")
trainData=loadTrainSet("../data/state_2334431.txt","../data/train_all_new_2.txt")
torch.save('../data/train_2.bin',trainData)

