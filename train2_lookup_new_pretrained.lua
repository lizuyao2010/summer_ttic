-- Train a ranking function so that mlp:forward({x,y},{x,z}) returns a number
-- which indicates whether x is better matched with y or z (larger score = better match)
require 'torch'
require 'nn'
require 'nnx'
require 'optim'
require 'image'
require 'pl'
require 'paths'
require 'rnn'
require 'os'
----------------------------------------------------------------------
-- parse command-line options
--
local opt = lapp[[
   -s,--save          (default "logs")      subdirectory to save logs
   -n,--network       (default "")          reload pretrained network
   --dataset          (default "web_dev")       dataset
   -f,--full                                use the full dataset
   -p,--plot                                plot while training
   -o,--optimization  (default "ADAGRAD")       optimization: SGD | LBFGS | ADAGRAD | ADADELTA | ADAM | RMSPROP
   -r,--learningRate  (default 0.05)        learning rate, for SGD only
   -b,--batchSize     (default 800)          batch size
   -m,--momentum      (default 0)           momentum, for SGD only
   -i,--maxIter       (default 3)           maximum nb of iterations per batch, for LBFGS
   --coefL1           (default 0)           L1 penalty on the weights
   --coefL2           (default 0)           L2 penalty on the weights
   -t,--threads       (default 8)           number of threads
   -d,--dimension     (default 100)         dimension of embedding
   -a,--randomSampling   (default false)       randomSampling
   -c,--candidates    (default 1)           number of candidates
   --margin           (default 1)           margin
   --threshold        (default 0)         threshold
   --pretrained       (default false)      load pretrained embedding
]]
-- fix seed
torch.manualSeed(1)

-- threads
torch.setnumthreads(opt.threads)
-- print('<torch> set nb of threads to ' .. torch.getnumthreads())


-- use floats, for SGD
if opt.optimization == 'SGD' or opt.optimization == 'ADAGRAD' or opt.optimization == 'RMSPROP' or opt.optimization == 'ADADELTA' or opt.optimization == 'ADAM' then
   torch.setdefaulttensortype('torch.FloatTensor')
end

-- batch size?
if opt.optimization == 'LBFGS' and opt.batchSize < 100 then
   error('LBFGS should not be used with small mini-batches; 1000 is a recommended')
end

if opt.dataset=="web" then
  trainData=torch.load('../data/train_random_web_soft_index.bin')
  Vocab_word=3499
  Vocab_relation=3505
  word_emb_file='../data/pretrained_word_emb'
  relation_emb_file='../data/pretrained_relation_emb'
  testFile="../data/test_web_soft_code_list.txt"
  testDataSize=1918
elseif opt.dataset=="web_dev" then
  trainData=torch.load('../data/train_random_web_soft_0.8_index_glove.bin')
  Vocab_word=400000
  Vocab_relation=3358
  word_emb_file='../data/pretrained_word_emb_dev_glove'
  relation_emb_file='../data/pretrained_relation_emb_dev'
  testFile="../data/dev_web_soft_code_list.glove.txt"
  testDataSize=717
elseif opt.dataset=="ws" then
  trainData=torch.load('../data/train_random_ws_soft_index.bin')
  Vocab_word=51230
  Vocab_relation=6769
  testFile="../data/test_ws_soft_code_list.txt"
  testDataSize=1918
else
  print("no that dataset")
  return
end
outPutFileName="../data/fb_test_out." .. opt.dataset .. opt.batchSize .. ".txt"

