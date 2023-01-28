# Pscx - PowerShell Community Extensions Light

This PowerShell module is aimed at providing a widely useful set of additional cmdlets, providers, aliases, filters, functions and
scripts for PowerShell Core that members of the community have expressed interest in.

This repository is a fork of the official PowerShell Community Extensions hosted and [maintained](https://github.com/Pscx/Pscx#maintainers) at GitHub. The fork has been made from 
version [4.0.0-beta4](https://github.com/Pscx/Pscx/releases/tag/v3.3.2) (commit [6980fdf0](https://github.com/Pscx/Pscx/commit/698efdf0ba9cb29b326eb93e4a25ac841cc302dd)).

The customizations made in this fork include:
* upgrade to PowerShell Core 7.2, .Net (Core) 6.0
* compatibility with MacOS and other *nix OS
* build upgraded to VS2022
* packaging and build improvements throughout
* removed cmdlets with low value, seldomly used
* GitHub CI/CD build

## Release notes

See [Changelog.md](CHANGELOG.md) for more detailed information. 

## License
PSCX is licensed under MIT license. This work includes other open-source projects licensed under their respective licenses, attached as appropriate. 
See the PSCX [LICENSE](./LICENSE) file as well [Imports](./Imports/) folder for respective license files of the projects distributed/leveraged.

## Install Pscx

### Pre-requisites

* Install [latest PowerShell Core version](https://github.com/PowerShell/PowerShell/releases/latest)
* Create a profile - may also want to have a look at the _awesome_ [ompgit](https://gitlab.com/danluca/ohmyposhgit) profile & prompt enhancer, especially if you use git SCM (shameless plug :stuck_out_tongue_winking_eye: )

### Installation
* Download the [latest artifact](https://github.com/danluca/Pscx/releases/latest) from GitHub
  * note this artifact may in fact be a double zip of the `Pscx-{version}.zip` file - this is an artifact of GitHub. A solution/work-around may surface, but for the time being this is not seen as a major inconvenience.
* Unzip the `Pscx-{version}.zip` file to `~/Documents/PowerShell/Modules` folder
* Import module PSCX in your PowerShell profile file `import-module pscx`

## Maintainers
 - @danluca and other maintainers in this GitHub repository

### Design constraints
#### C# Cmdlet C#
Required Annotations:
* `Cmdlet` using appropriate PscxVerbs and PscxNouns per the containing module. Do not use plain strings as this interferes with the tooling (see below)
* `Description` specify a summary of what the cmdlet accomplishes. This supports the tooling as well.
* (optional) `DetailedDescription` for more detailed information. While the format is not as flexible as the documentation comments in a `ps1` file, it is in keeping of the best practice of having documentation as close to the code as possible, for contextual/sustaining benefits

Place a new C# cmdlet in the OS appropriate project - `Pscx` for cross-platform, `Pscx.Win` for Windows specific. `Pscx.Core` is a framework level library that both `Pscx` and `Pscx.Win` projects depend upon; it is not intended to contain exportable cmdlets but their base classes and utilities. 

When this OS based functionality separation is not self evident and a class is not entirely cross-platform nor OS specific, at a minimum do annotate the functions that are OS specific with `SupportedOSPlatform` attribute. Refactoring the design where the OS specific classes extend a basic common functionality is encouraged.

When new C# cmdlets are added, remember to add corresponding help file in `Pscx.Help` project.


### Tooling
Several conveniences are made available in support of release process:
* `Tools\version_update.ps1` - consistently updates the version across all assembly info classes, psd1 files, etc.
* `Tools\find_cmdlets.ps1` - reports all the cmdlets and functions found throughout the PSCX solution (all projects and modules) (based on the _Cmdlet_ annotations discussed above). This aids in creating the `psd1` module files. It also helps with creating the content of the _Cmdlets_ and _Functions_ sections below - it pulls the cmdlet name and description (non-MD formatted, but it could be) such that it can be pasted directly into the section and apply MD formatting.

## Included cmdlets and functions

Cmdlets and functions below are sorted by noun. As always, you can get full Powershell help including examples using `get-help [command]`

# Cmdlets
## PSCX cross-platform core module

### Set-FileTime
Sets a file or folder's created and last accessed/write times.

### Edit-File
Edit file with configured editor - VSCode, Notepad++/TextMate, default for OS

### Test-Assembly
Tests whether or not the specified file is a .NET assembly.

### Get-EnvironmentBlock
Get the current environment block

### ConvertFrom-Base64
Converts base64 encoded string to byte array.

### Test-Xml
Tests for well formedness and optionally validates against XML Schema.

### ConvertTo-WindowsLineEnding
Converts the line endings in the specified file to Windows line endings \"\\r\\n\".

### Convert-Xml
Converts XML through a XSL

### Get-TypeName
Get type name as conveniently detailed information

### Get-PathVariable
Gets the specified path-like environment variable, defaults to PATH

### Get-LoremIpsum
Generates a lorem-ipsum text of specified length

### Skip-Object
Skips an object - similar with LINQ Skip() method, allows the user to skip the first N and/or last N objects in a sequence

### Get-PEHeader
Get the Portable Executable file header

### Get-PscxHash
Gets the hash value for the specified file or byte array via the pipeline.

### ConvertTo-Metric
Converts to metric system units

### ConvertTo-UnixLineEnding
Converts the line endings in the specified file to Unix line endings \"\\n\".

### Set-ForegroundWindow
Given an hWnd or window handle, brings that window to the foreground. Useful for restoring a window to uppermost after an application which seizes the foreground is invoked. See also Get-ForegroundWindow

### Get-ForegroundWindow
Returns the hWnd or handle of the window in the foreground on the current desktop. See also Set-ForegroundWindow.

### Test-Script
Test script for validity

### Get-DriveInfo
Get drive information

### Format-Xml
Pretty print for XML files and XmlDocument objects.

### Push-EnvironmentBlock
Pushes the current environment frame onto stack

### Get-FileVersionInfo
Get the file version information

### Pop-EnvironmentBlock
Pops the environment block frame from the stack

### ConvertTo-MacOs9LineEnding
Converts the line endings in the specified file to Mac OS9 and earlier style line endings \"\\r\".

### Format-Byte
Format the byte sizes in human readable forms - progressively increasing the unit based on byte size value

### Get-FileTail
Tails the contents of a file - optionally waiting on new content.

### ConvertTo-Base64
Converts byte array to base64 string.

### Split-PscxString
Splits a single string into an array of strings.

### Add-PathVariable
Adds values to an environment variable of type PATH (default is PATH variable)

### Set-PathVariable
Sets/overrides a path-like variable (defaults to PATH) to the value specified

### Format-Hex
Displays contents of files for byte streams in hex.

### Join-PscxString
Joins an array of strings into a single string.

## PSCX Windows companion module

### Get-MountPoint
Returns all mount points defined for a specific root path.

### Get-AdoDataProvider
Get ADO data provider

### Set-Privilege
Adjusts privileges held by the session.

### Get-SqlDataSet
Query and retrieve SQL data set

### Get-OpticalDriveInfo
Lists Optical drive information

### Disconnect-TerminalSession
Disconnects a specific remote desktop session on a system running Terminal Services/Remote Desktop

### Invoke-SqlCommand
Invokes sql commands on Sql Server database

### Remove-ReparsePoint
Removes NTFS reparse junctions and symbolic links.

### Write-PscxArchive
Creates Archives using 7zip library - supports all types 7zip does

### New-Junction
Creates NTFS directory junctions.

### Get-Privilege
Lists privileges held by the session and their current status.

### New-Hardlink
Creates filesystem hard links. The hardlink and the target must reside on the same NTFS volume.

### Get-ReparsePoint
Gets NTFS reparse point data.

### Get-DomainController
Finds the domain controller

### Set-VolumeLabel
Modifies the label shown in Windows Explorer for a particular disk volume.

### Get-PscxUptime
Get the amount of time the system was up

### Test-UserGroupMembership
Check group membership for the requested user identity

### Get-RunningObject
Retrieves currently running COM object

### Invoke-AdoCommand
Invokes an ADO command

### Remove-MountPoint
Removes a mount point, dismounting the current media if any. If used against the root of a fixed drive, removes the drive letter assignment.

### Get-PscxADObject
Search for objects in the Active Directory/Global Catalog.

### Get-TerminalSession
Get the terminal session

### Get-ShortPath
Gets the short, 8.3 name for the given path.

### Read-PscxArchive
List the contents of an archive - all types supported by 7zip

### Stop-TerminalSession
Logs off a specific remote desktop session on a system running Terminal Services/Remote Desktop

### Get-OleDbDataSet
Retrieve data set through an OLE-DB connection

### Get-AdoConnection
Get an ADO connection

### Expand-PscxArchive
Extract Archives using 7zip library - supports all types 7zip does

### Invoke-OleDbCommand
Invoke commands on OleDb datasources

### Get-OleDbData
Retrieves DB data through an OLE-DB connection

### Get-SqlData
Query and retrieves SQL data

### Invoke-Apartment
Invokes using apartment threading model

### Get-DhcpServer
Gets a list of authorized DHCP servers.

### New-Symlink
Creates filesystem symbolic links. Requires Microsoft Windows 7 or later.

### New-Shortcut
Creates shell shortcuts.

# Functions

## Cross platform
### SubModule CD
Set-PscxLocation


### SubModule FileSystem
Add-DirectoryLength

Add-ShortPath


### SubModule TranscribeSession
'Search-Transcript'


### SubModule Utility
AddAccelerator

PscxHelp

PscxLess

Edit-Profile

Edit-HostProfile

Resolve-ErrorRecord

Resolve-HResult

Resolve-WindowsError

QuoteList

QuoteString

Invoke-GC

Invoke-BatchFile

Get-ViewDefinition

Stop-RemoteProcess

Get-ScreenCss

Get-ScreenHtml

Invoke-Method

Set-Writable

Set-FileAttributes

Set-ReadOnly

Show-Tree

Get-Parameter

Import-VisualStudioVars

Get-ExecutionTime

AddRegex

## Windows Only

### SubModule Sudo

Invoke-Sudo

sudo


### SubModule Vhd
Mount-PscxVHD

Dismount-PscxVHD


### SubModule Wmi
AddAccelerator
