#include "SimpleDatabase.au3"

Local Const $nDataSize = (200 * 200 * 8) / 1000 ; (320 mb)
Local $tTime, $tTimeFPS, $tTimeFPS__, $aData[2] = [ "", "autoit" ]
Local $resultTimeProc, $resultTimeSave

print("Setup data array..")
For $i = 1 To 200 * 200 ; ví dụ 1 image 200 x 200 piexel
	$aData[0] &= "FFFF" ; F ở đây dưới dạng string, trong file là 2 byte, nên FFFF = 8 bytes, bằng 1 pixel của ảnh
Next

print("Opening Database..")
$db = DB_Open()

print("Feeding data...")
$tTimeFPS__ = TimerInit()
$tTimeFPS = TimerInit()
$tTime = TimerInit()

For $i = 1 To 1000
	If TimerDiff($tTimeFPS__) > 3000 Then
		print("-index " & $i & "  ||   FPS  >> " &  1000 / TimerDiff($tTimeFPS))
		$tTimeFPS__ = TimerInit()
	EndIf
	$tTimeFPS = TimerInit()
	DB_AddNewRow($db, $aData)
Next

$resultTimeProc = TimerDiff($tTime)

print("Saving the database...")

$tTime = TimerInit()
DB_SaveToFile($db, "example2.db")

$resultTimeSave = TimerDiff($tTime)

print(">Result")
print("-	processing data >> " & $nDataSize / Round($resultTimeProc / 1000) & " mb/s")
print("-	saving data >> " & $nDataSize / Round($resultTimeSave / 1000) & " mb/s")


;~ $db = DB_Open()
;~ DB_Close($db)

;~ $newDB = DB_Open()
;~ DB_OpenFromFile($newDB, "example.db")
;~ DB_PrintAllData($newDB)

;~ ConsoleWrite("[1][0] >> " & DB_ReadDataFromIndex($newDB, 1, 0) & @CRLF) ; read the data
;~ ConsoleWrite("[1][0] >> Type: " & $newDB[1][0].type & @CRLF) ; 03 = string, 04 = int,..
