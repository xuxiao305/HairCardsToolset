hairGeo = undefined
hairObj = undefined

sampleHeightMax = 185
sampleHeightMin = 137
boneNumPerSpline = 3

sampleRadius = 5
hairGeo
hairObj 
headBone = $BnHead

ChannelName_CurveParams = "CurveParams"
ChannelName_InitialPosition = "InitialPos"

AllGuideline = for s in shapes where (MatchPattern s.name pattern:"ClumpingGuide_*") collect s
VertSkinningTable = #()

AllClumpVertGroupArr = #()

AllClumpingCurveControl = #()

Fn DeleteUserProp node prop = 
(
	if getUserProp node prop == undefined do return()

 	buff = (getUserPropBuffer node) as stringStream 
 	newb = stringStream ""
 	while not eof buff do
 	(
  		str = readLine buff
  		if str != "" and not matchpattern str pattern:("*" + prop + "*=*") do 
  		(
  			format "%\n" str to:newb
 		)
 	)
 	setUserPropBuffer node (replace_LF_with_CRLF (newb as string))
)


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

struct CurveUtility 
(
	Fn GetCurveInfo allCurvesControl = 
	(
		local allCurveInfo = #()
		for c = 1 to allCurvesControl.count do 
		(
			local curCurveInfo = #()
			local nameStr = allCurvesControl[c].name
			local curve = allCurvesControl[c].curves[1]
			local valueArr = #()
			local inTangentArr = #()
			local outTangentArr = #()
			local bezierArr = #()
			local cornerArr = #()


			for i = 1 to curve.points.count do 
			(
				append valueArr curve.points[i].value
				append inTangentArr curve.points[i].inTangent
				append outTangentArr curve.points[i].outTangent
				append bezierArr curve.points[i].bezier
				append cornerArr curve.points[i].corner

			)
			curCurveInfo = #(nameStr, valueArr, inTangentArr, outTangentArr, bezierArr, cornerArr)

			append allCurveInfo curCurveInfo
		)
		
		return allCurveInfo
	),


	Fn SaveCurveInfo obj curveInfoArr guideline = 
	(
		setUserProp obj ("CurveInfo_" + guideline.name) curveInfoArr
	),


	Fn LoadCurveInfo obj guideline = 
	(
		local curveInfo = getUserProp obj ("CurveInfo_" + guideline.name)
		
		return curveInfo
	),

	Fn SetCurveinfo curveInfo curve = 
	(
		local nameStr = curveInfo[1]
		local valArr = curveInfo[2]
		local inTangentArr = curveInfo[3]
		local outTangentArr = curveInfo[4]
		local bezierArr = curveInfo[5]
		local cornerArr = curveInfo[6]

		for p = 1 to curve.points.count do 
		(
			curve.points[p].value = valArr[p]
			curve.points[p].inTangent = inTangentArr[p]
			curve.points[p].outTangent = outTangentArr[p]
			curve.points[p].bezier = bezierArr[p]
			curve.points[p].corner = cornerArr[p]
		)
	),
	Fn RemoveCurveInfo obj guideline = 
	(
		DeleteUserProp obj ("CurveInfo_" + guideline.name)
	)
)

crvUtil = CurveUtility()

filein "HairToolset_Builder.ms"
filein "HairToolset_Editor.ms"
filein "HairToolset_Rigger.ms"

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


Fn getTopFace obj selFaces =
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
	
Fn computeInitialSampleGradDirection _vertCluster _startSamplePos _selVerts = 
(
	local _closestPointsInfo0 = (_vertCluster.getVertexArr _startSamplePos sampleRadius 0 _selVerts)
	local _closestPointsInfo1 = (_vertCluster.getVertexArr _startSamplePos (sampleRadius * 2.0) 0 _selVerts)

	local _clusterPos0 = _vertCluster.computeClusterPos _closestPointsInfo0[1]
	local _clusterPos1 = _vertCluster.computeClusterPos _closestPointsInfo1[1]

	local _initGradDir = _clusterPos1 - _clusterPos0

	return _initGradDir
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






clearListener()


Fn OnSplineUpdate ev nd = 
(
	if ClassOf(GetAnimByHandle nd[1]) != line then return()

	vertArr = for v in m.verts collect v.index
	DeformHairCards m vertArr
	SaveCurveSample $ 1000

)


try (closeRolloutFloater HairToolset) catch()
HairToolset = newRolloutFloater "Hair Toolset" 400 1000 0 0

addrollout  HairBuilder HairToolset
addrollout  HairEditor 	HairToolset
addRollout  GraphEditor HairToolset
addrollout  HairRigger 	HairToolset






callbackItem = undefined
gc light:true

callbackItem = NodeEventCallback mouseUp:true geometryChanged:OnSplineUpdate
