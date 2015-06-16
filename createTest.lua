torch.setdefaulttensortype('torch.FloatTensor')
function createSparseVector( l )
  for i=1,table.getn(l) do
    -- l[i]={l[i]+1,1}
    -- l[i]=l[i]+1
    l[i]=l[i]
  end
  return torch.Tensor(l)
end
function loadTestSet( state_file,inPutFilename )
  local state=io.input(state_file)
  local l=io.read("*line"):split(" ")
  state:close()
  local testDataSize=tonumber(l[2])
  testFile=io.input(inPutFilename)
  testData={}

  for i=1,testDataSize do
      print(i)
      local qa=io.read("*line"):split(" # ")
      local Q_text=qa[1]
      local Answers=qa[2]
      local question_code=io.read("*line"):split(" ")
      local x=createSparseVector(question_code)
      local index=1
      testData[i]={}
      testData[i]['Q_text']=Q_text
      testData[i]['Answers']=Answers
      testData[i]['question_code']=x
      while true do
        local line=io.read("*line")
        if line=="" or line==nil then
          break
        end
        local l=line:split(" # ")
        local Can_id=l[1]
        local Can_code=l[2]:split(" ")
        local z=createSparseVector(Can_code)
        testData[i][index]={}
        testData[i][index]['Can_code']=z
        testData[i][index]['Can_id']=Can_id
        index=index+1
      end
 
  end
  function testData:size() return testDataSize end -- number of examples
  return testData
end

-- testData=loadTestSet("../data/state.test_2025750.txt","../data/test_2025750.txt")
-- testData=loadTestSet("../data/state.test.txt","../data/test.txt")
-- torch.save('../data/test_web_index.bin',testData)

testData=loadTestSet("../data/state.dev_web_soft.txt","../data/dev_web_soft_code.txt")
torch.save('../data/dev_web_soft_index.bin',testData)
