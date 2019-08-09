(
Fn CheckMesh obj = 
(
	local yesNoCancel
	if (getNumCPVVerts obj.mesh) != obj.mesh.verts.count then 
	(
		yesNoCancel = yesNoCancelBox (obj.name + " need to clean up, continue?")

		if yesNoCancel == #Yes then 
		(
			select obj
			channelInfo.ClearChannel obj 0
			macros.run "Modifier Stack" "Convert_to_Poly"
			polyop.setVertColor obj 0 obj.verts black
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


Fn ResolveFinalPosition hairGeo ccClumpingCurve ccTwistCurve = 
(
	if not (isValidObj hairObj) do return false
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


rollout HairEditor "Hair Editor"
(
	button btnSetHairObj "Pick Hair Mesh" align:#left width:120 across:3
	button btnCreateClumping "Add Clumping" align:#middle width:120 across:3
	button btnRemoveClumping "Remove Clumping"  align:#right width:120 across:3


	button btnRefresh "Refresh" align:#left width:120 across:3
	button btnResampleGuilde "Resample Guideline" align:#middle width:120 across:3
	button btnUpdateInitialPos "Update Initial Pos" align:#right width:120 across:3 


	listbox lbHairGroup "Hair Group" align:#left width:130 height:30


	on btnSetHairObj pressed do 
	(
		hairGeo = $CHR_S_F_Hair_ST03AT_LOD0_Clumping
		hairObj = $CHR_S_F_Hair_ST03AT_LOD0 

		local isClumpingMeshValid = CheckMesh hairGeo
		local isInitialMeshValid = CheckMesh hairObj
		
		chanUtil.CreateChannel hairGeo ChannelName_CurveParams
		
		if chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition == false do 
		(
			local chanInitPosIndex = chanUtil.CreateChannel hairGeo ChannelName_InitialPosition
			channelInfo.CopyChannel hairGeo 1 0
			channelInfo.PasteChannel hairGeo 3 chanInitPosIndex
		)
		
		
		if isClumpingMeshValid and isInitialMeshValid then 
		(
			btnSetHairObj.caption = hairObj.name
		)
		else 
		(
			messagebox "Didn't set hair object"
		)
	)
	on btnRefresh pressed do 
	(
		RefreshClumpingList lbHairGroup hairGeo
		zoom GraphEditor.ccClumpingCurve #all 
		zoom GraphEditor.ccTwistCurve #all 
	)

	on lbHairGroup selected itm do 
	(
		local verts = AllClumpVertGroupArr[(lbHairGroup.selection as integer)]
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
	on btnCreateClumping pressed do 
	(
		clearListener()
		selFaces = polyop.getFaceSelection hairGeo
		selVerts = polyop.getVertsUsingFace hairGeo selFaces
		hairGeo.showVertexColors = on
		for i = AllGuideline.count to 1 by -1 do
		(
			if (isValidNode AllGuideline[i] == false) then deleteItem AllGuideline i 
		) 

		AllVertexCluster = #()

		initVertCluster = VertexCluster()
		initVertCluster.obj = hairGeo

		initialFace = getTopFace $ selFaces 
		initialSamplePos = initialFace[1]
		initVertCluster.clusterPos = initialSamplePos

		append AllVertexCluster initVertCluster

		gradDir = computeInitialSampleGradDirection initVertCluster initialSamplePos selVerts
		gradDir = normalize gradDir

		safeBreak = 0
		while gradDir.z < 0 and safeBreak < 100 do 
		(
			previousCluster = AllVertexCluster[AllVertexCluster.count]

			local samplePos = previousCluster.clusterPos + gradDir

			newVertClst = VertexCluster()
			newVertClst.obj = hairGeo
			newVertClst.vertexArr = (newVertClst.getVertexArr samplePos sampleRadius gradDir selVerts)[1]
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

		guideline = splineShape name:("ClumpingGuide_" + ((AllGuideline.count + 1) as string))
		addnewSpline guideline

		for c in AllVertexCluster do 
		(
			local pos = c.clusterPos
			addKnot guideline 1 #smooth #curve pos
		)
		updateShape guideline
		append AllGuideline guideline

		SampleGuildeLine guideline hairGeo selVerts
				
		BindGuideline hairGeo selVerts

		RefreshClumpingList lbHairGroup hairGeo
		lbHairGroup.selection = lbHairGroup.items.count



		-- Save the curve infomation 
		local allCurveInfo = crvUtil.GetCurveInfo AllClumpingCurveControl
		crvUtil.SaveCurveInfo hairGeo allCurveInfo guideline



	)

	on btnResampleGuilde pressed do 
	(
		clearListener()
		selFaces = polyop.getFaceSelection hairGeo
		selVerts = (polyop.getVertsUsingFace hairGeo selFaces) as array
		local guideline = GetGuideline hairGeo selVerts

		SampleGuildeLine guideline hairGeo selVerts
	)

	on btnRemoveClumping pressed do 
	(
		local selFaces = polyop.getFaceSelection hairGeo
		local selVerts = polyop.getVertsUsingFace hairGeo selFaces 
		
		polyop.setVertColor hairGeo 0 selVerts black

		RefreshClumpingList lbHairGroup hairGeo 

		local chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition

		for v in (selVerts as array) do 
		(
			local localPos = polyop.getMapVert hairGeo chanInitPosIndex v 
			local newWorldPos = hairGeo.pos + localPos
			hairGeo.verts[v].pos = newWorldPos
		)
	)

	on btnUpdateInitialPos pressed do 
	(
		local selFaces = polyop.getFaceSelection hairGeo
		local selVerts = polyop.getVertsUsingFace hairGeo selFaces 
		
		polyop.setVertColor hairGeo 0 selVerts black

		RefreshClumpingList lbHairGroup hairGeo 

		local chanInitPosIndex = chanUtil.GetChannelIndex hairGeo ChannelName_InitialPosition

		for v in (selVerts as array) do 
		(
			local localPos = hairGeo.verts[v].pos - hairGeo.pos
			polyop.setMapVert hairGeo chanInitPosIndex v localPos
		)
	)

)

rollout GraphEditor "Clumping Graph Editor"
(
	CurveControl ccClumpingCurve "Clumping Curve:"	height:200 width:350 align:#left numCurves:1 visible:true
														x_range:[0.0,1.0] y_range:[0.0,1.0]
														scrollValues:[0.0,1.0] commandMode:#move_xy
														uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


	CurveControl ccTwistCurve "Twist Curve:"	height:200 width:350 align:#left numCurves:1 visible:true
														x_range:[0.0,1.0] y_range:[0.0,1.0]
														scrollValues:[0.0,1.0] commandMode:#move_xy
														uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


	on GraphEditor open do 
	(
		zoom ccClumpingCurve #all
		zoom ccTwistCurve #all

		AllClumpingCurveControl = #(ccClumpingCurve, ccTwistCurve)
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

)