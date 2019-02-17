#include "SimpleDatabase.au3"

$db = DB_Open()
Local $aData_1[3] = ["hello", 123, "word"]
Local $aData_2[4] = ["autoit", 345, "database", 456]
Local $aData_3[2] = ["cogi", "hot?"]
	DB_AddNewRow($db, $aData_1)
	DB_AddNewRow($db, $aData_2)
	DB_AddNewRow($db, $aData_3)
DB_SaveToFile($db, "example.db")

DB_Close($db)

$newDB = DB_Open()
DB_OpenFromFile($newDB, "example.db")
DB_PrintAllData($newDB)

ConsoleWrite("[1][0] >> " & DB_ReadDataFromIndex($newDB, 1, 0) & @CRLF) ; read the data
ConsoleWrite("[1][0] >> Type: " & $newDB[1][0].type & @CRLF) ; 03 = string, 04 = int,..

