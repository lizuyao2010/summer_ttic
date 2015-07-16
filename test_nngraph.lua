require "nn"
require "nngraph"
torch.setdefaulttensortype('torch.FloatTensor')
opt={}
opt.dimension=100
Vocab_word=5000
word_emb=nn.LookupTable(Vocab_word,opt.dimension)
w1=word_emb()
w2=word_emb:clone()()
kw=2
conv=nn.TemporalConvolution(opt.dimension,opt.dimension,kw,1)
gram_1=nn.Sum(1)(conv(w1))
gram_2=nn.Sum(1)(conv:clone()(w2))
gap_gram = nn.CAddTable(1)({gram_1, gram_2})
gmod = nn.gModule({w1,w2}, {gap_gram})
x1=torch.Tensor{1,3,5}
x2=torch.Tensor{2,4}
x={x1,x2}
-- y=nn.LookupTable(Vocab_word,opt.dimension):forward(torch.Tensor{1,3,5})
print(x1,x2)
print(gmod:forward(x))


-- draw graph (the forward graph, '.fg')
-- graph.dot(mlp.fg, 'MLP')