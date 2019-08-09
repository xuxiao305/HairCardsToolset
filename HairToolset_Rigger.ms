(
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

rollout HairRigger "Hair Rigger"
(
	button btnCreateBone "Create Bones" align:#left width:130
	button btnPreSkinning "Pre-Skinning" align:#left width:130
	button btnSkinning "Start Skinning"	align:#left width:130

	on btnCreateBone pressed do 
	(
		for s = 1 to AllGuideline.count do 
		(
			local guideline = AllGuideline[s]
			local startPosOnCurve = interpCurve3D 1 guideline 0 
			local endPosOnCurve = interpCurve3D 1 guideline 1

			local avgTangent = normalize (endPosOnCurve - startPosOnCurve)

			local newBoneGroup = #()

			for i = 0 to (boneNumPerSpline - 1) do
			(
				local posOnCurve = interpCurve3D 1 guideline ((i as float) / boneNumPerSpline)
				local nextPosOnCurve = interpCurve3D 1 guideline (((i + 1) as float) / boneNumPerSpline)

				local preUp = normalize(posOnCurve - (point3 hairGeo.pos.x hairGeo.pos.y 150.0))

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
		defaultVCFaces  hairGeo.mesh

		isMeshValid = true

		for v in hairGeo.verts do 
		(
			local col = getVertColor hairGeo.mesh v.index
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
				local guideline = AllGuideline[clumpingGuideIndex]

				local vertParam = nearestPathParam guideline v.pos

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

		AddSkinMod hairGeo boneList

		local boneNamesByID = SortBonesByID hairGeo.modifiers[#Skin]

		SkinWeight hairGeo VertSkinningTable boneNamesByID
	)
)

)