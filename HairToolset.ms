hairGeo = undefined

mode = #Spline
sampleHeightMax = 185
sampleHeightMin = 137
boneNumPerSpline = 3

sampleRadius = 7

headBone = $BnHead

ChannelName_CurveParams = "CurveParams"
ChannelName_InitialPosition = "InitialPos"
ChannelName_ManualPosition = "ManualOffset"
ChannelName_ClumpOffset = "ClumpOffset"


AllGuideline = for s in shapes where (MatchPattern s.name pattern:"HairGuide_*") collect s
VertSkinningTable = #()

AllClumpVertGroupArr = #()

AllClumpingCurveControl = #()

Fn RGBToInt col = 
(
	local out = (bit.shift col.r 16) + (bit.shift col.g 8) + col.b
	return out
)

Fn IntToRGB intVal = 
(
	local mask_blue = 255 -- 11111111
	local mask_green =  65280 -- 11111111 00000000
	local mask_red = 16711680 -- 11111111 00000000 00000000
	local col = black
	col.r = bit.shift (bit.and intVal mask_red) -16
	col.g = bit.shift (bit.and intVal mask_green) -8
	col.b = bit.and intVal mask_blue

	return col
)



Fn DeleteUserPropByPattern node propPattern = 
(
	local buff = (getUserPropBuffer node) as StringStream
	local newb = stringStream ""
 	while not eof buff do
 	(
  		str = readLine buff
  		if str != "" and not matchpattern str pattern:propPattern do 
  		(
  			format "%\n" str to:newb
 		)
 	)
 	setUserPropBuffer node (replace_LF_with_CRLF (newb as string))
)

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

Fn SetArrayProperty nd propName arrValue = 
(
	local s = StringStream ""

	format "#("  to:s

	for i = 1 to arrValue.count do 
	(
		if i == arrValue.count then format "%)" (arrValue[i] as string) to:s
		else format "%," arrValue[i] to:s
	)
	setUserProp nd propName (s as string)
)



struct ChannelUtility
(
	Fn CleanChannels obj keepUV1:true keepVC:true = 
	(
		local mapNum = polyOp.getNumMaps obj 

		for i = mapNum to 0 by -1 do 
		(
			if i == 0 and keepVC then continue
			if i == 1 and keepUV1 then continue
			channelInfo.ClearChannel obj i	
		)
		channelInfo.Update ()
-- 		setUserPropBuffer obj ""
	),
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


Fn CompleteCloneObj obj = 
(
	local newObj
	maxops.clonenodes obj actualNodeList:&lst newNodes:&newObj
	newObj = newObj[1]
	select newObj 

	local mapNum = polyOp.getNumMaps obj 

	for i = 0 to (mapNum - 1) do 
	(
		channelInfo.CopyChannel obj 3 i
		channelInfo.PasteChannel newObj 3 i
	)

	macros.run "Modifier Stack" "Convert_to_Poly"

	return newObj
)


struct CurveUtility 
(
	Fn GetCurveData crvControl = 
	(
		local curCurveData = #()

		local nameStr = crvControl.name
		local curve = crvControl.curves[1]
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
		curCurveData = #(valueArr, inTangentArr, outTangentArr, bezierArr, cornerArr)

		return curCurveData
	),


	Fn SaveCurveData  guideline crvControl = 
	(
		local curveData = GetCurveData crvControl
		setUserProp guideline crvControl.name curveData
	),

	Fn InitCurveData guideline = 
	(
		setUserProp guideline "ccClumpingCurve" "#(#([0,1], [1,0]), #([0,0], [0,0]), #([0,0], [0,0]), #(false, false), #(true, false))"
		setUserProp guideline "ccTwistCurve" "#(#([0,0], [1,0]), #([0,0], [0,0]), #([0,0], [0,0]), #(false, false), #(true, false))"

	),

	Fn LoadCurveData guideline = 
	(
		local clumpingCurve = execute(getUserProp guideline ("ccClumpingCurve"))
		local twistCurve = execute(getUserProp guideline ("ccTwistCurve"))

		return #(clumpingCurve, twistCurve)
	),

	Fn SetcurveData curveData curve = 
	(
		local valArr = curveData[1]
		local inTangentArr = curveData[2]
		local outTangentArr = curveData[3]
		local bezierArr = curveData[4]
		local cornerArr = curveData[5]

		for p = curve.points.count to 1 by -1 do 
		(
			deletePoint curve p
		)

		curve.numPoints = valArr.count

		for p = 1 to valArr.count do 
		(
			curve.points[p].value  = valArr[p]
			curve.points[p].inTangent = inTangentArr[p]
			curve.points[p].outTangent = outTangentArr[p]
			curve.points[p].bezier = bezierArr[p]
			curve.points[p].corner = cornerArr[p]
		)
	),

	Fn RemoveCurveData obj guideline = 
	(
		DeleteUserProp obj ("CurveData_" + guideline.name)
	)
)

crvUtil = CurveUtility()

-- filein "HairToolset_GuidelineAttribute.ms"
filein "HairToolset_Builder.ms"
filein "HairToolset_Editor.ms"
filein "HairToolset_Rigger.ms"



clearListener()




try (closeRolloutFloater HairToolset) catch()
HairToolset = newRolloutFloater "Hair Toolset" 400 1000 0 0

addrollout  HairBuilder HairToolset
addrollout  HairEditor 	HairToolset
-- addRollout  GraphEditor HairToolset
-- addrollout  HairRigger 	HairToolset



Fn OnSplineUpdate ev nd = 
(
	local cls = ClassOf(GetAnimByHandle nd[1])
	if cls != line and cls != SplineShape do return()

	print "OnSplineUpdate"

	for sel in selection do 
	(
		bindHairGeoName = execute (getUserProp sel "LinkedHairGeo")

		local guidelineIndex = GetGuidelineIndex sel
		local guidelineCol = IntToRGB guidelineIndex

		if bindHairGeoName != undefined then 
		(
			for n in bindHairGeoName do 
			(
				local nd = getNodeByName n
				if isValidNode nd do
				(
					vertArr = (meshOp.getVertsByColor nd.mesh guidelineCol 0 0 0) as array

					DeformHairCardsUsingGuideline sel nd vertArr
					SaveGuidelineData sel 1000  

				)
			)
		)
	)
	CompleteRedraw()
)

Fn OnNodeDeleted ev nd = 
(
	CleanupInValidGuideline()
	gc light:true
)

splineUpdateCallback = undefined
deleteCallback = undefined

gc light:true

splineUpdateCallback = NodeEventCallback mouseUp:true geometryChanged:OnSplineUpdate
deleteCallback = NodeEventCallback deleted:OnNodeDeleted