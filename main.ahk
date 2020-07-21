#SingleInstance, Force
    #KeyHistory, 0
SetBatchLines, -1
ListLines, Off
SendMode Input ; Forces Send and SendRaw to use SendInput buffering for speed.
SetWorkingDir, %A_ScriptDir%
SplitPath, A_ScriptName, , , , thisscriptname
#MaxThreadsPerHotkey, 1 ; no re-entrant hotkey handling
FileEncoding, UTF-8 ;UTF-8 is used for files, the locale.cfg must be in UTF-16LE no BOM
;#Warn

;Declare variables
global AppTitle := "Practicer"
global Author := "David Szilvasi"
global Email := "szilvasi.dave@gmail.com"
global LocaleFile := "locale.cfg" ;See above at FileEncoding

;Load language specific translations and create Tray menu
setLang()

;Let user select a file to practice from and make sure file exists
SelectNewPracticeFile()

;Start the practice
PracticeFunc()

Return ; Return of autoexecute section

SelectNewPracticeFile() {
    global
    FileSelectFile, PracticeFile , , , %Lang_FileSelectTitle%, %Lang_FileSelectDocType%
    If ErrorLevel {
        MsgBox 16, %AppTitle%, %Lang_FileCannotRead%
        ExitApp
    }
    local filetext := ""
    FileRead, fileText, %PracticeFile%
    If (fileText == "") {
        MsgBox 16, %AppTitle%, % Lang_FileIsEmpty . " " . PracticeFile
        ExitApp
    }

    ;Figure out highest line number in file -> = maximum number of questions possible
    Loop, read, %PracticeFile%
    {
        MaxLine := A_Index
    }
    return
}

PracticeFunc() {
    global
    local LoopCount := 0

    ;Ask user how many questions do they want to answer
    InputBox, LoopCount, %AppTitle%, % Lang_PracticeHowManyToAnswer . "`n" . Lang_PracticeEnterZeroForAll . "`n" . Lang_PracticeMaxQuestions . " " . MaxLine

    If (LoopCount < 1 OR LoopCount > MaxLine OR LoopCount is not digit) {
        LoopCount := MaxLine
    }

    ;Start practice loop to go through questions
    local score:=0, rndLine:=0, rndField:=0, index:=0, done:=[], didntKnow:=[], currLine:="", currentAnswer:="", a:="", q:="", didntKnowStr:="", value:= ""
    Loop, 
    {
        ;Take a random number as per below and read that line of the file
        Random, rndLine , 1, %MaxLine%
        FileReadLine, currLine, %PracticeFile%, %rndLine%
        If ((ErrorLevel) || (HasVal(done, rndLine) != 0) OR (currLine == ""))
            Continue
        Else If (InStr(currLine, A_Tab) == 0) {
            MsgBox 48, %AppTitle%, % Lang_FileCurrentLineNoTab . " " . rndLine . "`n" . currLine
            Continue
        }
        
        ;Mix up which side of the "Tab" on the line will be the question and which side will be the answer
        Random rndField, 1, 2
        Loop, parse, currLine, %A_Tab%
        {
            If (rndField == 1) {
                q := A_LoopField
                rndField := 2
                Continue
            }
            If (rndField == 2) {
                a := A_LoopField
                rndField := 1
            }
        }

        ;Ask for the answer from user
        InputBox, currentAnswer, %AppTitle%, % Lang_PracticeScore . " " . score . "`n" . Lang_PracticeTotal . " " . done.MaxIndex() . " " . Lang_PracticeOf . " " . LoopCount . "`n`n" . Lang_PracticeTask . " " . q


        If ErrorLevel { ;If Cancel button pressed exit loop
            Break
        } Else { ;Otherwise check if answer correct. If not correct, show correct and add this item to show at the end
            If (currentAnswer == a) {
                score := score+1
            } Else {
                MsgBox 48, %AppTitle%, % Lang_PracticeNotCorrect . " " . a
                didntKnow.Push(a)
            }
        }

        ;Dont check this line from the file again
        done.Push(rndLine)

        If (done.MaxIndex() == LoopCount) {
            Break
        }
    }

    ;Show after practice score, total, and questions to which user didn't know the answer
    didntKnowStr := ""
    for index, value in didntKnow
        didntKnowStr .= value . "`n"
    MsgBox 64, %AppTitle%, % Lang_PracticeFinishMessage . "`n" . Lang_PracticeScore . " " . score . "`n" . Lang_PracticeTotal . " " . done.MaxIndex() . "`n`n" . Lang_PracticeDidntKnow . "`n`n" . didntKnowStr

    ;Ask if user wants to start over
    MsgBox 36, %AppTitle%, % Lang_PracticeStartOver
    IfMsgBox, Yes
        PracticeFunc()
    IfMsgBox, No
        ExitApp

    return
}

