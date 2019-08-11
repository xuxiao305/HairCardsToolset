---------------------------------------------------------------
-------------- Guildeline Managing Functions  -----------------

Fn SelectNotUsedGuideline = 
(
	clearSelection() 
	CleanupInValidGuideline()

	local notUsedGuideline = #()
	for guideline in AllGuideline do 
	(
		local bindGeos = FindGuidelineBinding guideline

		if bindGeos.count == 0 then append notUsedGuideline guideline
	)

	select notUsedGuideline 
)


Fn ApplyClumping guideline obj selVerts = 
(
	for v in selVerts do 
	(
		local paramOnCurve = nearestPathParam guideline obj.verts[v].pos
		local posOnCurve = interpCurve3D guideline 1 paramOnCurve

		local clumpingPos = obj.verts[v].pos + (posOnCurve - obj.verts[v].pos) * paramOnCurve

		obj.verts[v].pos = clumpingPos

		local localPos = clumpingPos - obj.pos
		local chanClumpingPosIndex = chanUtil.GetChannelIndex obj ChannelName_ClumpingPos
		polyop.setMapVert obj chanClumpingPosIndex v localPos 

		local paramChannelIndex = chanUtil.GetChannelIndex obj ChannelName_CurveParams
		polyop.setMapVert obj paramChannelIndex v (point3 paramOnCurve 0 0)
	)
)

Fn SampleGuildeLine guideline obj selVerts = 
(
	for v in selVerts do 
	(
		local paramOnCurve = nearestPathParam guideline obj.verts[v].pos

		local paramChannelIndex = chanUtil.GetChannelIndex obj ChannelName_CurveParams

		polyop.setMapVert obj paramChannelIndex v (point3 paramOnCurve 0 0)
	)
)

Fn GuideWorldMatrix guideline param = 
(
	local guidePos = interpCurve3D guideline 1 param
	local guidePosNext = interpCurve3D guideline 1 (param + 0.01)

	local tangent = normalize(guidePosNext - guidePos)

	local avgPos = ((interpCurve3D guideline 1 1) + (interpCurve3D guideline 1 0)) * 0.5
	
	local normal = normalize(guidePos - (avgPos + point3 1000 0 0))
	local binormal = normalize(cross tangent normal) 
	normal = normalize(cross binormal tangent)
	local mat = Matrix3 tangent binormal normal guidePos

	return mat
)

Fn GuideWorldMatrixFromSparsingData dataArray index = 
(
	local guidePos = dataArray[index]
	local guidePosNext = point3 0 0 0
	if (index < dataArray.count) then 
		guidePosNext = dataArray[index + 1]
	else 
		guidePosNext = dataArray[index] + (dataArray[index] - dataArray[index-1]) * 0.5

	local tangent = normalize(guidePosNext - guidePos)

	local avgPos = ((dataArray[dataArray.count]) + (dataArray[1])) * 0.5
	local normal =  normalize(guidePos - (avgPos + point3 1000 0 0))
	local binormal = normalize(cross tangent normal) 
	normal = normalize(cross binormal tangent)
	local mat = Matrix3 tangent binormal normal guidePos

	return mat
)


Fn GuideWorldMatrixGaussian guideline param = 
(
	local matArr = #()

	for i = -2 to 2 do 
	(
		local p = param + (i as float) * 0.01
		local mat = GuideWorldMatrix guideline p
		append matArr mat
	)

	return matArr
)

Fn GuideWorldMatrixFromSparsingDataGaussian dataArray index = 
(
	local guidePos = dataArray[index]
	local guidePosNext = point3 0 0 0
	if (index < dataArray.count) then 
		guidePosNext = dataArray[index + 1]
	else 
		guidePosNext = dataArray[index] + (dataArray[index] - dataArray[index-1]) * 0.5

	local tangent = normalize(guidePosNext - guidePos)

	local avgPos = ((dataArray[dataArray.count]) + (dataArray[1])) * 0.5
	local normal =  normalize(guidePos - (avgPos + point3 1000 0 0))
	local binormal = normalize(cross tangent normal) 
	normal = normalize(cross binormal tangent)
	local mat = Matrix3 tangent binormal normal guidePos

	return mat
)

Fn CleanupInValidGuideline = 
(
	for i = AllGuideline.count to 1 by -1 do
	(
		if (isValidNode AllGuideline[i] == false) then 
		(
			print "delete invalid guideline"
			deleteItem AllGuideline i 
		)
	) 
)


Fn GetGuidelineIndex guideline = 
(
	local index = getUserProp guideline "Index"
	return index
)

Fn GetGuidelineByIndex index = 
(
	for guideline in AllGuideline do 
	(
		local i = GetGuidelineIndex guideline
		if i == index do return guideline
	)
	return undefined
)

Fn GetGuideline hairGeo vertIndexArr = 
(
	local vertIndex = vertIndexArr[1]
	local col = getVertColor hairGeo.mesh vertIndex
	local guidelineIndex = RGBToInt col
	local guideline = GetGuidelineByIndex guidelineIndex 

	return guideline
)


