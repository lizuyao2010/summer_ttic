
torch.setdefaulttensortype('torch.FloatTensor')
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end
local json = require ("dkjson")


-- load dictionary
local dic=io.input('../data/word2ind_web_soft_0.8.json')
local str=io.read("*all")
local obj, pos, err = json.decode (str, 1, nil)
if err then
  print ("Error:", err)
else
  print ("finish loading dictionary")
end
vocabsize=tablelength(obj)
emb=torch.Tensor(vocabsize,50):uniform(-0.08, 0.08)

local f=io.input(arg[1],"rb")
-- local f = assert(io.open(arg[1], "rb"))
local count = 1
while true do
 local line = io.read()
 print(line)
 if line == nil then break end
 local row=line:split(" ")
 local index=obj[row[1]]
 if index~=nil then
 	print(row[1])
 	for i=2,table.getn(row) do
 		emb[index][i-1]=row[i]*0.01
 	end
 end
 io.write(string.format("%6d  ", count), "\n")
 count = count + 1
end
torch.save('../data/pretrained_word_emb_dev',emb)


-- -- load dictionary
-- local dic=io.input('../data/relation2ind_web_soft_0.8.json')
-- local str=io.read("*all")
-- local obj, pos, err = json.decode (str, 1, nil)
-- if err then
--   print ("Error:", err)
-- else
--   print ("finish loading dictionary")
-- end
-- vocabsize=tablelength(obj)
-- emb=torch.Tensor(vocabsize,50):uniform(-0.08, 0.08)

-- local f=io.input(arg[1])
-- local count = 1
-- while true do
--  local line = io.read()
--  if line == nil then break end
--  local row=line:split(" ")
--  local relation=string.gsub(string.gsub(row[1],"fb:","/"),"%.","/")
--  local index=obj[relation]
--  if index~=nil then
--  	-- print(relation)
--  	for i=2,table.getn(row) do
--  		emb[index][i-1]=row[i]*0.01
--  	end
--  end
--  io.write(string.format("%6d  ", count), "\n")
--  count = count + 1
-- end
-- torch.save('../data/pretrained_relation_emb_dev',emb)