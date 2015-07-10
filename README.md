# torch code for question answering with freebase
#method1:
quesiton embedding and answer path embedding
sum over bag of word embeddings for question embedding
sum over path(relation) embeddings of answer for answer path embedding
#method2:
convolutional neural network for quesiton embedding
multi channel of question embedding
cnn kernel with kernel size 2, step size 1
#optimizers:
adagrad,adam,adadelta,sgd,rmsprop
adagrad achieves best performance, probably because of its ability to handle large dimension of parameters.
#loss function:
margin rank loss
loss=max(0,1-dot(question,correct_answer)+dot(question,incorrect_answer))
#minibatch size:
800 achieves best performance
#negative sampling size:
80 achieves best performance
#time for each epoch:
2 minutes

