#AutoIt3Wrapper_Run_AU3Check=n
#include-once
#include <WINAPI.au3>
#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include "AutoItObject_Internal.au3"

Local Const $cbitRow = "01"
Local Const $cbitCol = "02"
Local Const $cbitString = "03"
Local Const $cbitInt = "04"
Local Const $cbitImage = "05"

Local Const $cintDataLen = 10

Local Const $cintMaxNewRow = 100


Func DB_Open()
	_GDIPlus_Startup()
	Local $hDB[1][1]
	$hDB[0][0] = IDispatch()
	$hDB[0][0].row = 1
	$hDB[0][0].col = 1
	$hDB[0][0].newCount = 0
	$hDB[0][0].tempFileName = _WinAPI_GetTempFileName(@TempDir)
	$hDB[0][0].tempFile = FileOpen($hDB[0][0].tempFileName, 16 + 2)
	Return $hDB
EndFunc

Func DB_Close(ByRef $hDB)
	FileClose($hDB[0][0].file)
	FileClose($hDB[0][0].tempFile)
	FileDelete($hDB[0][0].fileName)
	FileDelete($hDB[0][0].tempFileName)
	ReDim $hDB[0][0]
EndFunc

Func DB_OpenFromFile(ByRef $hDB, $strFile)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)

	Local $hFile = FileOpen($strFile, 16)

	__InfoToHandle($hDB, $hFile, $strFile)
	$a = StringTrimLeft( FileRead($hFile, 1), 2)
	If $a <> $cbitRow Then Return SetError(-1, 0, -2)

	Local $nRowCount = _ReadDecAtPos($hDB, 3), $nColCount, $nMaxCol = 1, $pPos = 3, $tColPos, $tDataPos, $tDataInfo

	ReDim $hDB[$nRowCount + 1][$nMaxCol]
	; for each row in database
	For $iRow = 1 To $nRowCount
		$pPos += $cintDataLen
		$tColPos = _ReadDecAtPos($hDB, $pPos)
		$iColInfo = _GetDataInfo($hDB, $tColPos)

		; if this is not a column type
		If $iColInfo[0] <> $cbitCol Then ContinueLoop
		$tDataPos = $tColPos + $cintDataLen / 2 + 1

		If $iColInfo[1] > $nMaxCol Then
			$nMaxCol = $iColInfo[1]
			$hDB[0][0].row = $nRowCount + 1
			$hDB[0][0].col = $nMaxCol
			ReDim $hDB[$nRowCount + 1][$nMaxCol]
		EndIf

		; for each column in database
		For $iCol = 0 To $iColInfo[1] - 1
			$tDataInfo = _GetDataInfo($hDB, $tDataPos)
			$hDB[$iRow][$iCol] = IDispatch()
			$hDB[$iRow][$iCol].isNew = False
			$hDB[$iRow][$iCol].type = $tDataInfo[0]
			$hDB[$iRow][$iCol].pos = $tDataInfo[1]
			$hDB[$iRow][$iCol].len = $tDataInfo[2]
			$tDataPos += $cintDataLen  + 1
		Next
	Next

	Return True
EndFunc

