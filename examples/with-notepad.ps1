start-wsb -withNotepad `
  -mappedFolders  @{hostFolder = "$home\Downloads"; sandboxFolder = "c:\host\downloads"; readonly = $true  },
                  @{hostFolder = "$home\Documents"; sandboxFolder = "c:\host\documents"; readonly = $false }
