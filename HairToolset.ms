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

-- filein "HairToolset_GuidelineAttribute.ms"
filein "HairToolset_Builder.ms"
filein "HairToolset_Editor.ms"
filein "HairToolset_Rigger.ms"





clearListener()




try (closeRolloutFloater HairToolset) catch()
HairToolset = newRolloutFloater "Hair Toolset" 400 1000 0 0

addrollout  HairBuilder HairToolset
addrollout  HairEditor 	HairToolset
addRollout  GraphEditor HairToolset
-- addrollout  HairRigger 	HairToolset





