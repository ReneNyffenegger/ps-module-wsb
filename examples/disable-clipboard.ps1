set-clipboard -value 'This value was copied to the clipboard in the host.'
  start-wsb -disableClipboardRedirection -visiblePsCommand 'write-host (get-clipboard); set-clipboard -value "This value was copied to the clipboard in the sandbox."; read-host "Press any key to shutdown sandbox"; shutdown -s -t 0'
# start-wsb                              -visiblePsCommand 'write-host (get-clipboard); set-clipboard -value "This value was copied to the clipboard in the sandbox."; read-host "Press any key to shutdown sandbox"; shutdown -s -t 0'

while (-not (get-process WindowsSandboxClient -ea ignore)) {
 #
 # Wait until Sandbox is minimally started
 #
   start-sleep 1
}

while (get-process WindowsSandboxClient -ea ignore) {
 #
 # Wait until Sandbox is terminated
 #
   write-host (get-clipboard)
   start-sleep 1
}
