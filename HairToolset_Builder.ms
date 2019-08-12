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

Fn SetGuideline guideline = 
(
	crvUtil.InitCurveData guideline

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

Fn SpawnTemplateMesh targetGuideline templateMesh = 
(
	local vertArr = #()

	for vert in templateMesh.verts do 
	(
		local chanIndex = chanUtil.GetChannelIndex templateMesh ChannelName_CurveParams
		local param = meshop.getMapVert templateMesh.mesh chanIndex vert.index

		-- use the vertex position create the local matrix related to point.x value
		local localVertMat = TransMatrix (point3 0 vert.pos.y vert.pos.z) 

		local newGuidelineMat = GuideWorldMatrix targetGuideline param.x

		local newWorldMat = localVertMat * newGuidelineMat

		append vertArr newWorldMat.translation
	)
	spawnedMesh = CompleteCloneObj templateMesh
	
	spawnedMesh.name = "newMesh"

	for v = 1 to spawnedMesh.verts.count do 
	(
		spawnedMesh.verts[v].pos = vertArr[v]
	)

	local vertArr = for v = 1 to spawnedMesh.verts.count collect v
	BindGuideline spawnedMesh vertArr targetGuideline
)

Fn TransferMeshToAnotherGuideline targetGuideline templateMesh = 
(
	local vertArr = #()
	local guideline = GetGuideline templateMesh #(1)

	for vert in templateMesh.verts do 
	(
		local param = nearestPathParam guideline vert.pos
		local oldGuidelineMat = GuideWorldMatrix guideline param
		local invOldGuidelineMat = inverse oldGuidelineMat

		local newGuidelineMat = GuideWorldMatrix targetGuideline param

		local localVertMat = (TransMatrix vert.pos) * invOldGuidelineMat
		local newWorldMat = localVertMat * newGuidelineMat

		append vertArr newWorldMat.translation
	)
	local spawnedMesh = undefined
	local lst = undefined
	maxops.clonenodes templateMesh actualNodeList:&lst newNodes:&spawnedMesh
	spawnedMesh = spawnedMesh[1]

	spawnedMesh.name = "newMesh"


	for v = 1 to spawnedMesh.verts.count do 
	(
		spawnedMesh.verts[v].pos = vertArr[v]
	)
)


-------------- Guildeline Managing Functions End --------------
---------------------------------------------------------------


-------------- Template Mesh Functions  -----------------------
---------------------------------------------------------------
Fn SetTemplateMesh geo = 
(
	clearListener()
	select geo
	chanUtil.CleanChannels geo
	macros.run "Modifier Stack" "Convert_to_Poly"
	local bb = nodeGetBoundingBox geo geo.transform
	bbLengthX = abs(bb[1][1]) + abs(bb[2][1])
	bbLengthY = abs(bb[1][2]) + abs(bb[2][2])
	bbLengthZ = abs(bb[1][3]) + abs(bb[2][3])

	local bbLengthMain = bbLengthX
	local bbLengthSecondary = bbLengthY
	local bbLengthTetiry = bbLengthZ



/* 	local bbAxisMain = 1
	if bbLengthMain < bbLengthY then 
	(
		bbLengthMain = bbLengthY
		bbAxisMain = 2
	)
	if bbLengthMain < bbLengthZ then 
	(
		bbLengthMain = bbLengthZ
		bbAxisMain = 3
	)
 */
	

	chanIndex = chanUtil.CreateChannel geo ChannelName_InitialPosition
	channelInfo.CopyChannel geo 1 0
	channelInfo.PasteChannel geo 3 chanIndex

 	chanUtil.CreateChannel geo ChannelName_CurveParams

 	chanUtil.CreateChannel geo ChannelName_ManualPosition
 	chanUtil.CreateChannel geo ChannelName_ClumpOffset

 	macros.run "Modifier Stack" "Convert_to_Poly"
 	local paramChannelIndex = chanUtil.GetChannelIndex geo ChannelName_CurveParams
 	local manualChannelIndex = chanUtil.GetChannelIndex geo ChannelName_ManualPosition
 	local preManualChannelIndex = chanUtil.GetChannelIndex geo ChannelName_ClumpOffset

	for v = 1 to geo.verts.count do 
	(
		if bbLengthMain < 0.001 then sampleX = 0
		else sampleX = (geo.verts[v].pos[1] - bb[1][1]) / bbLengthMain

		if bbLengthSecondary < 0.001 then sampleY = 0
		else sampleY = (geo.verts[v].pos[2] - bb[1][2]) / bbLengthSecondary

		if bbLengthTetiry < 0.001 then sampleZ = 0
		else sampleZ = (geo.verts[v].pos[3] - bb[1][3]) / bbLengthTetiry
		
		polyop.setMapVert geo paramChannelIndex v (point3 sampleX sampleY sampleZ) 
		polyop.setMapVert geo manualChannelIndex v (point3 0 0 0) 
		polyop.setMapVert geo preManualChannelIndex v (point3 0 0 0) 
		
	)
)
-------------- Template Mesh Functions End---------------------
---------------------------------------------------------------


-------------- Deform Resolving Functions  --------------------
---------------------------------------------------------------

Fn GetTwistMat ccTwistCurve param = 
(
	local twistPercent = (getValue ccTwistCurve.curves[1] 0f param)
	local sinT = sin(twistPercent * 180.0)
	local cosT = cos(twistPercent * 180.0)
	local twistMat = Matrix3 (point3 1 0 0) (point3 0 cosT sinT) (point3 0 -sinT cosT) (point3 0 0 0)		

	return twistMat
)

Fn GetClumpingOffset ccClumpingCurve param guideWorldMat preClumpingPos = 
(
	local clumpPercent = 1.0 - (getValue ccClumpingCurve.curves[1] 0f param)
	local clumpOffset = (guideWorldMat.translation - preClumpingPos) * clumpPercent

	return clumpOffset 
)


Fn ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve = 
(
	if not (isValidObj hairGeo) do return false

	local selFaces = polyop.getFaceSelection hairGeo
	local selVerts = (polyop.getVertsUsingFace hairGeo selFaces) as array
	if selVerts.count == 0 do return false

	local guideline = GetGuideline hairGeo selVerts
	if guideline == undefined do return false 
	
	chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition
	chanCurveParamIndex = chanUtil.GetChannelIndex hairGeo ChannelName_CurveParams
	chanManualIndex = chanUtil.GetChannelIndex hairGeo ChannelName_ManualPosition
	chanClumpOffsetIndex = chanUtil.GetChannelIndex hairGeo ChannelName_ClumpOffset

	for v in selVerts do 
	(
-- 		print v
		local param = (polyop.getMapVert hairGeo chanCurveParamIndex v)[1]
		local guideWorldMat = GuideWorldMatrix guideline param
		
		-- Twist
		local twistPercent = (getValue ccTwistCurve.curves[1] 0f param)
		local originalLocalPos = polyop.getMapVert hairGeo chanInitPosIndex v
		
		-- !! IMPORTANT -- shift X to 0 to get local position!
		originalLocalPos.x = 0
		local originalPosMat = transMatrix ( originalLocalPos ) 

		local twistMat = GetTwistMat ccTwistCurve param

		local newWorldVertPos = (originalPosMat * twistMat * guideWorldMat).translation
-- 		format "newWorldVertPos -- %\n" newWorldVertPos

		-- Manual offset
		local manualOffset = transMatrix(polyop.getMapVert hairGeo chanManualIndex v)
-- 		format "manualOffset -- %\n" manualOffset
		
		local worldManualOffset = (manualOffset * twistMat * guideWorldMat).translation 
-- 		format "twistMat -- %\n" twistMat
-- 		format "guideWorldMat -- %\n" guideWorldMat
-- 		format "worldManualOffset -- %\n" worldManualOffset

		-- Clumping
		local clumpOffset = GetClumpingOffset ccClumpingCurve param guideWorldMat newWorldVertPos 
		polyop.setMapVert hairGeo chanClumpOffsetIndex v clumpOffset
-- 		format "clumpOffset -- %\n" clumpOffset


		hairGeo.verts[v].pos = newWorldVertPos + clumpOffset + (worldManualOffset - guideWorldMat.translation)

	)
	CompleteRedraw()

	crvUtil.SaveCurveData guideline ccClumpingCurve
	crvUtil.SaveCurveData guideline ccTwistCurve


)
Fn ResolveFinalPosition2 hairGeo ccClumpingCurve ccTwistCurve = 
(
	if not (isValidObj hairGeo) do return false

	local selFaces = polyop.getFaceSelection hairGeo
	local selVerts = (polyop.getVertsUsingFace hairGeo selFaces) as array
	if selVerts.count == 0 do return false

	local guideline = GetGuideline hairGeo selVerts
	if guideline == undefined do return false 
	
	chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition
	chanCurveParamIndex = chanUtil.GetChannelIndex hairGeo ChannelName_CurveParams
	chanManualIndex = chanUtil.GetChannelIndex hairGeo ChannelName_ManualPosition


	for v in selVerts do 
	(
-- 		format "v %\n" v

		local param = (polyop.getMapVert hairGeo chanCurveParamIndex v)[1]
-- 		format "param %\n" param

		local guideWorldMat = GuideWorldMatrix guideline param
-- 		format "guideWorldMat %\n" guideWorldMat

		-- twist
		local twistPercent = (getValue ccTwistCurve.curves[1] 0f param)
		local originalLocalPos = polyop.getMapVert hairGeo chanInitPosIndex v
		-- !! IMPORTANT -- shift X to 0 to get local position!
		originalLocalPos.x = 0

		-- Add manual offset
		local manualOffset = polyop.getMapVert hairGeo chanManualIndex v
		originalLocalPos = originalLocalPos + manualOffset

		local originalPosMat = transMatrix ( originalLocalPos ) 

		local twistMat = GetTwistMat ccTwistCurve param

		local newWorldVertPos = (originalPosMat *  twistMat * guideWorldMat).translation

		local clumpOffset = GetClumpingOffset ccClumpingCurve param guideWorldMat newWorldVertPos 
		hairGeo.verts[v].pos = newWorldVertPos --+ clumpOffset

	)
	CompleteRedraw()

	crvUtil.SaveCurveData guideline ccClumpingCurve
	crvUtil.SaveCurveData guideline ccTwistCurve


)

-------------- Deform Resolving Functions End------------------
---------------------------------------------------------------


rollout HairBuilder "Hair Builder" 
(
	button btnSplineFromLine "Use Line Tool" align:#left width:120 across:3

	button btnNewHairCards "New Hair Card" align:#left width:120 across:3

	button btnSpawnTemplate "Spawn Template" align:#left width:120 across:3

	button btnSetTemplate "Set Template" align:#left width:120  across:3
	button btnSetGuideline "Set Guideline" align:#left width:120 across:3



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

	on btnSetTemplate pressed do 
	(
		if (selection.count == 1 and classof selection[1] == Editable_Poly) do 
			SetTemplateMesh selection[1] 
	)

	on btnSetGuideline pressed do 
	(
		if (selection.count == 1 and superclassof selection[1] == shape) do 
			SetGuideline selection[1]
	)

	on btnSpawnTemplate pressed do 
	(
		local templateMesh 
		local guideline

		if selection.count == 2 then 
		(
			for sel in selection do 
			(
				if classof sel == Editable_Poly then 
				(
					templateMesh = sel
				)
				else if superclassof sel ==  shape then 
				(
					guideline = sel
				)
			)
		)

		print templateMesh
		print guideline
		if templateMesh != undefined and guideline != undefined do 
			SpawnTemplateMesh guideline templateMesh
	)
)