if opt.network == '' then
  -- define model to train

  print("load emb")
  word_emb=nn.LookupTable(Vocab_word,opt.dimension)
  relation_emb=nn.LookupTable(Vocab_relation,opt.dimension)
  relation_emb.weight:uniform(-0.08, 0.08)
  word_emb.weight=torch.load(word_emb_file)

  mlp11=nn.Sequential()
  mlp11:add(word_emb)  
  mlp11:add(nn.Sum(1))
  -- mlp1:add(nn.Tanh())

  mlp12=nn.Sequential()
  mlp12:add(relation_emb)
  mlp12:add(nn.Sum(1))
  -- mlp2:add(nn.Tanh())

  prl=nn.ParallelTable();
  prl:add(mlp11); prl:add(mlp12)

  mlp1=nn.Sequential()
  mlp1:add(prl)
  -- mlp1:add(nn.CosineDistance())
  mlp1:add(nn.DotProduct())
  
  mlp2=mlp1:clone('weight','bias','gradWeight','gradBias')
  model=nn.Sequential()
  prla=nn.ParallelTable()
  prla:add(mlp1)
  prla:add(mlp2)
  model:add(prla)
  -- retrieve parameters and gradients
  parameters,gradParameters = model:getParameters()
  -- parameters:uniform(-0.08, 0.08)
  -- verbose
  print('<qa> using model:')
  print(model)

  -- set criterion
  -- local margin=opt.margin
  crit=nn.MarginRankingCriterion(opt.margin); 
else 
  mlp1 = torch.load(opt.network)
end

-- this matrix records the current confusion across classes
confusion = optim.ConfusionMatrix({1,-1})
-- log results to files
trainLogger = optim.Logger(paths.concat(opt.save, 'train.log'))

function shrink( x )
  local n=x[1]
  local x_new = torch.Tensor(n)
  for i=1,n do
    x_new[i]=x[i+1]
  end
  return x_new
end

-- training function
function train(dataset)
   -- epoch tracker
   epoch = epoch or 1

   -- local vars
   local time = sys.clock()
   -- shuffle at each epoch
   -- shuffle = torch.randperm(dataset:size())
   shuffle = torch.randperm(dataset:size()[1])
   -- do one epoch
   print('<trainer> on training set:')
   print("<trainer> online epoch # " .. epoch .. ' [batchSize = ' .. opt.batchSize .. ']')
   for t = 1,dataset:size()[1],opt.batchSize do
      -- create mini batch
      local inputs = {}
      local targets = {}
      local k = 1
      for i = t,math.min(t+opt.batchSize-1,dataset:size()[1]) do
         -- load new sample
         local sample = dataset[shuffle[i]]
         -- local input = sample[1]
         -- local target = sample[2]
         -- local input = {{sample[1],sample[2]},{sample[1],sample[3]}}
         local x=shrink(sample[1])
         local y=shrink(sample[2])
         local z=shrink(sample[3])
         local input = {{x,y},{x,z}}
         local target = 1
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
            if predict>=opt.margin then confusion:add(1, targets[i]) else confusion:add(-1, targets[i]) end
            
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
         print(' - progress in batch: ' .. t .. '/' .. dataset:size()[1])
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
         xlua.progress(t, dataset:size()[1])
      
      elseif opt.optimization == 'ADAGRAD' then
         adagradState=adagradState or {
            learningRate=opt.learningRate,
            paramVariance=opt.paramVariance
         }

         optim.adagrad(feval,parameters,adagradState)
         
         -- disp progress
         xlua.progress(t, dataset:size()[1])
      
      elseif opt.optimization == 'ADAM' then
         local adam_state = {}
         local config = {}
         config.learningRate=opt.learningRate
         optim.adam(feval, parameters, config ,adam_state)
         -- disp progress
         xlua.progress(t, dataset:size()[1])
         
      elseif opt.optimization == 'ADADELTA' then
         local config={}
         local adadeltaState={}
         optim.adadelta(feval,parameters,config,adadeltaState)
         -- disp progress
         xlua.progress(t, dataset:size()[1])

      elseif opt.optimization == 'RMSPROP' then
        local config={}
        local rmspropState={}
        config.learningRate=opt.learningRate
        optim.rmsprop(feval,parameters,config,rmspropState)
        -- disp progress
        xlua.progress(t, dataset:size()[1])
      else
         error('unknown optimization method')
      end
   end
   
   -- time taken
   time = sys.clock() - time
   time = time / dataset:size()[1]
   print("<trainer> time to learn 1 sample = " .. (time*1000) .. 'ms')

   -- print confusion matrix
   print(confusion)
   trainLogger:add{['% mean class accuracy (train set)'] = confusion.totalValid * 100}
   confusion:zero()

   -- save/log current net
   local filename = paths.concat(opt.save, 'qa_'..opt.dataset..'.net')
   os.execute('mkdir -p ' .. sys.dirname(filename))
   if paths.filep(filename) then
      os.execute('mv ' .. filename .. ' ' .. filename .. '.old')
   end
   -- print('<trainer> saving network to '..filename)
   -- torch.save(filename, mlp1)

   -- next epoch
   epoch = epoch + 1