Func DB_SaveToFile($hDB, $strFile = False)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)
	If 		$hDB[0][0].row < 2 	   Then Return SetError(-2, 0, -2)

	Local $db = $hDB[0][0], $hFile, $tTempData, $tDataLen, $hNewDB[$db.row][$db.col], $pPos = 1

	; just boooooooring
	$hFile = FileOpen(($strFile ? $strFile : $db.file), 16 + 2)


	Local $pRowPos[$db.row], $pDataPos[$db.row][$db.col]
	$pPos += $cintDataLen + 2
	; this is for calculating the data position------------------------
	For $iRow = 1 To $db.row - 1
		$pPos += $cintDataLen
	Next

	For $iRow = 1 To $db.row - 1
		$pRowPos[$iRow] = Hex(Round(($pPos - 1) / 2), $cintDataLen)
		For $iCol = 0 To $db.col - 1
			If __CheckData($hDB[$iRow][$iCol]) = False Then ExitLoop
			$pPos += $cintDataLen * 2 + 2
		Next
		$pPos += $cintDataLen + 2
	Next

	For $iRow = 1 To $db.row - 1
		For $iCol = 0 To $db.col - 1
			If __CheckData($hDB[$iRow][$iCol]) = False Then ExitLoop
			$pDataPos[$iRow][$iCol] = Hex(Round(($pPos - 1) / 2), $cintDataLen)

			$tDataLen = $hDB[$iRow][$iCol].len
			If Not IsInt($tDataLen / 2) Then $tDataLen += 1

			$pPos += $tDataLen
		Next
	Next


	; setup database
	FileWrite($hFile, "0x" & $cbitRow & Hex($db.row - 1, $cintDataLen))
	$pPos = $cintDataLen + 3

	; for rows in database - write header of columns positon
	For $iRow = 1 To $db.row - 1
		$hNewDB[$iRow][0] = IDispatch()
		$hNewDB[$iRow][0].rowpos = $pPos
		FileWrite($hFile, "0x" &  $pRowPos[$iRow])
		$pPos += $cintDataLen
	Next

	; for rows and columns in database - write header of data position
	For $iRow = 1 To $db.row - 1

;~ 		;for columns in database
		For $iCol = 0 To $db.col - 1
			If __CheckData($hDB[$iRow][$iCol]) = False Then ExitLoop
			If $iCol > 0 Then $hNewDB[$iRow][$iCol] = IDispatch() ; because we've created object at col 0 up there

			$hNewDB[$iRow][$iCol].pos = $pPos + $cintDataLen + 2
			$tTempData &= $hDB[$iRow][$iCol].type & $pDataPos[$iRow][$iCol] & Hex($hDB[$iRow][$iCol].len, $cintDataLen) ; hex(99) is temp, because this is data position and we dont know yet
			$pPos += $cintDataLen * 2 + 2
		Next

		FileWrite($hFile, "0x" & $cbitCol & Hex($iCol, $cintDataLen) & $tTempData)
		$pPos += $cintDataLen + 2
		$tTempData = ""
	Next

	; for rows and columns in database - add data
	For $iRow = 1 To $db.row - 1
;~ 		;for columns in database
		For $iCol = 0 To $db.col - 1
			If __CheckData($hDB[$iRow][$iCol]) = False Then ExitLoop

			; if this data is just added, we don't have to read it from db file
			$tTempData = DB_ReadDataFromIndex($hDB, $iRow, $iCol, True)

			$tDataLen = $hDB[$iRow][$iCol].len
			$tTempData = StringLeft($tTempData, $tDataLen)
			$hDB[$iRow][$iCol].pos = $pPos

			If Not IsInt($tDataLen / 2) Then
				$tDataLen += 1
				$tTempData &= "0"
			EndIf
			FileWrite($hFile, "0x" & $tTempData)
			$pPos += $tDataLen
		Next
	Next

	If $strFile Then FileClose($hFile)
EndFunc

Func DB_ScreenToindex($hDB, $iRow, $iCol, $x1 = 0, $y1 = 0, $x2 = -1, $y2 = -1, $cursor = True)
	Local $strImageName = _WinAPI_GetTempFileName(@TempDir) & ".png"
	_ScreenCapture_Capture($strImageName, $x1, $y1, $x2, $y2, $cursor)
	DB_ImgFileToIndex($hDB, $strImageName, $iRow, $iCol)
	FileDelete($strImageName)
EndFunc

Func DB_ImgFileToIndex($hDB, $fImage, $iRow, $iCol)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)
	If $iRow >= UBound($hDB, 1) Or $iCol >= UBound($hDB, 2) Then Return SetError(-2, 0, -2)
	If Not FileExists($fImage) Then Return SetError(-3, 0, -3)

	; read the image
	Local $hFile = FileOpen($fImage, 16)
	Local $fRead = FileRead($hFile)

	FileSetPos($hDB[0][0].tempFile, 0, 2)
	$hDB[$iRow][$iCol].isNew = True
	$hDB[$iRow][$iCol].type = $cbitImage
	$hDB[$iRow][$iCol].tempPos = FileGetPos($hDB[0][0].tempFile)
	$hDB[$iRow][$iCol].len = StringLen($fRead) - 2 ; -2 bit of "0x"
	FileWrite($hDB[0][0].tempFile, $fRead)

	FileClose($hFile)
