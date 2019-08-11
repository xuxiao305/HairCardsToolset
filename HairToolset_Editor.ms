Fn CheckMesh obj = 
(
	if classof obj != Editable_Poly then return false

	local meshOK = true

	local channelUsage = #(0,2,3,4)
	try (

		for i in channelUsage do 
		(
			if (meshop.getNumMapVerts obj.mesh i) != obj.mesh.verts.count then 
				meshOK = false
		)
	)

	catch (meshOK = false)


	local yesNoCancel
	if not meshOK then 
	(
		yesNoCancel = yesNoCancelBox (obj.name + " need to be initilized first, continue?")

		if yesNoCancel == #Yes then 
		(
			select obj
			channelInfo.ClearChannel obj 0
			macros.run "Modifier Stack" "Convert_to_Poly"
			polyop.setVertColor obj 0 obj.verts black

			chanUtil.CreateChannel obj ChannelName_CurveParams
			
-- 			if chanUtil.GetChannelIndex obj ChannelName_InitialPosition == false do 
-- 			(
				channelInfo.CopyChannel obj 1 0
				local chanInitPosIndex = chanUtil.CreateChannel obj ChannelName_InitialPosition
				if chanInitPosIndex != false then
					channelInfo.PasteChannel obj 3 chanInitPosIndex

				local chanClumpingPosIndex = chanUtil.CreateChannel obj ChannelName_ClumpingPos
				if chanClumpingPosIndex != false then
					channelInfo.PasteChannel obj 3 chanClumpingPosIndex
			-- 			)

			macros.run "Modifier Stack" "Convert_to_Poly"

			return true 
		)
		else 
		(
			return false
		)
	)
	else 
	(
		return true
	)
)

struct VertexCluster
(
	obj,
	vertexArr,
	vertexArrDist,
	clusterPos,

	fn getPointsInRadius samplePos r _gradDir _selVerts = 
	(
		local _vertexArr = #()
		local _vertDistance = #()

		for v in _selVerts do 
		(
			local _dist = distance samplePos obj.verts[v].pos

			if _dist > r then 
			(
				continue
			)

			if _gradDir != 0 then 
			(
				local v1 = normalize (obj.verts[v].pos - samplePos)
				local v2 = normalize _gradDir
				if (dot v1 v2 ) < 0 then
				(
					continue
				)
			)

			append _vertexArr v
			append _vertDistance _dist
		)
		return #(_vertexArr, _vertDistance)
	),

	fn getVertexArr _samplePos _r _gradDir _selVerts =
	(
		local closestPointsInfo = getPointsInRadius _samplePos _r _gradDir _selVerts
		
		return closestPointsInfo	
	),

	fn computeClusterPos _vertexArr = 
	(
		local _clusterPos = point3 0 0 0
		for v in _vertexArr do 
		(
			local newPos = obj.verts[v].pos / (_vertexArr.count as float)
			_clusterPos = _clusterPos + newPos
		)

		return _clusterPos
	)

)


Fn GetTopVert obj vertsArr =
(
	local topVertPos = point3 0 0 0
	local topVertIndex = 0

	for v in vertsArr do 
	(
		local pos = obj.verts[v].pos
		if pos[3] > topVertPos[3] then 
		(
			topVertPos = pos
			topVertIndex = v
		)
	)

	return #(topVertPos, topVertIndex)
)
	
Fn ComputeInitialGradDirection _vertCluster _startSamplePos _selVerts = 
(
	local _closestPointsInfo0 = (_vertCluster.getVertexArr _startSamplePos sampleRadius 0 _selVerts)
	local _closestPointsInfo1 = (_vertCluster.getVertexArr _startSamplePos (sampleRadius * 2.0) 0 _selVerts)

	local _clusterPos0 = _vertCluster.computeClusterPos _closestPointsInfo0[1]
	local _clusterPos1 = _vertCluster.computeClusterPos _closestPointsInfo1[1]

	local _initGradDir = _clusterPos1 - _clusterPos0

	return _initGradDir
)	



Fn RefreshGuidelineList lbHairGroup obj = 
(
	if obj == undefined then return false

	AllClumpVertGroupArr = GetAllBindingGroup obj
	local guidelines = AllClumpVertGroupArr[2]
	print guidelines

	lbHairGroup.items = for i = 1 to guidelines.count collect (guidelines[i].name) 
)





