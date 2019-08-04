hairObjClumping = undefined
hairObj = undefined

sampleHeightMax = 185
sampleHeightMin = 137
boneNumPerSpline = 3

sampleRadius = 5
hairObjClumping
hairObj 
headBone = $BnHead

ChannelName_CurveParams = "CurveParams"
ChannelName_InitialPosition = "InitialPos"


struct ChannelUtility
(
	Fn GetChannelIndex obj channelName = 
	(
		local mapNum = polyOp.getNumMaps obj 
		channelIndex = false
		
		for m = 1 to mapNum do 
		(
			local n = getUserProp obj ("MapChannel:" + (m as string))
			if n == channelName then channelIndex = m
		)

		return channelIndex
	),

	Fn CreateChannel obj channelName = 
	(
		if (GetChannelIndex obj channelName) == false then 
		(
			local mapNum = polyOp.getNumMaps obj 
			channelInfo.addChannel obj
			channelInfo.NameChannel obj 3 mapNum channelName
			channelInfo.Update ()
			return mapNum
		)
		return false
	)
)

chanUtil = ChannelUtility()




-- for v = 1 to hairObjClumping.verts.count do 
-- (
-- 	polyop.setMapVert hairObjClumping 1 v (point3 v 0 0) 
-- )

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


fn getTopFace obj selFaces =
(
	local topFacePos = point3 0 0 0
	local topFaceIndex = 0

	for f in selFaces do 
	(
		local facePos = polyop.getFaceCenter obj f 
		if facePos[3] > topFacePos[3] then 
		(
			topFacePos = facePos
			topFaceIndex = f
		)
	)

	return #(topFacePos, topFaceIndex)
)
	
fn computeInitialSampleGradDirection _vertCluster _startSamplePos _selVerts = 
(
	local _closestPointsInfo0 = (_vertCluster.getVertexArr _startSamplePos sampleRadius 0 _selVerts)
	local _closestPointsInfo1 = (_vertCluster.getVertexArr _startSamplePos (sampleRadius * 2.0) 0 _selVerts)

	local _clusterPos0 = _vertCluster.computeClusterPos _closestPointsInfo0[1]
	local _clusterPos1 = _vertCluster.computeClusterPos _closestPointsInfo1[1]

	local _initGradDir = _clusterPos1 - _clusterPos0

	return _initGradDir
)	