end


function computeF1(goldList,predictedList)
  -- Assume all questions have at least one answer
  -- print("gold",goldList)
  -- print("pred",predictedList)
  if #goldList==0 then
    error({mss="gold list may not be empty"})
  end
  -- If we return an empty list recall is zero and precision is one
  if #predictedList==0 then
    return {0,1,0}
  end
  -- It is guaranteed now that both lists are not empty
  local precision = 0
  for i,entity in ipairs(predictedList) do
    for j,gold in ipairs(goldList) do
      if entity==gold then
        precision=precision+1
      end
    end
  end
  precision = precision / #predictedList
  local recall=0
  for i,entity in ipairs(goldList) do
    for j,pred in ipairs(predictedList) do
      if entity==pred then
        recall=recall+1
      end
    end
  end
  recall = recall / #goldList
  local f1 = 0
  if precision+recall>0 then
    f1 = 2*recall*precision / (precision + recall)
  end
  return {recall,precision,f1}
end
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
  local averageRecall=0
  local averagePrecision=0
  local averageF1=0
  local count=0
  outPutFile = io.open(outPutFileName, "w")
  local test=io.open(testDataFileName)
  for i=1,testDataSize do
      local qa=test:read("*line"):split(" # ")
      local Q_text=qa[1]
      local Answers=qa[2]
      local answers, pos, err = json.decode (Answers, 1, nil)
      local question_code=test:read("*line"):split(" ")
      local x=createSparseVector(question_code)
      local score_table={}
      local index=1
      while true do
        local line=test:read("*line")
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
      local predicatesSet={}
      local j=1
      local max_score=score_table[1][2]
      for key,value in pairs(score_table) do
        local cu_score=value[2]
        local diff=max_score-cu_score
        if diff>opt.margin*opt.threshold then
          break
        else
          predicatesSet[value[1]]=true
        end
        j=j+1
      end
      predicates={}
      for k,v in pairs(predicatesSet) do
        table.insert(predicates,k)
      end
      local stat = computeF1(answers,predicates)
      local recall=stat[1]
      local precision=stat[2]
      local f1=stat[3]
      averageRecall = averageRecall + recall
      averagePrecision = averagePrecision + precision
      averageF1 = averageF1 + f1
      count = count+1
      local predicates_str = json.encode (predicates, { indent = true })
      -- Opens a file in write
      outPutFile:write(table.concat({Q_text,Answers,predicates_str},"\t"),"\n")  
  end
  -- Print final results
  averageRecall = averageRecall / count
  averagePrecision = averagePrecision / count
  averageF1 = averageF1 / count
  print ("Number of questions: ", count)
  print ("Average recall over questions: ",averageRecall)
  print ("Average precision over questions: " ,averagePrecision)
  print ("Average f1 over questions (accuracy): ", averageF1)
  averageNewF1 = 2 * averageRecall * averagePrecision / (averagePrecision + averageRecall)
  print ("F1 of average recall and average precision: ", averageNewF1)
  -- close output file
  outPutFile:close()
end

while true do
  -- train
  if opt.network=='' then
    train(trainData)
  end
  test2(testFile,outPutFileName)
  -- os.execute('./evaluation.py ' .. outPutFileName)
  print("")
  -- plot errors
   if opt.plot then
      trainLogger:style{['% mean class accuracy (train set)'] = '-'}
      trainLogger:plot()
   end
end