Fn ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve = 
(
	if not (isValidObj hairGeo) do return false

	local selFaces = polyop.getFaceSelection hairGeo
	local selVerts = (polyop.getVertsUsingFace hairGeo selFaces) as array
	if selVerts.count == 0 do return false

	local guideline = GetGuideline hairGeo selVerts
	if guideline == undefined do return false 
	
	local chanCurveParamIndex = chanUtil.GetChannelIndex hairGeo ChannelName_CurveParams
	local chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition


	for v in selVerts do 
	(
		local param = (polyop.getMapVert hairGeo chanCurveParamIndex v)[1]

		local guideWorldMat = GuideWorldMatrix guideline param

		-- twist
		local twistPercent = (getValue ccTwistCurve.curves[1] 0f param)

		local invGuideWorldMat = inverse guideWorldMat

		local originalPos = polyop.getMapVert hairGeo chanInitPosIndex v 

		local localVertMat = transMatrix (originalPos + hairGeo.pos) 

		localVertMat = localVertMat * invGuideWorldMat
		
		local sinT = sin(twistPercent * 180.0)
		local cosT = cos(twistPercent * 180.0)
		local twistMat = Matrix3 (point3 1 0 0) (point3 0 cosT sinT) (point3 0 -sinT cosT) (point3 0 0 0)

		local twistWorldMat = localVertMat * twistMat * guideWorldMat

		-- clumping 
		local clumpPercent = 1.0 - (getValue ccClumpingCurve.curves[1] 0f param)
		local clumpPos = guideWorldMat.translation
		local twistPos = twistWorldMat.translation

		hairGeo.verts[v].pos = twistPos * (1 - clumpPercent) + clumpPos * clumpPercent

	)


	local allCurveInfo = crvUtil.GetCurveInfo AllClumpingCurveControl
	crvUtil.SaveCurveInfo hairGeo allCurveInfo guideline
)

Fn SetSelectionAsHairObj = 
(
	if selection.count != 1 then return false
	if classof selection[1] != Editable_Poly then return false

	return selection[1] 
)

Fn AddGuideline lbHairGroup = 
(
	if hairGeo == undefined then return false

	clearListener()
	local selFaces = polyop.getFaceSelection hairGeo
	if (selFaces as array).count == 0 then return false 

	local selVerts = polyop.getVertsUsingFace hairGeo selFaces

	
	hairGeo.showVertexColors = on

	CleanupInValidGuideline()

	local guideline = CreateGuidelineFromVerts hairGeo selVerts

	format "btnAddClumping guideline % \n" guideline.name
	InitializeHairGuideline guideline

	ApplyClumping guideline hairGeo selVerts
	
	BindGuideline hairGeo selVerts guideline
	SaveGuidelineData guideline 1000

	RefreshGuidelineList lbHairGroup hairGeo
	lbHairGroup.selection = lbHairGroup.items.count

	-- Save the curve infomation 
	local allCurveInfo = crvUtil.GetCurveInfo AllClumpingCurveControl

	crvUtil.SaveCurveInfo hairGeo allCurveInfo guideline

	return true
		
)
Fn RemoveGuidelineBinding lbHairGroup = 
(
	if hairGeo == undefined then return false

	clearListener()

	local selFaces = polyop.getFaceSelection hairGeo
	local selVerts = polyop.getVertsUsingFace hairGeo selFaces 
	if selVerts.count == 0 then return false 

	polyop.setVertColor hairGeo 0 selVerts black

	RefreshGuidelineList lbHairGroup hairGeo 

	local chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition

	for v in (selVerts as array) do 
	(
		local localPos = polyop.getMapVert hairGeo chanInitPosIndex v 
		local newWorldPos = hairGeo.pos + localPos
		hairGeo.verts[v].pos = newWorldPos
	)
)

Fn ReSampleGuideline = 
(
	if hairGeo == undefined then return false 
	clearListener()
	selFaces = polyop.getFaceSelection hairGeo
	selVerts = (polyop.getVertsUsingFace hairGeo selFaces) as array

	if selVerts.count == 0 then return false 

	local guideline = GetGuideline hairGeo selVerts

	ApplyClumping guideline hairGeo selVerts
)

Fn RelaxHairCards = 
(
	if hairGeo == undefined then return false 
	clearListener()
	selFaces = polyop.getFaceSelection hairGeo
	selVerts = (polyop.getVertsUsingFace hairGeo selFaces) as array

	if selVerts.count == 0 then return false 

	local guideline = GetGuideline hairGeo selVerts

	RelaxHairCardsUsingGuideline guideline hairGeo selVerts
)

Fn UpdateVertBindingPosition = 
(
	if hairGeo == undefined then return false 

	clearListener()

	local selFaces = polyop.getFaceSelection hairGeo
	local selVerts = polyop.getVertsUsingFace hairGeo selFaces 

	if selVerts.count == 0 then return false 
	
	polyop.setVertColor hairGeo 0 selVerts black

	RefreshGuidelineList HairEditor.lbHairGroup hairGeo 

	local chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition

	for v in (selVerts as array) do 
	(
		local localPos = hairGeo.verts[v].pos - hairGeo.pos
		polyop.setMapVert hairGeo chanInitPosIndex v localPos
	)
)


