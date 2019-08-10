(

guideColStep = 4

---------------------------------------------------------------
-------------- Guildeline Managing Functions  -----------------
Fn SampleGuildeLine guideline obj selVerts = 
(
	for v in selVerts do 
	(
		local paramOnCurve = nearestPathParam guideline obj.verts[v].pos
		local posOnCurve = interpCurve3D guideline 1 paramOnCurve

		local clumpingPos = obj.verts[v].pos + (posOnCurve - obj.verts[v].pos) * paramOnCurve

		obj.verts[v].pos = clumpingPos

		local localPos = clumpingPos - obj.pos

		polyop.setMapVert obj 1 v localPos 

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


Fn GetGuideline hairGeo vertIndexArr = 
(
	local vertIndex = vertIndexArr[1]
	local col = getVertColor hairGeo.mesh vertIndex
	local clumpingGuideIndex = 0

	if col.r > 0 then clumpingGuideIndex = (col.r - guideColStep) / guideColStep
	else if col.g > 0 then clumpingGuideIndex = ((col.g - guideColStep) / guideColStep) + (guideColStep - 1)
	else clumpingGuideIndex = ((col.b - guideColStep) / guideColStep) + (guideColStep * 2 - 1)


	if clumpingGuideIndex != 0 then 
		return AllGuideline[clumpingGuideIndex]
	else 
		return undefined
)

Fn BindGuideline hairGeo verts =
(
	local col = black
	if AllGuideline.count < guideColStep then 
		col = color ((AllGuideline.count + 1) * guideColStep) 0 0
	else if AllGuideline.count < guideColStep * 2 then 
		col = color 0 ((AllGuideline.count - (guideColStep - 1)) * guideColStep) 0
	else if AllGuideline.count < guideColStep * 3 then 
		col = color 0 0 ((AllGuideline.count - (guideColStep * 2 - 1)) * guideColStep)

	polyop.setVertColor hairGeo 0 verts col

)

Fn GetAllBindingGroup obj = 
(
	allColor = #()
	allClumpingVertArr = #()

	for i = 1 to 3 do 
	(
		for c = guideColStep to 256 by guideColStep do 
		(
			local newCol = black
			if i == 1 do newCol = color c 0 0
			if i == 2 do newCol = color 0 c 0
			if i == 3 do newCol = color 0 0 c

			vertArr = (meshop.getVertsByColor obj.mesh newCol 0 0 0) as array 
			if vertArr.count > 0 do append allClumpingVertArr vertArr 
		)
	)
	return allClumpingVertArr
)
-------------- Guildeline Managing Functions End --------------
---------------------------------------------------------------


Fn BuildHairCardMesh guideline = 
(
	local vertArr = #()
	local faceArr = #()
	local paramsArr = #()

	local sampleNum = 10
	local width = 10.0

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
			append vertArr worldPos.translation
			append paramsArr param
		)
	)

	for v = 1 to (vertArr.count - 2) do 
	(
		if (mod v 2 == 0) then 
			append faceArr [v,v+1,v+2]
		else 
			append faceArr [v,v+2,v+1]
	)

	local newHairCard = mesh vertices:vertArr faces:faceArr
	newHairCard.backfacecull = off
	select newHairCard 
	macros.run "Modifier Stack" "Convert_to_Poly"

	chanIndex = chanUtil.CreateChannel newHairCard ChannelName_InitialPosition
	channelInfo.CopyChannel newHairCard 1 0
	channelInfo.PasteChannel newHairCard 3 chanIndex

	paramChannelIndex = chanUtil.CreateChannel newHairCard ChannelName_CurveParams

	macros.run "Modifier Stack" "Convert_to_Poly"


	for v = 1 to vertArr.count do 
	(
		polyop.setMapVert newHairCard paramChannelIndex v (point3 paramsArr[v] 0 0)
	)

	BindGuideline newHairCard (for v in newHairCard.verts collect v.index)

	return newHairCard
)



Fn DeformHairCards hairGeo vertArr = 
(
-- 	allCurvePos = execute(getUserPropBuffer $)
	allCurvePos = execute(getUserProp "SplineData" $)

	for v = 1 to vertArr.count do 
	(
		local param = (polyop.getMapVert hairGeo paramChannelIndex v)[1]
		local index = ((param * (allCurvePos.count - 1)) as integer) + 1

		local prevCurveMat = GuideWorldMatrixFromSparsingData allCurvePos index
		local invPrevCurveMat = inverse prevCurveMat

		local newWorldMat = GuideWorldMatrix $ param
		
		local newVertPosMat = transMatrix hairGeo.verts[v].pos
		newVertPosMat = newVertPosMat * invPrevCurveMat * newWorldMat

		hairGeo.verts[v].pos = newVertPosMat.translation
	)
)

Fn InitializeHairGuideline guideline = 
(
	setUserProp guideline "SplineData" #()
	setUserProp guideline "LinkedHairGeo" #()
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
			append AllGuideline selection[1]
			selection[1].name = "HairGuide_" + (AllGuideline.count as string)
			InitializeHairGuideline selection[1]

			return true
		)
		
		return false
	)
	return true

)





Fn AddLinkedHairCardsVerts guideline newHairGeo = 
(
	local linkedHairMesh = execute( getUserProp guideline "LinkedHairGeo")
	local index = findItem linkedHairMesh newHairGeo.name

	if index == 0 then 
	(
		append linkedHairMesh newHairGeo.name
		setUserProp guideline "LinkedHairGeo" linkedHairMesh

		local n = "LinkedVertArr_" + (newHairGeo.name)
		local p = for vert in newHairGeo.verts collect vert.index
		SetArrayProperty guideline n p
	)	
)


Fn UpdateLinkedHairCardsVerts guideline hairGeo verts = 
(
	local linkedHairMesh = execute( getUserProp guideline "LinkedHairGeo")
	local index = findItem linkedHairMesh newHairGeo.name
	
	if index == 0 then return false 
	
	local linkedVertArr = execute (getUserProp guideline "LinkedVertArr")
	linkedVertArr[index] = (for v in verts collect v)
	SetArrayProperty guideline "LinkedVertArr" linkedVertArr

)

Fn RemoveLinkedHairCardsVerts guideline hairGeo =
(
	local linkedHairMesh = execute( getUserProp guideline "LinkedHairGeo")
	local index = findItem linkedHairMesh newHairGeo.name
	
	if index == 0 then return false 

	linkedHairMesh = deleteItem linkedHairMesh index

	setUserProp guideline "LinkedHairGeo" linkedHairMesh

	local linkedVertArr = execute (getUserProp guideline "LinkedVertArr")
	linkedVertArr = deleteItem linkedVertArr index

	SetArrayProperty guideline "LinkedVertArr" linkedVertArr
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

-- 	setUserPropBuffer guideline  (allPos as string)
	setUserProp guideline "SplineData" (allPos as string)

)


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
				AddLinkedHairCardsVerts sp newHairCard  
			)
		)
			
	)
)

Fn OnSplineUpdate ev nd = 
(
	if ClassOf(GetAnimByHandle nd[1]) != line then return()

	vertArr = for v in m.verts collect v.index
	DeformHairCards m vertArr
	SaveGuidelineData $ 1000  

)




callbackItem = undefined
gc light:true

callbackItem = NodeEventCallback mouseUp:true geometryChanged:OnSplineUpdate
)