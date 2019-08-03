hairObjClumping = $CHR_S_F_Hair_ST03AT_LOD0_Clumping
hairObj = $CHR_S_F_Hair_ST03AT_LOD0 


sampleHeightMax = 185
sampleHeightMin = 137
boneNumPerSpline = 3

sampleRadius = 5
hairObjClumping
hairObj 
headBone = $BnHead


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

Fn GetClumpingGuide hairObjClumping vertIndex = 
(
	local col = getVertColor hairObjClumping.mesh vertIndex
	local clumpingGuideIndex = 0

	if col.r > 0 then clumpingGuideIndex = col.r / 16
	else if col.g > 0 then clumpingGuideIndex = col.g / 16
	else clumpingGuideIndex = col.b / 16


	if clumpingGuideIndex != 0 then 
		return AllClumpingGuideline[clumpingGuideIndex]
	else 
		return false
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
	button btnSetHairObj "Pick Hair Mesh" align:#left width:130
	button btnCreateClumping "Add Clumping" align:#left width:130
	button btnRemoveClumping "Remove Clumping"  align:#left width:130

	label lbl1 ""
	button btnCreateBone "Create Bones" align:#left width:130
	button btnPreSkinning "Pre-Skinning" align:#left width:130
	button btnSkinning "Start Skinning"	align:#left width:130

	button btnRefresh "Refresh" align:#left width:130
	listbox lbClumpingGroup "Clumping Group" align:#left width:130

	CurveControl ccClumpingCurve "Clumping Curve:"	height:200 width:400 align:#center
														numCurves:2 visible:true
														x_range:[0.0,1.0]
														y_range:[0.0,1.0]
														scrollValues:[0.0,1.0]
														commandMode:#move_xy
														uiFlags:#(#lowerToolbar , #drawgrid, #xvalue)

	on btnSetHairObj pressed do 
	(

		local isClumpingMeshValid = CheckMesh hairObjClumping
		local isOriginalMeshValid = CheckMesh hairObj

	
		if isClumpingMeshValid and isOriginalMeshValid then 
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

		for v in selVerts do 
		(
			local paramOnCurve = nearestPathParam clumpingGuideline hairObjClumping.verts[v].pos
			local posOnCurve = pathInterp clumpingGuideline paramOnCurve

			local clumpingPos = hairObjClumping.verts[v].pos + (posOnCurve - hairObjClumping.verts[v].pos) * paramOnCurve

			hairObjClumping.verts[v].pos = clumpingPos
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
	)

	on btnRemoveClumping pressed do 
	(
		local selFaces = polyop.getFaceSelection hairObjClumping
		local selVerts = polyop.getVertsUsingFace hairObjClumping selFaces 
		
		polyop.setVertColor hairObjClumping 0 selVerts black

		RefreshClumpingList lbClumpingGroup hairObjClumping 

		for v in (selVerts as array) do 
		(
			local localPos = hairObj.verts[v].pos - hairObj.pos
			local newWorldPos = hairObjClumping.pos + localPos
			hairObjClumping.verts[v].pos = newWorldPos
		)
		
	)

	on ccClumpingCurve ptChanged ci val do
	(
		local selFaces = polyop.getFaceSelection hairObjClumping
		local selVerts = (polyop.getVertsUsingFace hairObjClumping selFaces) as array

		if selVerts.count > 0 do 
		(
			local clumpingGuideline = GetClumpingGuide hairObjClumping selVerts[1]

			if clumpingGuideline != false then 
			(
				local params = #()
				for v in selVerts do 
				(
					local localOriginalPos = hairObj.verts[v].pos - hairObj.pos
					local worldPos = localOriginalPos + hairObjClumping.pos
					local p = nearestPathParam clumpingGuideline worldPos
					append params p
				)

				for i = 1 to selVerts.count do 
				(
					v = selVerts[i]
					local percent = 1.0 - (getValue ccClumpingCurve.curves[1] 0f params[i])
					local localClumpPos = hairObjClumping.verts[v].pos - hairObjClumping.pos
					local localOriginalPos = hairObj.verts[v].pos - hairObj.pos
					local newLocalPos = localOriginalPos * (1 - percent) + localClumpPos * percent

-- 					format "percent --> %\n" 			percent
-- 					format "localClumpPos --> %\n" 		localClumpPos
-- 					format "localOriginalPos --> %\n" 	localOriginalPos
-- 					format "newLocalPos --> %\n" 		newLocalPos
								

					hairObjClumping.verts[v].pos =  hairObjClumping.pos + newLocalPos
				)
			)
			
		)
	) 
	on btnCreateBone pressed do 
	(
		for s = 1 to AllClumpingGuideline.count do 
		(
			local guideline = AllClumpingGuideline[s]
			local startPosOnCurve = pathInterp guideline 0 
			local endPosOnCurve = pathInterp guideline 1

			local avgTangent = normalize (endPosOnCurve - startPosOnCurve)

			local newBoneGroup = #()

			for i = 0 to (boneNumPerSpline - 1) do
			(
				local posOnCurve = pathInterp guideline ((i as float) / boneNumPerSpline)
				local nextPosOnCurve = pathInterp guideline (((i + 1) as float) / boneNumPerSpline)

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

