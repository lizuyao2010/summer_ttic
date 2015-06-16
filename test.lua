require 'nn'
local json = require ("dkjson")
function createSparseVector( l )
  for i=1,table.getn(l) do
    l[i]={l[i]+1,1}
  end
  return torch.Tensor(l)
end
function compare(a,b)
  return a[2] > b[2]
end

mlp1=torch.load('train.model')

local state=io.input("data/state.test.txt")
local l=io.read("*line"):split(" ")
state:close()
local Vocab=tonumber(l[1])
local DataSize=tonumber(l[2])


test=io.input("data/test.txt")
for i=1,DataSize do
    local qa=io.read("*line"):split(" # ")
    local Q_text=qa[1]
    local Answers=qa[2]
    local question_code=io.read("*line"):split(" ")
    local x=createSparseVector(question_code)
    local score_table={}
    local index=1
    while true do
      local line=io.read("*line")
      if line=="" or line==nil then
        break
      end
      local l=line:split(" # ")
      local Can_id=l[1]
      local Can_code=l[2]:split(" ")
      local z=createSparseVector(Can_code)
      local s=mlp1:forward{x,z}[1]
      score_table[index]={Can_id,s}
      index=index+1
    end
    table.sort(score_table,compare)
    local predicates={}
    local j=1
    for key,value in pairs(score_table) do
      predicates[j]=value[1]
      if j== 3 then
        break
      end
      j=j+1
    end
    local predicates_str = json.encode (predicates, { indent = true })
    io.write(table.concat({Q_text,Answers,predicates_str},"\t"),"\n")  
end