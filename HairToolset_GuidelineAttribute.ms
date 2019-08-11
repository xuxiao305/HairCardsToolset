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
		print curveInfo
		
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

	Fn RemoveCurveInfo obj guideline = 
	(
		DeleteUserProp obj ("CurveInfo_" + guideline.name)
	)
)

crvUtil = CurveUtility()

plugin modifier  HairToolset
name:"HairGuideline" classID:#(685325,452281) version:1
(
	parameters main  rollout:UI
	(
	)

	rollout UI "Ropes Bones"
	(
		button btnZoom "Zoom" align:#left width:150

		CurveControl ccClumpingCurve "Clumping Curve:"	height:200  align:#left numCurves:1 visible:true
															x_range:[0.0,1.0] y_range:[0.0,1.0]
															scrollValues:[0.0,1.0] commandMode:#move_xy
															uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


		CurveControl ccTwistCurve "Twist Curve:"	height:200  align:#left numCurves:1 visible:true
															x_range:[0.0,1.0] y_range:[0.0,1.0]
															scrollValues:[0.0,1.0] commandMode:#move_xy
															uiFlags:#(#upperToolbar, #lowerToolbar , #drawgrid, #xvalue)


		on UI open do
		(
			zoom ccClumpingCurve #all
			zoom ccTwistCurve #all
		)

		on btnZoom pressed do 
		(
			zoom ccClumpingCurve #all
			zoom ccTwistCurve #all	
		)
	)
)