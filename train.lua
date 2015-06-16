-- Train a ranking function so that mlp:forward({x,y},{x,z}) returns a number
-- which indicates whether x is better matched with y or z (larger score = better match)
require 'nn'
-- create network
-- mlp1=nn.SparseLinear(5000,300)
state=io.input("../data/state.23740.txt")
l=io.read("*line"):split(" ")
state:close()
Vocab=tonumber(l[1])
dataSize=tonumber(l[2])
mlp1=nn.SparseLinear(Vocab,100)
mlp2=mlp1:clone('weight','bias')

prl=nn.ParallelTable();
prl:add(mlp1); prl:add(mlp2)

mlp1=nn.Sequential()
mlp1:add(prl)
mlp1:add(nn.DotProduct())
-- mlp1=torch.load('train.model')

mlp2=mlp1:clone('weight','bias')

mlp=nn.Sequential()
prla=nn.ParallelTable()
prla:add(mlp1)
prla:add(mlp2)
mlp:add(prla)



-- x=torch.Tensor({{1,1},{2,1},{10,1},{31,1}});
-- y=torch.Tensor({{1,1},{2,1},{10,1},{32,1}});
-- z=torch.Tensor({{5,1},{7,1},{9,1},{31,1}});

-- x=torch.zeros(25000)
-- y=torch.zeros(25000)
-- z=torch.zeros(25000)
function assignOnesRandomly(x)
    for i=1,5 do
        local ind=math.random(Vocab)
        x[ind]=1
    end
end
-- assignOnes(x)
-- assignOnes(y)
-- assignOnes(z)


-- print(mlp1:forward{x,x}[1])
-- print(mlp1:forward{x,y}[1])
-- print(mlp1:forward{y,y}[1])

-- set criterion
local margin=0.1
crit=nn.MarginRankingCriterion(margin); 

-- Use a typical generic gradient update function
function gradUpdate(mlp, x, y, criterion, learningRate)
   local pred = mlp:forward(x)
   local err = criterion:forward(pred, y)
   local gradCriterion = criterion:backward(pred, y)
   mlp:zeroGradParameters()
   mlp:backward(x, gradCriterion)
   mlp:updateParameters(learningRate)
end

dataset={};
-- number of data
function dataset:size() return dataSize end -- number of examples
-- for i=1,dataset:size() do 
--   local input={{x,y},{x,z}}
--   local output=1
--   dataset[i] = {input,output}
-- end

-- io.input("question")
-- local count=1
-- for line in io.lines() do
--     l=line:split(" ")
--     local output=1
--     x=torch.Tensor(l)
--     local input={{x,x},{x,x}} 
--     dataset[count] = {input,output}
--     count=count+1
-- end

-- create vecotr according to index
function assignOnes( x,l )
  for i=1,table.getn(l) do
      -- assert (l[i]>0 && l[i]<=Vocab)
      x[l[i]+1]=1
  end
end
function createSparseVector( l )
  for i=1,table.getn(l) do
    l[i]={l[i]+1,1}
  end
  return torch.Tensor(l)
end

-- create dataset
train=io.input("../data/train_all.txt")
for i=1,dataset:size() do
    local l=io.read("*line"):split(" ")
    -- x=torch.Tensor(l);
    -- print(x:size())
    -- local y=torch.zeros(Vocab)
    -- y=assignOnes(l)
    local x=createSparseVector(l)
    l=io.read("*line"):split(" ")
    -- print(y:size())
    -- z=torch.zeros(Vocab);
    -- local x=torch.zeros(Vocab)
    -- assignOnes(x,l)
    local y=createSparseVector(l)
    -- assignOnesRandomly(z)
    while true do
      local line=io.read("*line")
      if line=="" then
        break
      end
      l=line:split(" ")
      -- local z=torch.zeros(Vocab)
      -- assignOnes(z,l)
      local z=createSparseVector(l)
      local output=1
      local input={{x,y},{x,z}}
      dataset[i]= {input,output}
    end    
end
train:close()
-- q:close()
-- a:close()
-- a_:close()
-- dataset={{{x,y},{x,z}},{{y,x},{y,z}}}
math.randomseed(1)

-- make the pair x and y have a larger dot product than x and z

-- for i=1,10 do
--    for j=1,dataset:size() do
--       input=dataset[j]
--       gradUpdate(mlp,input,1,crit,0.05)
--       o1=mlp1:forward{x,y}[1]; 
--       o2=mlp2:forward{x,z}[1]; 
--       o=crit:forward(mlp:forward{{x,y},{x,z}},1)
--       -- print(o1,o2,o)
--    end
-- end

trainer = nn.StochasticGradient(mlp, crit)
trainer.learningRate = 0.01
trainer.maxIteration=5
print("start training")
trainer:train(dataset)

torch.save("../models/train." .. dataSize .. "." .. trainer.maxIteration .. "." .. margin .. ".model",mlp1)
