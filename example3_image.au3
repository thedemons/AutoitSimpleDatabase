#include "SimpleDatabase.au3"

Local $aData[2] = ["image_here", "hello"]

$db = DB_Open()
DB_AddNewRow($db, $aData)

DB_ScreenToIndex($db, 1, 0, 0, 0, 200, 200)

$hBitmap = DB_GetImgFromIndex($db, 1, 0) ;this return in hBitmap
_GDIPlus_ImageSaveToFile($hBitmap, "testfile.png")

DB_PrintAllData($db)

DB_SaveToFile($db, "example.db")

DB_Close($db)