Fn AddSkinMod obj boneList =
(
	setCommandPanelTaskMode #modify

	if obj != undefined then
	(
    	local skinMod = skin()

    	addmodifier obj skinMod
		modPanel.setCurrentObject obj.modifiers[#Skin]

		for bn in boneList do
		(
			skinOps.addbone obj.modifiers[#Skin] bn 1
		)
  	)
  	else messagebox "skin is not valid"
)

Fn SortBonesByID skinModifier =
(
	local sortedBoneNameArr = #()
  	local boneCount = skinOps.GetNumberBones skinModifier

  	for i = 1 to boneCount do
  	(
  		local n = skinOps.GetBoneName skinModifier i 1
    	append sortedBoneNameArr n
  	)
  	return sortedBoneNameArr
)


Fn SkinWeight meshToSkin bonesAndWeights boneNamesByID =
(
	local skinMod = meshToSkin.modifiers[#Skin]
	for i = 1 to meshToSkin.verts.count do
	(
		local boneIDArr = #()
		local weightArr = #()
		local bonesAndWeightsPerVert = bonesAndWeights[i]

		for k = 1 to bonesAndWeightsPerVert.count do
		(
			local boneName = bonesAndWeightsPerVert[k][1]

		  	local boneID = finditem boneNamesByID boneName

		  	if (boneID == 0) then
				format "Can't find bone! k:%, boneName:% boneID:%\n" k boneName boneID
		 	
		 	local weight = bonesAndWeightsPerVert[k][2]

		  	append boneIDArr boneID
		  	append weightArr weight
		)
		skinOps.ReplaceVertexWeights skinMod i boneIDArr weightArr
	)
)

Fn GetFaceColor obj = 
(
	local arr = #()
	for v in obj.mesh.verts do 
	(
		local col = getVertColor obj.mesh v.index
		local clumpingGuideIndex = 0

		if col.r > 0 then clumpingGuideIndex = col.r / 16
		else if col.g > 0 then clumpingGuideIndex = col.g / 16
		else clumpingGuideIndex = col.b / 16

		append arr v

		meshop.getVertsByColor $.mesh red 0 0 0

	)
)

Fn GetAllClumpingGroup obj = 
(
	allColor = #()
	allClumpingVertArr = #()

	for i = 1 to 3 do 
	(
		for c = 16 to 256 by 16 do 
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



Fn RefreshClumpingList lbClumpingGroup obj = 
(
	AllClumpVertGroupArr = GetAllClumpingGroup obj
	lbClumpingGroup.items = for i = 1 to AllClumpVertGroupArr.count collect (i as string) 
)


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


Fn GetGuideline hairObjClumping vertIndex = 
(
	local col = getVertColor hairObjClumping.mesh vertIndex
	local clumpingGuideIndex = 0

	if col.r > 0 then clumpingGuideIndex = col.r / 16
	else if col.g > 0 then clumpingGuideIndex = col.g / 16
	else clumpingGuideIndex = col.b / 16


	if clumpingGuideIndex != 0 then 
		return AllClumpingGuideline[clumpingGuideIndex]
	else 
		return undefined
)


Fn GuideWorldMatrix guideline param = 
(
	local guidePos = interpCurve3D guideline 1 param
	local guidePosNext = interpCurve3D guideline 1 (param + 0.1)
	local tangent = normalize(guidePosNext - guidePos)
	local normal = point3 0 1 0 
	local binormal = normalize(cross tangent normal) 
	normal = normalize(cross binormal tangent)
	local mat = Matrix3 tangent binormal normal guidePos

	return mat
)

Fn ResolveFinalPosition hairObjClumping ccClumpingCurve ccTwistCurve = 
(
	if not (isValidObj hairObj) do return false
	if not (isValidObj hairObjClumping) do return false

	local selFaces = polyop.getFaceSelection hairObjClumping
	local selVerts = (polyop.getVertsUsingFace hairObjClumping selFaces) as array
	if selVerts.count == 0 do return false

	local guideline = GetGuideline hairObjClumping selVerts[1]
	if guideline == undefined do return false 
	
	local chanCurveParamIndex = chanUtil.GetChannelIndex hairObjClumping ChannelName_CurveParams
	local chanInitPosIndex = chanUtil.GetChannelIndex hairObjClumping ChannelName_InitialPosition

	for v in selVerts do 
	(
		local param = (polyop.getMapVert hairObjClumping chanCurveParamIndex v)[1]

		local guideWorldMat = GuideWorldMatrix guideline param

		-- twist
		local twistPercent = (getValue ccTwistCurve.curves[1] 0f param)

		local invGuideWorldMat = inverse guideWorldMat

		local originalPos = polyop.getMapVert hairObjClumping chanInitPosIndex v 

-- 		local localVertMat = transMatrix (hairObj.verts[v].pos - hairObj.pos + hairObjClumping.pos) 
		local localVertMat = transMatrix (originalPos + hairObjClumping.pos) 

		localVertMat = localVertMat * invGuideWorldMat
		
		local sinT = sin(twistPercent * 180.0)
		local cosT = cos(twistPercent * 180.0)
		local twistMat = Matrix3 (point3 1 0 0) (point3 0 cosT sinT) (point3 0 -sinT cosT) (point3 0 0 0)

		local twistWorldMat = localVertMat * twistMat * guideWorldMat

		-- clumping 
		local clumpPercent = 1.0 - (getValue ccClumpingCurve.curves[1] 0f param)
		local clumpPos = guideWorldMat.translation
		local twistPos = twistWorldMat.translation

		hairObjClumping.verts[v].pos = twistPos * (1 - clumpPercent) + clumpPos * clumpPercent

-- 		polyOp.setMapVert hairObjClumping chanIndex v newLocalPos
	)
)

try (DestroyDialog hairClumpingTool) catch()

AllClumpingGuideline = for s in shapes where (MatchPattern s.name pattern:"ClumpingGuide_*") collect s
VertSkinningTable = #()

AllClumpVertGroupArr = #()
struct CurvePointInfoStruct
(
	pos,
	val,
	inTangent,
	outTangent
)
struct ClumpingCurveInfoStruct 
(
	curvePointArray,

	Fn NewCurve = 
	(
		newPoint = CurvePointInfoStruct()
-- 		newPoint.pos = 
	)
)


AllClumpingCurveInfo = #()

rollout hairClumpingTool "Hair Clumping Tool" width:400
(
	button btnSetHairObj "Pick Hair Mesh" align:#left width:120 across:3
	button btnCreateClumping "Add Clumping" align:#middle width:120 across:3
	button btnRemoveClumping "Remove Clumping"  align:#right width:120 across:3

-- 	button btnCreateBone "Create Bones" align:#left width:130
-- 	button btnPreSkinning "Pre-Skinning" align:#left width:130
-- 	button btnSkinning "Start Skinning"	align:#left width:130

	button btnRefresh "Refresh" align:#left width:120 across:2
	button btnUpdateInitialPos "Update Initial Pos" align:#right width:120 across:2 


	listbox lbClumpingGroup "Clumping Group" align:#left width:130

	CurveControl ccClumpingCurve "Clumping Curve:"	height:200 width:400 align:#center numCurves:1 visible:true
														x_range:[0.0,1.0] y_range:[0.0,1.0]
														scrollValues:[0.0,1.0] commandMode:#move_xy
														uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


	CurveControl ccTwistCurve "Twist Curve:"	height:200 width:400 align:#center numCurves:1 visible:true
														x_range:[0.0,1.0] y_range:[0.0,1.0]
														scrollValues:[0.0,1.0] commandMode:#move_xy
														uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


	on hairClumpingTool open do 
	(
		zoom ccClumpingCurve #all
		zoom ccTwistCurve #all
	)
	on btnSetHairObj pressed do 
	(
		hairObjClumping = $CHR_S_F_Hair_ST03AT_LOD0_Clumping
		hairObj = $CHR_S_F_Hair_ST03AT_LOD0 

		local isClumpingMeshValid = CheckMesh hairObjClumping
		local isInitialMeshValid = CheckMesh hairObj
		

		chanUtil.CreateChannel hairObjClumping ChannelName_CurveParams
		
		if chanUtil.GetChannelIndex hairObjClumping ChannelName_InitialPosition == false do 
		(
			local chanInitPosIndex = chanUtil.CreateChannel hairObjClumping ChannelName_InitialPosition
			channelInfo.CopyChannel hairObjClumping 1 0
			channelInfo.PasteChannel hairObjClumping 3 chanInitPosIndex

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
		RefreshClumpingList lbClumpingGroup hairObjClumping
		zoom ccClumpingCurve #all 
		zoom ccTwistCurve #all 
	)

	on lbClumpingGroup selected itm do 
	(
		local verts = AllClumpVertGroupArr[(lbClumpingGroup.selection as integer)]
		polyop.setFaceSelection hairObjClumping (polyop.getFacesUsingVert hairObjClumping verts)
		ForceCompleteRedraw()
	)
	on btnCreateClumping pressed do 
	(
		clearListener()
		selFaces = polyop.getFaceSelection hairObjClumping
		selVerts = polyop.getVertsUsingFace hairObjClumping selFaces
		hairObjClumping.showVertexColors = on
		for i = AllClumpingGuideline.count to 1 by -1 do
		(
			if (isValidNode AllClumpingGuideline[i] == false) then deleteItem AllClumpingGuideline i 
		) 

		AllVertexCluster = #()

		initVertCluster = VertexCluster()
		initVertCluster.obj = hairObjClumping

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
			newVertClst.obj = hairObjClumping
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

		clumpingGuideline = splineShape name:("ClumpingGuide_" + ((AllClumpingGuideline.count + 1) as string))
		addnewSpline clumpingGuideline

		for c in AllVertexCluster do 
		(
			local pos = c.clusterPos
			addKnot clumpingGuideline 1 #smooth #line pos
		)

		local paramChannelIndex = chanUtil.GetChannelIndex hairObjClumping ChannelName_CurveParams

		for v in selVerts do 
		(
			local paramOnCurve = nearestPathParam clumpingGuideline hairObjClumping.verts[v].pos
			local posOnCurve = interpCurve3D clumpingGuideline 1 paramOnCurve

			local clumpingPos = hairObjClumping.verts[v].pos + (posOnCurve - hairObjClumping.verts[v].pos) * paramOnCurve

			hairObjClumping.verts[v].pos = clumpingPos

			local localPos = clumpingPos - hairObjClumping.pos

			polyop.setMapVert hairObjClumping 1 v localPos 

			polyop.setMapVert hairObjClumping paramChannelIndex v (point3 paramOnCurve 0 0)
		)
				
		local col = black
		if AllClumpingGuideline.count < 16 then 
			col = color ((AllClumpingGuideline.count + 1) * 16) 0 0
		else if AllClumpingGuideline.count < 32 then 
			col = color 0 ((AllClumpingGuideline.count - 15) * 16) 0
		else if AllClumpingGuideline.count < 48 then 
			col = color 0 0 ((AllClumpingGuideline.count - 31) * 16)

		polyop.setVertColor hairObjClumping 0 selVerts col
		append AllClumpingGuideline clumpingGuideline

		RefreshClumpingList lbClumpingGroup hairObjClumping

		ccClumpingCurve.curves[ccClumpingCurve.curves.count].points[1].value = point2 0 1
		ccClumpingCurve.curves[ccClumpingCurve.curves.count].points[2].value = point2 1 0

		ccTwistCurve.curves[ccTwistCurve.curves.count].points[1].value = point2 0 0
		ccTwistCurve.curves[ccTwistCurve.curves.count].points[2].value = point2 1 0

		zoom ccClumpingCurve #all 
		zoom ccTwistCurve #all 
	)

	on btnRemoveClumping pressed do 
	(
		local selFaces = polyop.getFaceSelection hairObjClumping
		local selVerts = polyop.getVertsUsingFace hairObjClumping selFaces 
		
		polyop.setVertColor hairObjClumping 0 selVerts black

		RefreshClumpingList lbClumpingGroup hairObjClumping 

		local chanInitPosIndex = chanUtil.GetChannelIndex hairObjClumping ChannelName_InitialPosition

		for v in (selVerts as array) do 
		(
-- 			local localPos = hairObj.verts[v].pos - hairObj.pos
			local localPos = polyop.getMapVert hairObjClumping chanInitPosIndex v 
			local newWorldPos = hairObjClumping.pos + localPos
-- 			local newWorldPos = polyop.getMapVert hairObjClumping chanInitPosIndex v 
			hairObjClumping.verts[v].pos = newWorldPos
		)
	)

	on btnUpdateInitialPos pressed do 
	(
		local selFaces = polyop.getFaceSelection hairObjClumping
		local selVerts = polyop.getVertsUsingFace hairObjClumping selFaces 
		
		polyop.setVertColor hairObjClumping 0 selVerts black

		RefreshClumpingList lbClumpingGroup hairObjClumping 

		local chanInitPosIndex = chanUtil.GetChannelIndex hairObjClumping ChannelName_InitialPosition

		for v in (selVerts as array) do 
		(
			local localPos = hairObjClumping.verts[v].pos - hairObjClumping.pos
			polyop.setMapVert hairObjClumping chanInitPosIndex v localPos
		)
	)

	on ccClumpingCurve ptChanged ci val do
	(
		ResolveFinalPosition hairObjClumping ccClumpingCurve ccTwistCurve
	) 

	on ccClumpingCurve tangentChanged ci val type do 
	(
		ResolveFinalPosition hairObjClumping ccClumpingCurve ccTwistCurve
	)

	on ccTwistCurve ptChanged ci val do
	(
		clearListener()
		ResolveFinalPosition hairObjClumping ccClumpingCurve ccTwistCurve
	) 

	on ccTwistCurve tangentChanged ci val type do 
	(
		clearListener()
		ResolveFinalPosition hairObjClumping ccClumpingCurve ccTwistCurve
	)

	on btnCreateBone pressed do 
	(
		for s = 1 to AllClumpingGuideline.count do 
		(
			local guideline = AllClumpingGuideline[s]
			local startPosOnCurve = interpCurve3D 1 guideline 0 
			local endPosOnCurve = interpCurve3D 1 guideline 1

			local avgTangent = normalize (endPosOnCurve - startPosOnCurve)

			local newBoneGroup = #()

			for i = 0 to (boneNumPerSpline - 1) do
			(
				local posOnCurve = interpCurve3D 1 guideline ((i as float) / boneNumPerSpline)
				local nextPosOnCurve = interpCurve3D 1 guideline (((i + 1) as float) / boneNumPerSpline)

				local preUp = normalize(posOnCurve - (point3 hairObjClumping.pos.x hairObjClumping.pos.y 150.0))

				local binormal = cross avgTangent preUp 

				local up = cross binormal avgTangent
				
				local newBn = BoneSys.createBone posOnCurve nextPosOnCurve up
				newBn.width = 0.3
				newBn.height = 0.3
				newBn.frontfin = off
				newBn.sidefins = off

				newBn.name = "Bn_ClumpGrp_" + (s as string) + "_" + (i as string)

				if newBoneGroup.count == 0 then newBn.parent = headBone
				else newBn.parent = newBoneGroup[newBoneGroup.count]

				append newBoneGroup newBn


				setUserProp newBn "BoneParamOnCurve" (nearestPathParam guideline posOnCurve)
			)
		)
	)


	on btnPreSkinning pressed do
	(
		clearListener()
		defaultVCFaces  hairObjClumping.mesh

		isMeshValid = true

		for v in hairObjClumping.verts do 
		(
			local col = getVertColor hairObjClumping.mesh v.index
			local clumpingGuideIndex = 0

			if col.r > 0 then clumpingGuideIndex = col.r / 16
			else if col.g > 0 then clumpingGuideIndex = col.g / 16
			else clumpingGuideIndex = col.b / 16

			clumpingGuideIndex = clumpingGuideIndex as integer

			if clumpingGuideIndex == 0 then 
			(
				local vertSkinning = #(#(headBone.name, 1.0))
				append VertSkinningTable vertSkinning
			)
			else 
			(
				local clumpingGuideline = AllClumpingGuideline[clumpingGuideIndex]

				local vertParam = nearestPathParam clumpingGuideline v.pos

				local boneNamePattern = "Bn_ClumpGrp_" + (clumpingGuideIndex as string) + "_*"
				local relatedBones = for bn in objects where (MatchPattern bn.name pattern:boneNamePattern) collect bn
				local relatedBonesParam = for bn in relatedBones collect (getUserProp bn "BoneParamOnCurve")

				for p = 1 to (relatedBonesParam.count - 1) do 
				(
					local paramCurrent = relatedBonesParam[p]
					local paramNext = relatedBonesParam[p+1]

					if vertParam >= paramCurrent and vertParam <= paramNext then 
					(
						local skinningPercent = (vertParam - paramCurrent) / (paramNext - paramCurrent) 
						local vertSkinning = #(#(relatedBones[p].name, 1.0 - skinningPercent), #(relatedBones[p+1].name, skinningPercent))
						append VertSkinningTable vertSkinning
						exit
					)

					else if vertParam > relatedBonesParam[relatedBonesParam.count] then 
					(
						local vertSkinning = #(#(relatedBones[relatedBones.count].name, 1.0))
						append VertSkinningTable vertSkinning
						exit
					)
				)
			)

		)
		

	)

	on btnSkinning Pressed do 
	(
		clearListener()
		local boneList = for s in objects where (MatchPattern s.name pattern:"Bn_ClumpGrp_*") collect s
		insertItem headBone boneList 1

		AddSkinMod hairObjClumping boneList

		local boneNamesByID = SortBonesByID hairObjClumping.modifiers[#Skin]

		SkinWeight hairObjClumping VertSkinningTable boneNamesByID
	)
)

CreateDialog hairClumpingTool

