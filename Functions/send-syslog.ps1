Add-Type -TypeDefinition @"
	public enum Syslog_Facility
	{
		kern,
		user,
		mail,
		daemon,
		auth,
		syslog,
		lpr,
		news,
		uucp,
		clock,
		authpriv,
		ftp,
		ntp,
		logaudit,
		logalert,
		cron, 
		local0,
		local1,
		local2,
		local3,
		local4,
		local5,
		local6,
		local7,
	}
"@

Add-Type -TypeDefinition @"
	public enum Syslog_Severity
	{
		Emergency,
		Alert,
		Critical,
		Error,
		Warning,
		Notice,
		Informational,
		Debug
	}
"@

function Send-SyslogMessage
{
<#
.SYNOPSIS
Sends a SYSLOG message to a server running the SYSLOG daemon

.DESCRIPTION
Sends a message to a SYSLOG server as defined in RFC 5424. A SYSLOG message contains not only raw message text,
but also a severity level and application/system within the host that has Generated the message.

.PARAMETER Server
Destination SYSLOG server that message is to be sent to

.PARAMETER Message
Our message

.PARAMETER Severity
Severity level as defined in SYSLOG specification, must be of ENUM type Syslog_Severity

.PARAMETER Facility
Facility of message as defined in SYSLOG specification, must be of ENUM type Syslog_Facility

.PARAMETER Hostname
Hostname of machine the mssage is about, if not specified, local hostname will be used

.PARAMETER Timestamp
Timestamp, myst be of format, "yyyy:MM:dd:-HH:mm:ss zzz", if not specified, current date & time will be used

.PARAMETER UDPPort
SYSLOG UDP port to send message to

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
Nothing is output

.EXAMPLE
Send-SyslogMessage mySyslogserver "The server is down!" Emergency Mail
Sends a syslog message to mysyslogserver, saying "server is down", severity emergency and facility is mail

.NOTES
NAME: Send-SyslogMessage
AUTHOR: Kieran Jacobsen
LASTEDIT: 2015 01 12
KEYWORDS: syslog, messaging, notifications

.LINK
https://github.com/kjacobsen/PowershellSyslog

.LINK
http://poshsecurity.com

#>
[CMDLetBinding()]
Param
(
	[Parameter(mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[String] 
	$Server,
	
	[Parameter(mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[String]
	$Message,
	
	[Parameter(mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[Syslog_Severity]
	$Severity,
	
	[Parameter(mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[Syslog_Facility] 
	$Facility,
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[String]
	$Hostname = '-',
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[String]
	$ApplicationName = 'PowerShell.exe',
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[String]
	$ProcessID = $PID,
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[String]
	$MessageID = '-',
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[String]
	$StructuredData = '-',
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
	[DateTime] 
	$Timestamp = [DateTime]::Now,
	
	[Parameter(mandatory=$false)]
	[ValidateNotNullOrEmpty()]
    [UInt16]
	$UDPPort = 514,
	
	[Parameter(mandatory=$false)]
	[switch]
	$RFC3164
)

# Create a UDP Client Object
$UDPCLient = New-Object System.Net.Sockets.UdpClient
$UDPCLient.Connect($Server, $UDPPort)

# Evaluate the facility and severity based on the enum types
$Facility_Number = $Facility.value__
$Severity_Number = $Severity.value__
Write-Verbose "Syslog Facility, $Facility_Number, Severity is $Severity_Number"

# Calculate the priority
$Priority = ($Facility_Number * 8) + $Severity_Number
Write-Verbose "Priority is $Priority"

<#
1.  FQDN

2.  Static IP address

3.  Hostname - Windows always has one of these

4.  Dynamic IP address

5.  the NILVALUE
#>
if ($hostname -eq '-')
{
	if (($ENV:Computername -ne $null) -and ($ENV:userdnsdomain -ne $null))
	{
		$hostname = $ENV:Computername + "." + $ENV:userdnsdomain
	}
	elseif ((Get-NetIPAddress -PrefixOrigin Manual -SuffixOrigin Manual -ErrorAction SilentlyContinue) -ne $null)
	{
		$interface = (Get-NetIPAddress -PrefixOrigin Dhcp -SuffixOrigin Dhcp -ErrorAction SilentlyContinue) | Select-Object -First 1
		$hostname = $interface.ipaddress
	}
	else
	{
		$hostname = $ENV:Computername
	}
}

if ($RFC3164)
{
	Write-Verbose 'Using RFC 3164 UNIX/BSD message format'
	#Get the timestamp
	$FormattedTimestamp = $Timestamp.ToString('MMM dd HH:mm:ss')
	# Assemble the full syslog formatted Message
	$FullSyslogMessage = "<{0}>{1} {2} {3} {4}" -f $Priority, $FormattedTimestamp, $Hostname, $ApplicationName, $Message

}
else
{
	Write-Verbose 'Using RFC 5424 IETF message format'
	#Get the timestamp
	$FormattedTimestamp = $Timestamp.ToString('yyyy-MM-ddTHH:mm:ss.ffffffzzz')
	# Assemble the full syslog formatted Message
	$FullSyslogMessage = "<{0}>1 {1} {2} {3} {4} {5} {6} {7}" -f $Priority, $FormattedTimestamp, $Hostname, $ApplicationName, $ProcessID, $MessageID, $StructuredData, $Message
}

Write-Verbose "Message to send will be $FullSyslogMessage"

# create an ASCII Encoding object
$Encoding = [System.Text.Encoding]::ASCII

# Convert into byte array representation
$ByteSyslogMessage = $Encoding.GetBytes($FullSyslogMessage)

# If the message is too long, shorten it
if ($ByteSyslogMessage.Length -gt 1024)
{
    $ByteSyslogMessage = $ByteSyslogMessage.SubString(0, 1024)
}

# Send the Message
$UDPCLient.Send($ByteSyslogMessage, $ByteSyslogMessage.Length) | Out-Null

}
