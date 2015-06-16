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

----------------------------------------------------------------------
-- parse command-line options
--
local opt = lapp[[
   -s,--save          (default "logs")      subdirectory to save logs
   -n,--network       (default "")          reload pretrained network
   --dataset          (default "web")       dataset
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
   -c,--candidates    (default 2)           number of candidates
   --margin           (default 1)           margin
   --threshold        (default 0)         threshold
   --pretrained       (default false)      load pretrained embedding
]]
-- fix seed
torch.manualSeed(1)

-- threads
torch.setnumthreads(opt.threads)
print('<torch> set nb of threads to ' .. torch.getnumthreads())


-- use floats, for SGD
if opt.optimization == 'SGD' or opt.optimization == 'ADAGRAD' or opt.optimization == 'RMSPROP' then
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
elseif opt.dataset=="web_new" then
  trainData=torch.load('../data/train_random_web_soft_index_new.bin')
  Vocab_word=3501
  Vocab_relation=3505
elseif opt.dataset=="ws" then
  trainData=torch.load('../data/train_random_ws_soft_index.bin')
  Vocab_word=51230
  Vocab_relation=6769
else
  trainData=torch.load('../data/train_random.bin')
  Vocab=2025750
end

if opt.network == '' then
  -- define model to train
  mlp1=nn.Sequential()
  

    -- RNN
    hiddenSize=opt.dimension
    rho=14
    word_emb=nn.LookupTable(Vocab_word,opt.dimension)
    r = nn.Recurrent(
       hiddenSize, word_emb, 
       nn.Linear(hiddenSize, hiddenSize), nn.Sigmoid(), 
       rho
    )
  -- r=nn.LSTM(Vocab_word,hiddenSize)
  s=nn.Sequencer(r)
    

  mlp1:add(s)
  mlp1:add(nn.JoinTable(1))
  mlp1:add(nn.Sum(1))
  -- mlp1:add(nn.Tanh())

  mlp2=nn.Sequential()
  relation_emb=nn.LookupTable(Vocab_relation,opt.dimension)

  mlp2:add(relation_emb)
  mlp2:add(nn.Sum(1))
  mlp2:add(nn.Tanh())

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
    parameters:uniform(-0.08, 0.08)
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
         local x=shrink(sample[1]):split(1)
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
   print('<trainer> saving network to '..filename)
   torch.save(filename, mlp1)

   -- next epoch
   epoch = epoch + 1
end


if opt.dataset=="web" then
  testData = torch.load('../data/test_web_soft_index.bin')
elseif opt.dataset=="web_new" then
  testData = torch.load('../data/test_web_soft_index_new.bin')
elseif opt.dataset=="ws" then
  testData = torch.load('../data/test_ws_soft_index.bin')
else
  testData = torch.load('../data/test.bin')
end



local outPutFileName="../data/fb_test_out." .. opt.batchSize .. ".txt"
-- test function
function test( testData,outPutFileName )
  collectgarbage()
  -- local vars
  local time = sys.clock()

  -- test over given dataset
  print('<trainer> on testing Set:')

  local json = require ("dkjson")

  function compare(a,b)
    return a[2] > b[2]
  end
  -- Opens a file in write
  outPutFile = io.open(outPutFileName, "w")
  local accumulator={}
  for i=1,testData:size() do
    local score_table={}
    for index=1,table.getn(testData[i])-3 do
      local x=testData[i]['question_code']
      local z=testData[i][index]['Can_code']
      local s=mlp1:forward{x,z}[1]
      score_table[index]={testData[i][index]['Can_id'],s}
    end
    table.sort(score_table,compare)
    local predicates={}
    local j=1
    local answers=testData[i]['Answers']:split(",")
    local num_answers=table.getn(answers)
    local max_score=score_table[1][2]
    for key,value in pairs(score_table) do
      predicates[j]=value[1]
      local cu_score=value[2]
      local diff=(max_score-cu_score)
      -- if j== num_answers then
      --   table.insert(accumulator,diff)
      --   break
      -- end
      if diff>=opt.margin*opt.threshold then
        table.insert(accumulator,diff)
        break
      end
      -- if j== opt.candidates then
      --   table.insert(accumulator,diff)
      --   break
      -- end
      j=j+1
    end
    local predicates_str = json.encode (predicates, { indent = true })
    outPutFile:write(table.concat({testData[i]['Q_text'],testData[i]['Answers'],predicates_str},"\t"),"\n")  
  end
  local accTensor=torch.Tensor(accumulator)
  print("average diff:",torch.mean(accTensor),torch.max(accTensor),torch.min(accTensor))
  -- close output file
  outPutFile:close()
end

while true do
  -- train
  if opt.network=='' then
    train(trainData)
  end
  test(testData,outPutFileName)
  os.execute('./evaluation.py ' .. outPutFileName)
  -- plot errors
   if opt.plot then
      trainLogger:style{['% mean class accuracy (train set)'] = '-'}
      trainLogger:plot()
   end
end