Fn BindGuideline hairGeo verts guideline =
(
	-- Set guideline index to vertex channel 
	local guidelineIndex = GetGuidelineIndex guideline
	if guidelineIndex == undefined do return () 

	local col = IntToRGB guidelineIndex

	polyop.setVertColor hairGeo 0 verts col


	-- Set mesh vert array to guideline
	local linkedHairMesh = execute( getUserProp guideline "LinkedHairGeo")
	local index = findItem linkedHairMesh hairGeo.name

	if index == 0 then 
	(
		append linkedHairMesh hairGeo.name
		setUserProp guideline "LinkedHairGeo" linkedHairMesh
	)	
)

Fn GetAllBindingGroup obj = 
(
	if obj == undefined then return false

	local clumpingVertArr = #()
	local bindGuidelineArr = #()

	CleanupInValidGuideline()

	for guideline in AllGuideline do 
	(
		local index = GetGuidelineIndex guideline
		if index == undefined then 
			messageBox (guideline.name + " dosn't have index property")

		local col = IntToRGB index

		vertArr = (meshop.getVertsByColor obj.mesh col 0 0 0) as array 
		if vertArr.count > 0 do 
		(
			append clumpingVertArr vertArr
			append bindGuidelineArr guideline
		) 
	)

	return #(clumpingVertArr, bindGuidelineArr)
)

Fn BuildHairCardMesh guideline = 
(
	local vertPosArr = #()
	local faceArr = #()
	local paramsArr = #()

	local sampleNum = 10
	local width = 2.0

	for i = 0 to sampleNum do 
	(
		local param = (i as float) / ((sampleNum + 0.1) as float)
		local guidelineMat = GuideWorldMatrix guideline param
		local invGuideWorldMat = inverse guidelineMat

		for p = 1 to 2 do 
		(
			local localPos = point3 0  0 width

			if p == 2 then localPos.z = -localPos.z

			local vertMat = TransMatrix localPos
			local worldPos = vertMat * guidelineMat
			append vertPosArr worldPos.translation
			append paramsArr param
		)
	)

	for v = 1 to (vertPosArr.count - 2) do 
	(
		if (mod v 2 == 0) then 
			append faceArr [v,v+1,v+2]
		else 
			append faceArr [v,v+2,v+1]
	)

	local newHairCard = mesh vertices:vertPosArr faces:faceArr
	newHairCard.backfacecull = off

	select newHairCard 
	macros.run "Modifier Stack" "Convert_to_Poly"

	chanIndex = chanUtil.CreateChannel newHairCard ChannelName_InitialPosition
	channelInfo.CopyChannel newHairCard 1 0
	channelInfo.PasteChannel newHairCard 3 chanIndex

	paramChannelIndex = chanUtil.CreateChannel newHairCard ChannelName_CurveParams

	macros.run "Modifier Stack" "Convert_to_Poly"


	for v = 1 to vertPosArr.count do 
	(
		polyop.setMapVert newHairCard paramChannelIndex v (point3 paramsArr[v] 0 0)
	)

	vertIndexArr = for v in newHairCard.verts collect v.index
	BindGuideline newHairCard vertIndexArr guideline

	return newHairCard
)

Fn InitializeHairGuideline guideline = 
(
	local index = 0
	if AllGuideline.count > 0 then 
	(
		for g = 1 to AllGuideline.count do 
		(
			local i = getUserProp AllGuideline[g] "Index"
			if i != undefined and index < i do  index = i
		)
	)

	index = index + 1
	 
	setUserProp guideline "Index" index
	setUserProp guideline "SplineData" #()
	setUserProp guideline "LinkedHairGeo" #()

	guideline.name = "HairGuide_" + (index as string)	

	append AllGuideline guideline

)

Fn CheckSelectionIsGuideline  = 
(
	if selection.count != 1 then return false
	if (classof selection[1] != line) then return false

	local userInput = undefined
	if (MatchPattern selection[1].name pattern:"HairGuide_*") == false then 
	(
		userInput = yesNoCancelBox "Initialize the guideline?"

		if userInput == #yes then 
		(

			InitializeHairGuideline selection[1]

			return true
		)
		
		return false
	)
	return true

)

Fn SaveGuidelineData guideline sampleNum = 
(
	local allPos = stringstream ""

	format "#("  to:allPos
	for i = 1 to sampleNum do 
	(
		local param = (i as float) / (sampleNum as float)
		local pos = interpCurve3D guideline 1 param
		if i == sampleNum then format "%" pos to:allPos
		else format "%," pos to:allPos
	)
	format ")"  to:allPos
	setUserProp guideline "SplineData" (allPos as string)

)

