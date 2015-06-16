-- Train a ranking function so that mlp:forward({x,y},{x,z}) returns a number
-- which indicates whether x is better matched with y or z (larger score = better match)
require 'torch'
require 'nn'
require 'nnx'
require 'optim'
require 'image'
require 'pl'
require 'paths'
-- create network
-- local state=io.input("../data/state_web.txt")
-- local l=io.read("*line"):split(" ")
-- state:close()
-- local Vocab=tonumber(l[1])
-- local trainDataSize=tonumber(l[2])
-- trainDataSize=60
----------------------------------------------------------------------
-- parse command-line options
--
local opt = lapp[[
   -s,--save          (default "logs")      subdirectory to save logs
   -f,--full                                use the full dataset
   -p,--plot                                plot while training
   -o,--optimization  (default "ADAGRAD")       optimization: SGD | LBFGS | ADAGRAD | ADAM
   -r,--learningRate  (default 0.05)        learning rate, for SGD only
   -b,--batchSize     (default 10)          batch size
   -m,--momentum      (default 0)           momentum, for SGD only
   -i,--maxIter       (default 3)           maximum nb of iterations per batch, for LBFGS
   --coefL1           (default 0)           L1 penalty on the weights
   --coefL2           (default 0)           L2 penalty on the weights
   -t,--threads       (default 8)           number of threads
   -e,--negativeSamples  (default 10)       number of negativeSamples
   -d,--dimension     (default 100)         dimension of embedding
   -a,--randomSampling   (default false)       randomSampling
]]
-- fix seed
torch.manualSeed(1)

-- threads
torch.setnumthreads(opt.threads)
print('<torch> set nb of threads to ' .. torch.getnumthreads())


-- use floats, for SGD
if opt.optimization == 'SGD' or opt.optimization == 'ADAGRAD' then
   torch.setdefaulttensortype('torch.FloatTensor')
end

-- batch size?
if opt.optimization == 'LBFGS' and opt.batchSize < 100 then
   error('LBFGS should not be used with small mini-batches; 1000 is a recommended')
end

function createSparseVector( l )
  return torch.Tensor(l)+1
end


function loadTrainSet( state_file, train_file )
  local state=io.input(state_file)
  local l=io.read("*line"):split(" ")
  state:close()
  local Vocab=tonumber(l[1])
  local trainDataSize=tonumber(l[2])
  local trainData={}
  
  local train=io.input(train_file)
  local j=1
  for i=1,trainDataSize do
      local l=io.read("*line"):split(" ")
      local x=createSparseVector(l)
      l=io.read("*line"):split(" ")
      local y=createSparseVector(l)
      local k=1
      while true do
        local line=io.read("*line")
        if line=="" then
          break
        end
        if k<=opt.negativeSamples then
          l=line:split(" ")
          local z=createSparseVector(l)
          local output=1
          local input={{x,y},{x,z}}
          trainData[j]= {input,output}
          j=j+1
        end
        k=k+1
      end
    
  end
  train:close()
  function trainData:size() return j-1 end -- number of examples
  return Vocab,trainData
end

-- Vocab,trainData=loadTrainSet("../data/state_web.txt","../data/train_web.txt")
trainData=torch.load('../data/train_new.bin')
Vocab=225961

-- define model to train
-- mlp1=nn.SparseLinear(Vocab,opt.dimension)
mlp1=nn.Sequential()
lookup=nn.LookupTable(Vocab, opt.dimension)
sumlayer=nn.Sum(1)
mlp1:add(lookup)
mlp1:add(sumlayer)

mlp2=mlp1:clone('weight','bias','gradWeight','gradBias')

prl=nn.ParallelTable();
prl:add(mlp1); prl:add(mlp2)

mlp1=nn.Sequential()
mlp1:add(prl)
mlp1:add(nn.DotProduct())

mlp2=mlp1:clone('weight','bias','gradWeight','gradBias')

model=nn.Sequential()
prla=nn.ParallelTable()
prla:add(mlp1)
prla:add(mlp2)
model:add(prla)

-- retrieve parameters and gradients
parameters,gradParameters = model:getParameters()

-- verbose
print('<qa> using model:')
print(model)


-- set criterion
local margin=0.1
crit=nn.MarginRankingCriterion(margin); 


-- this matrix records the current confusion across classes
confusion = optim.ConfusionMatrix({1,-1})

-- log results to files
trainLogger = optim.Logger(paths.concat(opt.save, 'train.log'))

