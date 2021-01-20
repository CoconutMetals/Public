# The goal of this script is to audit the 4 file server drives, and log changes made.
# Logging should create a table, showing user, time, file edited, and file server edited on. 
<#
1. Create paths to monitor
2. Create a system watcher, and aim it at the specified paths
3. Have the code write the watcher's findings to a log file, with specific information included
    - Name of last user to interact with the file
    - Whether the file was created, deleted, or modified
    - Name of the file
    - Path of the file 
    - Date of the change
    - The specific file server the file is/was located on, alongside the specific path
4. Make the watcher continue to run and look for changes, not just once
5. Add the watcher to some kind of autostart, possibly on this machine, possibly one per server.
#>

# Setting path variables for each of the file servers. I can't seem to CD to an entire fileserver, I have to select a folder within the server to navigate. That's okay for now.

# $1path = "\\'
# $2path = "\\"
# $3path = "\\"
# $4path = "\\"

# Testing others' code, modified

Function Watch {
    # Just setting the target here.
    $folder = "$1path" 

    # We're looking for any kind of file, but I think some kind of filter variable may be required.
    $filter = "*" 
    
    # This specifies the properties of what is getting monitored
    $attributes = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastAccess, [IO.NotifyFilters]::LastWrite, [IO.NotifyFilters]::Attributes

    # Testing 'Asynchronous Watcher' script, shifted to suit my needs.

    try {
        # Slightly altered watcher, flags all placed in properties section
        $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
            Path = $folder
            filter = $filter
            IncludeSubdirectories = $true
            EnableRaisingEvents = $true
            NotifyFilter = $attributes
        }
        # We're placing logging here.

        $action = {
            # Developing some environmental variables for the 'action'
            
            # Change type info
            $details = $event.SourceEventArgs
            $name = $details.name
            $fullPath = $details.FullPath 
            $oldPath = $details.OldFullPath 
            $oldName = $details.OldName 
            $who = [System.Security.Principal.WindowsIdentity]::GetCurrent().name

            # Type of Change
            $changeType = $details.ChangeType 

            # Time of Change

            $timeStamp = $event.TimeGenerated 

            # With the prior variables set, logging action can be carried out 

            New-Object PSObject -Property @{
                Path = $fullPath
                Change = $changeType
                Time = $timeStamp
                User = $who
            } | Out-File -FilePath C:\Log -append

        }

        # Now, we're subscribing the event handler to all type of changes which we want monitored.

        $handlers = . {
            Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
            Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
            Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action
            Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action
        }

        # Monitoring starts here apparantly, but I thought that's what the 'action' section could be used for. We'll see.


        Write-Host "Watcher is active, surveying $folder."

        # FileSystemWatcher is no longer blocking PowerShell, and we need a way to pause PowerShell while keeping it responsive to new input. An endless loop can accomplish this.

        do {
            # Wait-Event is like Start-Sleep, except it waits specifically for an event after each specified time out.

            Wait-Event -Timeout 3

            # Write a . to show PowerShell is still responsive. -NoNewLine can come in handy with other script

            Write-Host "." -NoNewLine

        } while ($true)
    }
    Finally 

    {
        # This portion will allow Watcher to be halted with CTRL + C
        # Stop Monitoring

        $watcher.EnableRaisingEvents = $false

        # Remove event handlers

        $handlers | ForEach-Object {
            Unregister-Event -SourceIdentifier $_.Name
        }
        # Event handlers are a special kind of background job? Cool. This removes those jobs
        $handlers | Remove-Job

        # And this properly disposes of the Watcher itself. 

        $watcher.dispose()

        Write-Warning "Watcher has been terminated, monitoring will cease."

    }       
}