EndFunc

Func DB_GetImgFromIndex($hDB, $iRow, $iCol)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)
	If $iRow >= UBound($hDB, 1) Or $iCol >= UBound($hDB, 2) Then Return SetError(-2, 0, -2)

	Local $hFile = ($hDB[$iRow][$iCol].isNew ? $hDB[0][0].tempFile : $hDB[0][0].file)
	Local $pPos = ($hDB[$iRow][$iCol].isNew ? $hDB[$iRow][$iCol].tempPos: (($hDB[$iRow][$iCol].pos - 1) / 2))

;~ 	MsgBox(0,"", $hDB[$iRow][$iCol].tempPos)
	FileSetPos($hFile, $pPos, 0)
	Local $data = FileRead($hFile, Round($hDB[$iRow][$iCol].len / 2))
	Local $strTempFileName = _WinAPI_GetTempFileName(@TempDir)
	Local $hTempFile =FileOpen($strTempFileName, 16 + 2); FileOpen, 16 + 2)

	FileWrite($hTempFile, $data)
	FileClose($hTempFile)

	Local $hBitmap = _GDIPlus_BitmapCreateFromFile($strTempFileName)
;~ 	_GDIPlus_BitmapDispose($hBitmap)
;~ 	_GDIPlus_Shutdown()

	FileDelete($strTempFileName)
	Return $hBitmap
EndFunc

Func DB_AddNewRow(ByRef $hDB, $data)
	;check if database handle and data array is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1) ; array handle is invalid
	If 		UBound($data) < 1 	   Then Return SetError(-2, 0, -2) ; array data is invalid

	; add new data to $db[][]
	Local $vCurRow = $hDB[0][0].row, $vCurCol = $hDB[0][0].col

	; add a row and redim handle array
	If $vCurCol < UBound($data) Then $vCurCol = UBound($data)
	$hDB[0][0].row += 1
	$hDB[0][0].col = $vCurCol
	ReDim $hDB[$vCurRow + 1][$vCurCol]

	; setup object and copy from data array to handle array
	For $iData = 0 To UBound($data) - 1
		$tData = _Data2Bit($data[$iData])
		FileSetPos($hDB[0][0].tempFile, 0, 2)
		$hDB[$vCurRow][$iData] = IDispatch()
		$hDB[$vCurRow][$iData].isNew = True
		$hDB[$vCurRow][$iData].type = __GetDataType($data[$iData])
		$hDB[$vCurRow][$iData].tempPos = FileGetPos($hDB[0][0].tempFile)
		$hDB[$vCurRow][$iData].len = StringLen($tData)
		If not IsInt($hDB[$vCurRow][$iData].len / 2) Then $tData &= "0"
		FileWrite($hDB[0][0].tempFile, "0x" & $tData)
	Next
EndFunc

Func DB_ReadDataFromIndex($hDB, $iRow, $iCol, $InBinary = False)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)
	If $iRow >= UBound($hDB, 1) Or $iCol >= UBound($hDB, 2) Then Return SetError(-2, 0, -2)
	If $hDB[$iRow][$iCol].type = $cbitImage Then Return "/img"
	If $hDB[$iRow][$iCol].isNew Then
		FileSetPos($hDB[0][0].tempFile, $hDB[$iRow][$iCol].tempPos, 0)
		$data = StringTrimLeft(FileRead($hDB[0][0].tempFile, Round($hDB[$iRow][$iCol].len / 2)), 2)
		Return ($InBinary ? $data : _Bit2Data($data, $hDB[$iRow][$iCol].type))
	EndIf

	FileSetPos($hDB[0][0].file, ($hDB[$iRow][$iCol].pos - 1) / 2, 0)
	Local $data = StringTrimLeft( FileRead($hDB[0][0].file, Round($hDB[$iRow][$iCol].len / 2)), 2)
	$data = StringLeft($data, $hDB[$iRow][$iCol].len)
	$data = ($InBinary ? $data : _Bit2Data($data, $hDB[$iRow][$iCol].type))
	Return $data
