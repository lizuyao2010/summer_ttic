trainData=torch.load('../data/train_random_2.bin')
Vocab=2334431
function check( x )
	for i=1,x:size()[1] do
		if x[i]>Vocab then
			print(x[i])
		end
	end
end
for i=1,trainData:size()[1] do
	local x=trainData[i][1]
	local y=trainData[i][2]
	local z=trainData[i][3]
	check(x)
	check(y)
	check(z)
end