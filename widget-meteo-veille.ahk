#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Ignore

; ============================================================================
;  Veille du widget météo : relance widget-meteo.ahk s'il a disparu (plantage),
;  sauf si l'utilisateur l'a quitté lui-même (fichier arret-volontaire.txt,
;  écrit par le widget à la fermeture voulue, effacé à son démarrage).
;  Lancée toutes les 5 minutes par la tâche planifiée « AHK - veille widget
;  meteo » (droits normaux : le widget relancé ne tourne pas en administrateur).
;  Ne fait rien d'autre et se termine aussitôt.
; ============================================================================

dossier := EnvGet("LOCALAPPDATA") "\WidgetMeteo"
widget := A_ScriptDir "\widget-meteo.ahk"

if FileExist(dossier "\arret-volontaire.txt") || !FileExist(widget)
    ExitApp

if !WidgetEnService()
    Relancer()
ExitApp

; Un widget « normal » tourne-t-il ? (les modes de test, lancés avec des
; arguments après le nom du script, ne comptent pas)
WidgetEnService() {
    requete := "SELECT CommandLine FROM Win32_Process WHERE Name LIKE 'AutoHotkey%'"
    for p in ComObjGet("winmgmts:").ExecQuery(requete) {
        ligne := p.CommandLine
        if (ligne != "" && RegExMatch(ligne, 'i)widget-meteo\.ahk"?\s*$'))
            return true
    }
    return false
}

Relancer() {
    global dossier, widget
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " veille : widget absent, relancé`n",
        dossier "\journal.log", "UTF-8")
    Run('"' A_AhkPath '" "' widget '"', A_ScriptDir)
}
