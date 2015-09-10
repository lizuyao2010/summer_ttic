inputFileName="word_emb_100_epoch_3"
emb=torch.load(inputFileName)
outPutFileName="emb_dev.vectors"
outPutFile = io.open(outPutFileName, "w")
local json = require ("dkjson")
dictionFileName='../data/ind2word_web_soft_0.8.json'
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

inputFileName="relation_emb_100_epoch_3"
emb=torch.load(inputFileName)
dictionFileName='../data/ind2relation_web_soft_0.8.json'
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