Fn CreateGuidelineFromVerts obj verts = 
(
	local AllVertexCluster = #()

	local initVertCluster = VertexCluster()
	initVertCluster.obj = hairGeo

	local initialSamplePos = (GetTopVert obj verts)[1] 
	initVertCluster.clusterPos = initialSamplePos

	append AllVertexCluster initVertCluster

	local gradDir = ComputeInitialGradDirection initVertCluster initialSamplePos verts
	gradDir = normalize gradDir

	safeBreak = 0
	while gradDir.z < 0 and safeBreak < 100 do 
	(
		previousCluster = AllVertexCluster[AllVertexCluster.count]

		local samplePos = previousCluster.clusterPos + gradDir

		newVertClst = VertexCluster()
		newVertClst.obj = hairGeo
		newVertClst.vertexArr = (newVertClst.getVertexArr samplePos sampleRadius gradDir verts)[1]
		newVertClst.clusterPos = newVertClst.computeClusterPos newVertClst.vertexArr

		if newVertClst.vertexArr.count > 0 then 
		(
			append AllVertexCluster newVertClst
			gradDir = newVertClst.clusterPos - previousCluster.clusterPos
			gradDir = normalize gradDir
		)
		else 
		(
			exit
		)
		safeBreak += 1
	)

	guideline = splineShape name:("HairGuide_" + ((AllGuideline.count + 1) as string))
	addnewSpline guideline

	for c in AllVertexCluster do 
	(
		local pos = c.clusterPos
		addKnot guideline 1 #smooth #curve pos
	)
	updateShape guideline

	return guideline
)

Fn FindGuidelineBinding guideline = 
(
	local bindGeometryList = #()

	local guidelineIndex = GetGuidelineIndex guideline
	local guidelineCol = IntToRGB guidelineIndex

	local propName = trimRight ("CurveInfo_" + guideline.name) 
	for geo in geometry do 
	(
		local vertArr = (meshOp.getVertsByColor geo.mesh guidelineCol 0 0 0) as array

		if vertArr.count > 0 do append bindGeometryList geo
	)
	return bindGeometryList
)


Fn DeformHairCardsUsingGuideline guideline hairGeo vertArr = 
(
	allCurvePos = execute(getUserProp guideline "SplineData")

	local paramChannelIndex = chanUtil.GetChannelIndex hairGeo ChannelName_CurveParams

	for v = 1 to vertArr.count do 
	(
		local param = (polyop.getMapVert hairGeo paramChannelIndex v)[1]
		local index = ((param * (allCurvePos.count - 1)) as integer) + 1

		local prevCurveMat = GuideWorldMatrixFromSparsingData allCurvePos index
		local invPrevCurveMat = inverse prevCurveMat

		local newWorldMat = GuideWorldMatrix guideline param
		
		local newVertPosMat = transMatrix hairGeo.verts[v].pos
		newVertPosMat = newVertPosMat * invPrevCurveMat * newWorldMat

		hairGeo.verts[v].pos = newVertPosMat.translation
	)
)

Fn RelaxHairCardsUsingGuideline guideline hairGeo vertArr = 
(
-- 	local gaussianWeightArr = #(0.05, 0.2, 0.5, 0.2, 0.05)
	local gaussianWeightArr = #(0.2, 0.2, 0.2, 0.2, 0.2)
	local centerIndex = 3

	allCurvePos = execute(getUserProp guideline "SplineData")

	SampleGuildeLine guideline hairGeo vertArr

	local paramChannelIndex = chanUtil.GetChannelIndex hairGeo ChannelName_CurveParams

	for v = 1 to vertArr.count do 
	(
		local param = (polyop.getMapVert hairGeo paramChannelIndex v)[1]

		local guidelineMatArr = GuideWorldMatrixGaussian guideline param

		local vertPosMat = transMatrix hairGeo.verts[v].pos
		local originalMat = guidelineMatArr[centerIndex]
		local invOriginalMat = inverse originalMat

		local localVertPosMat = vertPosMat * invOriginalMat 

		local newPos = point3 0 0 0
		for i = 1 to guidelineMatArr.count do 
		(
			newPos += (localVertPosMat * guidelineMatArr[i]).translation * gaussianWeightArr[i]

			hairGeo.verts[v].pos = newPos
		)
	)
	SampleGuildeLine guideline hairGeo vertArr
)

-------------- Guildeline Managing Functions End --------------
---------------------------------------------------------------


rollout HairBuilder "Hair Builder" 
(
	button btnSplineFromLine "Use Line Tool" align:#left width:120 across:3

	button btnNewHairCards "New Hair Card" align:#left width:120 across:3

	on btnSplineFromLine pressed do 
	(
		max create mode 
		macros.run "Objects Shapes" "Lines"
	)

	on btnNewHairCards pressed do
	(
		if selection.count == 1 and (classof selection[1] == line) then 
		(
			if (CheckSelectionIsGuideline()) do 
			(
				local sp = (deepcopy (selection as array))[1]
				local newHairCard = BuildHairCardMesh sp
				SaveGuidelineData sp 1000
			)
		)
			
	)
)