EndFunc

Func DB_PrintAllData($hDB)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)

	Local $strPrint
	For $iRow = 1 To $hDB[0][0].row - 1
		$strPrint = $iRow & ": ["
		For $iCol = 0 To $hDB[0][0].col - 1
			If __CheckData($hDB[$iRow][$iCol]) = False Then ExitLoop
			$strPrint &= DB_ReadDataFromIndex($hDB, $iRow, $iCol) & ", "
		Next
		print(StringTrimRight($strPrint, 2) & "]")
	Next
EndFunc

Func _ReadDataFromColumn($hDB, $pPos)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)

	Local $dataInfo = _GetDataInfo($hDB, $pPos)

	FileSetPos($hDB[0][0].file, $dataInfo[1], 0)
	Local $data[3]
	$data[0] = $dataInfo[0]
	$data[1] = StringTrimLeft( FileRead($hDB[0][0].file, 2), $dataInfo[2])
	$data[2] = $dataInfo[2]

	Return $data
EndFunc

Func __InfoToHandle(ByRef $hDB, $hFile, $strFile)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)

	;parsing info to handle array
	$hDB[0][0].file = $hFile
	$hDB[0][0].fileName = $strFile
EndFunc

Func __GetDataType($data)
	If IsString($data) Then Return $cbitString
	If IsNumber($data) Then Return $cbitInt
	Return False
EndFunc

Func __CheckHandle($hDB)
	; if array hanlde is invalid
	If UBound($hDB, 1) <  1 Or UBound($hDB, 2) <  1 Or IsObj($hDB[0][0]) = False Then Return False
	Return True
EndFunc

Func __CheckData($ObjData)
	; if array hanlde is invalid
	If IsObj($ObjData) = False Then Return False
	Return True
EndFunc

Func _Data2Bit($Str)
	If Not $Str Then Return False

	Local $rData
	Switch __GetDataType($Str)
		Case $cbitString
			$rData = StringTrimLeft( StringToBinary($Str), 2)
		Case $cbitInt
			$rData = Hex($Str, StringLen($Str))
	EndSwitch
	Return $rData
EndFunc

Func _Bit2Data($bit, $type)
	Switch $type
		Case $cbitString
			Return BinaryToString("0x" & $bit)
		Case $cbitInt
			Return Dec($bit)
	EndSwitch

	Return False
EndFunc

Func _GetDataInfo($hDB, $pPos)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)
	FileSetPos($hDB[0][0].file, $pPos, 0)
	Local $data = StringTrimLeft( FileRead($hDB[0][0].file, $cintDataLen + 2), 2),  $rInfo[3]
	$rInfo[0] = StringLeft($data, 2)
	$rInfo[1] = Dec( StringMid($data, 3, $cintDataLen) )
	If $rInfo[0] <> $cbitCol And $rInfo[0] <> $cbitRow Then
		$rInfo[1] = $rInfo[1] * 2 +1
		$rInfo[2] = Dec( StringMid($data, $cintDataLen + 3, $cintDataLen) )
	EndIf

	Return $rInfo
EndFunc

Func _ReadDecAtPos($hDB, $pPos)

	;check if database handle is valid
	If __CheckHandle($hDB) = False Then Return SetError(-1, 0, -1)

	FileSetPos($hDB[0][0].file, ($pPos - 1) / 2, 0)
	Local $rRead = StringTrimLeft( FileRead($hDB[0][0].file, $cintDataLen / 2), 2)
	Return Dec( $rRead )
EndFunc

Func __getrandomfilename()
	Local $str = "dataset-temp-"
	For $i = 0 To 20
		$str &= Random(0, 9, 1)
	Next
	Return $str & ".db"
EndFunc

Func print($str, $isBreak = True)
	ConsoleWrite($str & ($isBreak ? " --" & @CRLF : ""))
EndFunc