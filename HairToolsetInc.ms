
struct ChannelUtility
(
	Fn CreateChannel obj channelName = 
	(
		local mapNum = polyOp.getNumMaps obj 
		clumpBufferExist = false
		
		for m = 1 to mapNum do 
		(
			local channelName = getUserProp obj ("MapChannel:" + (m as string))
			print channelName
			if channelName == channelName then clumpBufferExist = true
		)
		if not clumpBufferExist then 
		(
			channelInfo.addChannel obj
			channelInfo.NameChannel obj 3 mapNum channelName
		)
		channelInfo.Update ()
	)
)
