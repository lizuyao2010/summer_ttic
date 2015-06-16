require 'nn'
mlp1=torch.load('train.model')

state=io.input("data/state.txt")
l=io.read("*line"):split(" ")
state:close()
Vocab=tonumber(l[1])

function createSparseVector( l )
  for i=1,table.getn(l) do
    l[i]={l[i]+1,1}
  end
  return torch.Tensor(l)
end

question=io.input("data/q.txt")
l=io.read("*line"):split(" ")
-- local x=torch.zeros(Vocab)
-- assignOnes(x,l)
local x=createSparseVector(l)

vecs=io.input("data/vecs.txt")

local best_score=-100
local best_index=-1
local index=1
score_table={}
while true do
      local line=io.read("*line")
      if line==nil or line=="" then
        break
      end
      l=line:split(" ")
      -- local z=torch.zeros(Vocab)
      -- assignOnes(z,l)
      local z=createSparseVector(l)
      local s=mlp1:forward{x,z}[1]
      score_table[index]={index,s}
      -- print(s)
      if s>best_score then
        best_score=s
        best_index=index
      end
      index=index+1
end
function compare(a,b)
  return a[2] > b[2]
end
ids=io.input("data/ids.txt")
text=io.read("*all"):split("\n")
table.sort(score_table,compare)
for i=1,5 do
  local ind=score_table[i][1]
  -- print(ind)
  print(text[ind])
  print(score_table[i][2])
end

-- print(best_score,best_index)
-- print(text[best_index])
