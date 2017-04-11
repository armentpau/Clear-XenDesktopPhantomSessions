# Clear-XenDesktopPhantomSessions

## Synopsis
Queries the XenDesktop/XenAPp Citrix database and clears any connection errors found by resetting the Broker Agent service on impacted servers.

## Description
This script queries the citrix database at the specified time period and then works to reset any affected broker services on impacted servers.

## PARAMETER Database
The database name where the XenDesktop/XenApp data is stored.  This can be either a live instance of your Citrix database or can be a copy of the datase (provided the copy is within the scan frequency)
	
## PARAMETER DatabaseServerInstance
The SQL instance where the Database lives.
	
## PARAMETER DatabaseUserId
The username used to log into the Citrix database to query for connection errors.
	
## PARAMETER DatabasePassword
The password associated with DatabaseUserId.
	
## PARAMETER ServerDomain
The domain name which is prefixed to the server names in the citrix database.  This does not have to be all uppercase as the script converts the entire computer name to lowercase.
	
## PARAMETER OutputFile
If specified, the script will output any sessions that is has to reset to a file as well as to the screen.  The outputed file will be in csv format.
	
## PARAMETER MinutesBetweenLoops
This is how long the script sleeps before it once again checks the sql database for errors.
	
## EXAMPLE

PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain" -outputfile "c:\outputFiles\ResetSessions.csv"

## EXAMPLE

PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain" -outputfile "c:\outputFiles\ResetSessions.csv" -MinutesBetweenLoops 10
 
## EXAMPLE

PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain" -MinutesBetweenLoops 10

## EXAMPLE

PS C:\> .Clear-XenDesktopPhantomSessions -Database "Client-Citrix" -DatabaseServerInstance "9999sqlni01\9999sqlni01" -DatabaseUserId "username" -DatabasePassword "Password" -ServerDomain "clientDomain"

## NOTES
Additional information about the file.
