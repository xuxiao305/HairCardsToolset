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

-- Fn GetBindGroup obj guideline = 
-- (
-- 	local guidelineIndex = findItem AllGuideline guideline

-- 	if bindCol[1] > 0 then 
-- )

Fn GetAllBindingGroup obj = 
(
	local clumpingVertArr = #()
	local bindGuidelineArr = #()


	for guideline in AllGuideline do 
	(
		local index = GetGuidelineIndex guideline
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
-------------- Guildeline Managing Functions End --------------
---------------------------------------------------------------


Fn BuildHairCardMesh guideline = 
(
	local vertPosArr = #()
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



Fn DeformHairCards hairGeo vertArr = 
(
-- 	allCurvePos = execute(getUserPropBuffer $)
	allCurvePos = execute(getUserProp $ "SplineData")

	local paramChannelIndex = chanUtil.GetChannelIndex hairGeo ChannelName_CurveParams

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
			)
		)
			
	)
)



-- Fn OnSplineUpdate ev nd = 
-- (
-- 	local cls = ClassOf(GetAnimByHandle nd[1])
-- 	if cls != line and cls != SplineShape do return()

-- 	print "OnSplineUpdate"

-- 	bindHairGeoName = execute (getUserProp $ "LinkedHairGeo")

-- 	if bindHairGeoName != undefined then 
-- 	(
-- 		for n in bindHairGeoName do 
-- 		(
-- 			local nd = getNodeByName n
-- 			if isValidNode nd do
-- 			(
-- 				append bindHairGeo nd
				
-- 				bindVertsArr = execute (getUserProp $ ("LinkedVertArr_" + n))

-- 				vertArr = for v in nd.verts collect v.index
-- 				DeformHairCards nd vertArr
-- 				SaveGuidelineData $ 1000  

-- 			)
				 
-- 		)
-- 	)
-- )



