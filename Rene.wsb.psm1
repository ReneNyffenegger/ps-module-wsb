function start-wsb {
 #
 # start-wsb creates a .wsb file in the temp directory whose
 # content is controlled by this function's parameters and
 # then launches the sandbox.
 #
   param(
       [int   ] $memoryInMB = $null,

     # Features that are enabled by default
       [switch] $disableVGpu,
       [switch] $disableNetworking,
       [switch] $disableAudioInput,
       [switch] $disableClipboardRedirection,

     # Features that are disabled by default
       [switch] $enableVideoInput,
       [switch] $enableProtectedClient,
       [switch] $enablePrinterRedirection,

       [string] $logonCommand     = $null,
       [string] $visiblePsCommand = $null,
       [string] $psScript         = $null,

       [array ] $mappedFolders    = @(),

       [switch] $keepWsb
   )

 #
 # The WindowsSandbox.exe process might be running even when
 # no sandbox is active. Therefore checking for
 # WindowsSandboxClient.exe
 #
   $runningSandbox = get-process -name WindowsSandboxClient -errorAction silentlyContinue

   if ($runningSandbox) {
      write-host 'Windows Sandbox is already running.' -foregroundColor red
      return
   }

  [xml] $xml = '<Configuration></Configuration>'

   function add-config {
       param(
           [System.Xml.XmlElement] $Parent,
           [string               ] $ElementName,
           [string               ] $Value
       )
       if ($Value) {
           $newElement = $xml.CreateElement($ElementName)
           $newElement.InnerText = $Value
           $Parent.AppendChild($newElement) | Out-Null
       }
   }

 # Use DocumentElement to avoid the string conversion issue
   $root = $xml.DocumentElement

   if ($psBoundParameters.ContainsKey('memoryInMB')) { add-config $root 'MemoryInMB' $memoryInMB }

   if ($disableVGpu                ) { add-config $root 'VGpu'                 'Disable' }
   if ($disableNetworking          ) { add-config $root 'Networking'           'Disable' }
   if ($disableAudioInput          ) { add-config $root 'AudioInput'           'Disable' }
   if ($disableClipboardRedirection) { add-config $root 'ClipboardRedirection' 'Disable' }
   if ($enableVideoInput           ) { add-config $root 'VideoInput'           'Enable'  }
   if ($enableProtectedClient      ) { add-config $root 'ProtectedClient'      'Enable'  }
   if ($enablePrinterRedirection   ) { add-config $root 'PrinterRedirection'   'Enable'  }

   $cmd  = $logonCommand

   if ($psScript) {
    #
    # Somewhat convoluted addition of the new folder because
    # mappedfolder is declared with [array] which makes it
    # fixed size
    #
       $psScript_ = resolve-path $psScript 
       $mappedFolders = @($mappedFolders) + @(
         @{ hostFolder    = split-path $psScript_
            sandboxFolder ='c:\scriptDir'
            readOnly      = $true
          }
      )

    #
    # executionPolicy is set to prevent
    #    File C:\scriptDir\...ps1 cannot be loaded because running scripts is disabled on this system.
    #    
      $cmd = "cmd /c `"start powershell.exe -noLogo -noExit -executionPolicy unrestricted -file c:/scriptDir/$(split-path $psScript_ -leaf)`""
   }
   elseif ($visiblePsCommand) {
      $cmd = $visiblePsCommand -replace '"', '\"'

    #
    # If cmd is a cmdlet (such as get-date), the -executionPolicy parameter is not needed.
    # It is needed however, if cmd is the path of a script.
    #
      $cmd = "cmd /c `"start powershell.exe -noLogo -noExit -executionPolicy unrestricted -command $cmd`""
   }

 # MappedFolders
   if ($mappedFolders.count -gt 0) {
       $mappedFoldersElem = $xml.CreateElement('MappedFolders')

       foreach ($folder in $mappedFolders) {
           $mf = $xml.CreateElement('MappedFolder')

           add-config $mf 'HostFolder' $folder.HostFolder

           if ($folder.SandboxFolder) {
               add-config $mf 'SandboxFolder' $folder.SandboxFolder
           }

           $readOnlyVal = if ($folder.ReadOnly) { 'true' } else { 'false' }
           add-config $mf 'ReadOnly' $readOnlyVal

           $mappedFoldersElem.AppendChild($mf) | Out-Null
       }
       $root.AppendChild($mappedFoldersElem) | Out-Null
   }

 # LogonCommand
   if ($cmd) {
       $logonElem = $xml.CreateElement('LogonCommand')
       $cmdElem   = $xml.CreateElement('Command')
       $cmdElem.InnerText = $cmd

       $null = $logonElem.AppendChild($cmdElem)
       $null = $root.AppendChild($logonElem)
   }

   $wsbContent = $xml.OuterXml

 # Create temporary .wsb file and launch sandbox
   $tempWsbPath = join-path $env:temp "sandbox_$(get-date -format 'yyyyMMdd_HHmmss').wsb"

   $wsbContent | out-file -filePath $tempWsbPath -encoding UTF8 -force
   write-host "Created temporary config: $tempWsbPath" -foregroundColor Green

   write-host "Starting Windows Sandbox..." -foregroundColor Cyan
   invoke-item -literalPath $tempWsbPath

   start-sleep -seconds 4

   if (! $keepWsb ) {
    # Remove wsb file
      write-host "Deleting temporary .wsb file..." -foregroundColor Yellow
      remove-item -path $tempWsbPath -force -errorAction stop
      write-host "Temporary .wsb file deleted successfully." -foregroundColor green
   }
}

function start-wsbWithNotepad {
 #
 # start-wsbWithNotepad maps the host System32 folder into the
 # sandbox and copies the host's notepad.exe to the sandbox's
 # System32 directory.
 #

   $lang = [System.Globalization.CultureInfo]::CurrentUICulture.Name
   write-host "lang = $lang"

   $mappedFolders = @(
      @{
         hostFolder    = 'C:\Windows\System32'
         sandboxFolder = 'C:\host\Windows\System32'
         readOnly      = $true
      }
   )

   $psCmd = 'copy-item C:\host\Windows\System32\notepad.exe C:\Windows\System32\notepad.exe'

   $encodedCopyScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($psCmd))
   $logonCommand      = "powershell.exe -noLogo -executionPolicy unrestricted -encodedCommand $encodedCopyScript"

   start-wsb -mappedFolders $mappedFolders -logonCommand $logonCommand

}