rollout HairEditor "Hair Editor"
(
	button btnSetHairObj "Pick Hair Mesh" align:#left width:360 
	button btnRelax "Relax" align:#left width:120 across:3
	button btnAddClumping "Add Clumping" align:#middle width:120 across:3
	button btnRemoveGuidelineBinding "Remove Clumping"  align:#right width:120 across:3

	button btnRefresh "Refresh" align:#left width:120 across:3
	button btnResampleGuilde "Resample Guideline" align:#middle width:120 across:3
	button btnUpdateInitialPos "Update Initial Pos" align:#right width:120 across:3 
	button btnSelectUnusedGuideline "Select Unused" align:#right width:120 


	listbox lbHairGroup "Hair Group" align:#left width:130 height:30

	CurveControl ccClumpingCurve "Clumping Curve:"	height:200 width:350 align:#left numCurves:1 visible:true
														x_range:[0.0,1.0] y_range:[0.0,1.0]
														scrollValues:[0.0,1.0] commandMode:#move_xy
														uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


	CurveControl ccTwistCurve "Twist Curve:"	height:200 width:350 align:#left numCurves:1 visible:true
														x_range:[0.0,1.0] y_range:[0.0,1.0]
														scrollValues:[0.0,1.0] commandMode:#move_xy
														uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


	on HairEditor open do 
	(
		zoom ccClumpingCurve #all
		zoom ccTwistCurve #all

		AllClumpingCurveControl = #(ccClumpingCurve, ccTwistCurve)
	)

	on btnSetHairObj pressed do 
	(
		gc()
		hairGeo = SetSelectionAsHairObj()

		local isClumpingMeshValid = CheckMesh hairGeo
		
		if isClumpingMeshValid then 
		(
			btnSetHairObj.caption = hairGeo.name
			
			RefreshGuidelineList lbHairGroup hairGeo
		
		)
		else 
		(
			messagebox "Invalid hair object"
		)
		gc()

	)
	on btnRelax pressed do 
	(
		RelaxHairCards()

	)
	on btnRefresh pressed do 
	(
		RefreshGuidelineList lbHairGroup hairGeo
		zoom ccClumpingCurve #all 
		zoom ccTwistCurve #all 
	)

	on lbHairGroup selected itm do 
	(
		local verts = AllClumpVertGroupArr[1][(lbHairGroup.selection as integer)]
		polyop.setFaceSelection hairGeo (polyop.getFacesUsingVert hairGeo verts)
		
		selFaces = polyop.getFaceSelection hairGeo
		selVerts = (polyop.getVertsUsingFace hairGeo selFaces as array)

		local guideline = GetGuideline hairGeo selVerts
		local curveInfo = execute (crvUtil.LoadCurveInfo hairGeo guideline)

		for i = 1 to AllClumpingCurveControl.count do
		(
			crvUtil.SetCurveinfo curveInfo[i] AllClumpingCurveControl[i].curves[1] 
		)
		
		print curveInfo
		ForceCompleteRedraw()
	)


	on btnAddClumping pressed do 
	(
		local successed = AddGuideline lbHairGroup
		if successed then 
		(
			ccClumpingCurve.curves[1].points[1].value = point2 0 1
			ccClumpingCurve.curves[1].points[2].value = point2 1 0
			ccTwistCurve.curves[1].points[1].value = point2 0 0
			ccTwistCurve.curves[1].points[2].value = point2 0 0

			zoom ccClumpingCurve #all 
			zoom ccTwistCurve #all 
		)
	)

	on btnResampleGuilde pressed do 
	(
		ReSampleGuideline()
	)

	on btnRemoveGuidelineBinding pressed do 
	(
		RemoveGuidelineBinding lbHairGroup
	)

	on btnUpdateInitialPos pressed do 
	(
		UpdateVertBindingPosition()
	)

	on btnSelectUnusedGuideline pressed do 
	(
		SelectNotUsedGuideline()
	)

	on ccClumpingCurve ptChanged ci val do
	(
		clearListener()
		ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve

	) 

	on ccClumpingCurve tangentChanged ci val type do 
	(
		clearListener()
		ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve
	)

	on ccTwistCurve ptChanged ci val do
	(
		clearListener()
		ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve
	) 

	on ccTwistCurve tangentChanged ci val type do 
	(
		clearListener()
		ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve
	)
)