-- training function
function train(dataset)
   -- epoch tracker
   epoch = epoch or 1

   -- local vars
   local time = sys.clock()
   -- shuffle at each epoch
   shuffle = torch.randperm(dataset:size())

   -- do one epoch
   print('<trainer> on training set:')
   print("<trainer> online epoch # " .. epoch .. ' [batchSize = ' .. opt.batchSize .. ']')
   for t = 1,dataset:size(),opt.batchSize do
      -- create mini batch
      local inputs = {}
      local targets = {}
      local k = 1
      for i = t,math.min(t+opt.batchSize-1,dataset:size()) do
         -- load new sample
         local sample = dataset[shuffle[i]]
         local input = sample[1]
         local target = sample[2]
         inputs[k] = input
         targets[k] = target
         k = k + 1
      end

      -- create closure to evaluate f(X) and df/dX
      local feval = function(x)
         -- just in case:
         collectgarbage()

         -- get new parameters
         if x ~= parameters then
            parameters:copy(x)
         end

         -- reset gradients
         gradParameters:zero()

         -- f is the average of all criterions
         local f = 0
         -- evaluate function for complete mini batch
         for i = 1,#inputs do
            -- estimate f
            local output = model:forward(inputs[i])
            local err = crit:forward(output, targets[i])
            f = f + err
            -- estimate df/dW
            local df_do = crit:backward(output, targets[i])
            model:backward(inputs[i], df_do)
            -- update confusion
            local predict=(output[1]-output[2])[1]
            if predict>=margin then confusion:add(1, targets[i]) else confusion:add(-1, targets[i]) end
            
         end

         -- penalties (L1 and L2):
         if opt.coefL1 ~= 0 or opt.coefL2 ~= 0 then
            -- locals:
            local norm,sign= torch.norm,torch.sign

            -- Loss:
            f = f + opt.coefL1 * norm(parameters,1)
            f = f + opt.coefL2 * norm(parameters,2)^2/2

            -- Gradients:
            gradParameters:add( sign(parameters):mul(opt.coefL1) + parameters:clone():mul(opt.coefL2) )
         end

         -- normalize gradients and f(X)
         gradParameters:div(#inputs)
         f = f/#inputs

         -- return f and df/dX
         return f,gradParameters  
      end

      -- optimize on current mini-batch
      if opt.optimization == 'LBFGS' then

         -- Perform LBFGS step:
         lbfgsState = lbfgsState or {
            maxIter = opt.maxIter,
            lineSearch = optim.lswolfe
         }
         optim.lbfgs(feval, parameters, lbfgsState)
       
         -- disp report:
         print('LBFGS step')
         print(' - progress in batch: ' .. t .. '/' .. dataset:size())
         print(' - nb of iterations: ' .. lbfgsState.nIter)
         print(' - nb of function evalutions: ' .. lbfgsState.funcEval)

      elseif opt.optimization == 'SGD' then

         -- Perform SGD step:
         sgdState = sgdState or {
            learningRate = opt.learningRate,
            momentum = opt.momentum,
            learningRateDecay = 5e-7
         }

         optim.sgd(feval, parameters, sgdState)
      
         -- disp progress
         xlua.progress(t, dataset:size())
      
      elseif opt.optimization == 'ADAGRAD' then
         adagradState=adagradState or {
            learningRate=opt.learningRate,
            paramVariance=opt.paramVariance
         }

         optim.adagrad(feval,parameters,adagradState)
         
         -- disp progress
         xlua.progress(t, dataset:size())
      
      elseif opt.optimization == 'ADAM' then
         local adam_state = {}
         local config = {}
         optim.adam(feval, parameters, config ,adam_state)
         -- disp progress
         xlua.progress(t, dataset:size())

      
      else
         error('unknown optimization method')
      end
   end
   
   -- time taken
   time = sys.clock() - time
   time = time / dataset:size()
   print("<trainer> time to learn 1 sample = " .. (time*1000) .. 'ms')

   -- print confusion matrix
   print(confusion)
   trainLogger:add{['% mean class accuracy (train set)'] = confusion.totalValid * 100}
   confusion:zero()

   -- save/log current net
   local filename = paths.concat(opt.save, 'qa.net')
   os.execute('mkdir -p ' .. sys.dirname(filename))
   if paths.filep(filename) then
      os.execute('mv ' .. filename .. ' ' .. filename .. '.old')
   end
   print('<trainer> saving network to '..filename)
   --torch.save(filename, mlp1)

   -- next epoch
   epoch = epoch + 1
end

-- test function
function test(inPutFilename,outPutFileName)
   collectgarbage()
   -- local vars
   local time = sys.clock()

   -- test over given dataset
   print('<trainer> on testing Set:')

  local json = require ("dkjson")

  function compare(a,b)
    return a[2] > b[2]
  end
  -- mlp1=torch.load('logs/qa.net')

  local state=io.input("../data/state.test.txt")
  local l=io.read("*line"):split(" ")
  state:close()
  local testDataSize=tonumber(l[2])
  -- Opens a file in read
  outPutFile = io.open(outPutFileName, "w")
  testFile=io.input(inPutFilename)
  for i=1,testDataSize do
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
      outPutFile:write(table.concat({Q_text,Answers,predicates_str},"\t"),"\n")  
  end
  testFile:close()
  outPutFile:close()
   -- timing
   time = sys.clock() - time
   time = time / testDataSize
   print("<trainer> time to test 1 sample = " .. (time*1000) .. 'ms')
   confusion:zero()
end

local outPutFileName="../data/fb_test_out." .. opt.batchSize .. ".txt"
while true do
  -- train
  train(trainData)
  test("../data/test.txt",outPutFileName)
  os.execute('./evaluation.py ' .. outPutFileName)
  -- plot errors
   if opt.plot then
      trainLogger:style{['% mean class accuracy (train set)'] = '-'}
      trainLogger:plot()
   end
end