;Search function to work with arrays
HasVal(haystack, needle) {
	if !(IsObject(haystack)) || (haystack.Length() == 0)
		return 0
	for index, value in haystack
		if (value = needle)
			return index
	return 0
}

setLang(languageToUse := "") {
    global
    local LangData := "", LangCurrLine := -1, Var := "", Val := ""

    ;Check if system language is found or the function was called with a specific language to be used
    ;If a language was found, load all data for it
    ;More info about Language Codes: https://www.autohotkey.com/docs/misc/Languages.htm
    If (SubStr(A_Language, 1 , 4) == "040e" OR languageToUse == "Hungarian") {
        IniRead, LangData, %LocaleFile%, %languageToUse%
        If (LangData = "") {
            OutputDebug, %languageToUse% wasn't found, reverting to English
            setLang()
            return
        }
        currentLanguage := languageToUse
    } Else If (SubStr(A_Language, 3 , 2) == "07" OR languageToUse == "German") {
        IniRead, LangData, %LocaleFile%, %languageToUse%
        If (LangData = "") {
            OutputDebug, %languageToUse% wasn't found, reverting to English
            setLang()
            return
        }
        currentLanguage := languageToUse
    } Else If (SubStr(A_Language, 1 , 4) == "0419" OR languageToUse == "Russian") {
        IniRead, LangData, %LocaleFile%, %languageToUse%
        If (LangData = "") {
            OutputDebug, %languageToUse% wasn't found, reverting to English
            setLang()
            return
        }
        currentLanguage := languageToUse
    } Else { ;Default to English if none of the above languages were used
        IniRead, LangData, %LocaleFile%, English
        If LangData = ""
            Throw, Exception("Language data is missing! Please contact " . Email . " for help")
        currentLanguage := "English"
    }

    ;Create global variables for each language data item
    Loop, Parse, LangData, "`n"
    {
        LangCurrLine := A_LoopField
        Val := ""

        Loop, Parse, LangCurrLine, "="
        {
            If (A_Index == 1) {
                Var := A_LoopField
            } Else If (A_Index != 1) {
                Val .= A_LoopField
                Lang_%Var% := Val
            }
        }
    }
    
    ;Set currentLanguage so later we can "Check" the right item in the Tray menu
    currentLanguage := % "Lang_Lang" . currentLanguage
    
    ;Initialize/Reinitialize Tray menu
    ;Remove all previously existing custom menuitems
    Menu, Tray, DeleteAll

    ;Menu, Tray, Icon, Icon.ico
    Menu, Tray, Tip, %AppTitle%
    Menu, Tray, NoStandard

    ;Add each possible language to the menu dynamically local
    local param := "", ChangeToLangHandler := ""
    IniRead, LangSectionData, %LocaleFile%
    Loop, Parse, LangSectionData, "`n"
    {
        Var := % "Lang_Lang" . A_LoopField
        param := A_LoopField
        ChangeToLangHandler := Func("setLang").Bind(param)
        Menu, Tray, Add, % %Var%, % ChangeToLangHandler, +Radio
    }

    Menu, Tray, Add
    Menu, Tray, Add, %Lang_MenuReload%, Reload
    Menu, Tray, Add, %Lang_MenuAbout%, About
    Menu, Tray, Add, %Lang_MenuExit%, Exit
    Menu, Tray, Default, %Lang_MenuAbout%

    ;"Check" (mark) the currently active language in the menu
    Menu, Tray, Check, % %currentLanguage%

    return
}

About:
	MsgBox 64, %AppTitle%,
	(
App created by %Author%
For feedback and questions contact %Email%

Credits:
Russian Translation - Maryna Dubina
	)
	return

Exit:
    ExitApp

Reload:

	Reload
    return


