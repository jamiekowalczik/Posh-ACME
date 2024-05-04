function Get-CurrentPluginType { 'dns-01' }

function Add-DnsTxt {
    [CmdletBinding(DefaultParameterSetName='Secure')]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=1)]
        [string]$TxtValue,
        [Parameter(ParameterSetName='Secure',Mandatory,Position=2)]
        [securestring]$DSToken,
        [Parameter(ParameterSetName='DeprecatedInsecure',Mandatory,Position=2)]
        [string]$DSTokenInsecure,
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )

    # get the plaintext version of the token
    if ('Secure' -eq $PSCmdlet.ParameterSetName) {
        $DSTokenInsecure = [pscredential]::new('a',$DSToken).GetNetworkCredential().Password
    }

    $apiRoot = 'https://api.dnsimple.com/v2'
    $commonParams = @{
        Headers = @{Authorization="Bearer $DSTokenInsecure"}
        ContentType = 'application/json'
        ErrorAction = 'Stop'
        Verbose = $false
    }

    # get the account ID for our token
    try {
        Write-Debug "GET $apiRoot/whoami"
        $resp = Invoke-RestMethod "$apiRoot/whoami" @commonParams @script:UseBasic
        Write-Debug "Response:`n$($resp | ConvertTo-Json -Depth 10)"
        if (-not $resp.data.account) {
            throw "DNSimple account data not found. Wrong token type?"
        }
        $acctID = $resp.data.account.id.ToString()
    } catch { throw }
    Write-Debug "Found account $acctID"

    # get the zone name for our record
    $zoneName = Find-DSZone $RecordName $acctID $commonParams
    if ([String]::IsNullOrWhiteSpace($zoneName)) {
        throw "Unable to find zone for $RecordName in account $acctID"
    }
    Write-Debug "Found zone $zoneName"

    # get all the instances of the record
    try {
        $recShort = ($RecordName -ireplace [regex]::Escape($zoneName), [string]::Empty).TrimEnd('.')
        $uri = "$apiRoot/$acctID/zones/$zoneName/records?name=$recShort&type=TXT&per_page=100"
        Write-Debug "GET $uri"
        $resp = Invoke-RestMethod $uri @commonParams @script:UseBasic
        Write-Debug "Response:`n$($resp | ConvertTo-Json -Depth 10)"
        # We're ignoring potential pagination here because there really shouldn't be more than 100
        # TXT records with the same FQDN in the zone.
    } catch { throw }

    $rec = $resp.data | Where-Object { $_.content -eq "`"$TxtValue`"" }

    if (-not $rec) {
        # add new record
        try {
            Write-Verbose "Adding a TXT record for $RecordName with value $TxtValue"
            $uri = "$apiRoot/$acctID/zones/$zoneName/records"
            $bodyJson = @{name=$recShort;type='TXT';content=$TxtValue;ttl=10} | ConvertTo-Json -Compress
            Write-Debug "POST $uri`n$bodyJson"
            $resp = Invoke-RestMethod $uri -Method Post -Body $bodyJson @commonParams @script:UseBasic
            Write-Debug "Response:`n$($resp | ConvertTo-Json -Depth 10)"
        } catch { throw }
    } else {
        Write-Debug "Record $RecordName already contains $TxtValue. Nothing to do."
    }

    <#
    .SYNOPSIS
        Add a DNS TXT record to DNSimple.

    .DESCRIPTION
        Add a DNS TXT record to DNSimple.

    .PARAMETER RecordName
        The fully qualified name of the TXT record.

    .PARAMETER TxtValue
        The value of the TXT record.

    .PARAMETER DSToken
        The Account API token for DNSimple.

    .PARAMETER DSTokenInsecure
        (DEPRECATED) The Account API token for DNSimple.

    .PARAMETER ExtraParams
        This parameter can be ignored and is only used to prevent errors when splatting with more parameters than this function supports.

    .EXAMPLE
        $token = Read-Host "DNSimple Token" -AsSecureString
        PS C:\>Add-DnsTxt '_acme-challenge.example.com' 'txt-value' $token

        Adds a TXT record for the specified site with the specified value on Windows.
    #>
}

function Remove-DnsTxt {
    [CmdletBinding(DefaultParameterSetName='Secure')]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=1)]
        [string]$TxtValue,
        [Parameter(ParameterSetName='Secure',Mandatory,Position=2)]
        [securestring]$DSToken,
        [Parameter(ParameterSetName='DeprecatedInsecure',Mandatory,Position=2)]
        [string]$DSTokenInsecure,
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )

    # get the plaintext version of the token
    if ('Secure' -eq $PSCmdlet.ParameterSetName) {
        $DSTokenInsecure = [pscredential]::new('a',$DSToken).GetNetworkCredential().Password
    }

    $apiRoot = 'https://api.dnsimple.com/v2'
    $commonParams = @{
        Headers = @{Authorization="Bearer $DSTokenInsecure"}
        ContentType = 'application/json'
        ErrorAction = 'Stop'
        Verbose = $false
    }

    # get the account ID for our token
    try {
        Write-Debug "GET $apiRoot/whoami"
        $resp = Invoke-RestMethod "$apiRoot/whoami" @commonParams @script:UseBasic
        Write-Debug "Response:`n$($resp | ConvertTo-Json -Depth 10)"
        if (-not $resp.data.account) {
            throw "DNSimple account data not found. Wrong token type?"
        }
        $acctID = $resp.data.account.id.ToString()
    } catch { throw }
    Write-Debug "Found account $acctID"

    # get the zone name for our record
    $zoneName = Find-DSZone $RecordName $acctID $commonParams
    if ([String]::IsNullOrWhiteSpace($zoneName)) {
        throw "Unable to find zone for $RecordName in account $acctID"
    }
    Write-Debug "Found zone $zoneName"

    # get all the instances of the record
    try {
        $recShort = ($RecordName -ireplace [regex]::Escape($zoneName), [string]::Empty).TrimEnd('.')
        $uri = "$apiRoot/$acctID/zones/$zoneName/records?name=$recShort&type=TXT&per_page=100"
        Write-Debug "GET $uri"
        $resp = Invoke-RestMethod $uri @commonParams @script:UseBasic
        Write-Debug "Response:`n$($resp | ConvertTo-Json -Depth 10)"
        # We're ignoring potential pagination here because there really shouldn't be more than 100
        # TXT records with the same FQDN in the zone.
    } catch { throw }

    $rec = $resp.data | Where-Object { $_.content -eq "`"$TxtValue`"" }

    if (-not $rec) {
        Write-Debug "Record $RecordName with value $TxtValue doesn't exist. Nothing to do."
    } else {
        # delete record
        try {
            Write-Verbose "Removing TXT record for $RecordName with value $TxtValue"
            $uri = "$apiRoot/$acctID/zones/$zoneName/records/$($rec.id)"
            Write-Debug "DELETE $uri"
            $resp = Invoke-RestMethod $uri -Method Delete @commonParams @script:UseBasic
            Write-Debug "Response:`n$($resp | ConvertTo-Json -Depth 10)"
        } catch { throw }
    }

    <#
    .SYNOPSIS
        Remove a DNS TXT record from DNSimple.

    .DESCRIPTION
        Remove a DNS TXT record from DNSimple.

    .PARAMETER RecordName
        The fully qualified name of the TXT record.

    .PARAMETER TxtValue
        The value of the TXT record.

    .PARAMETER DSToken
        The Account API token for DNSimple.

    .PARAMETER DSTokenInsecure
        (DEPRECATED) The Account API token for DNSimple.

    .PARAMETER ExtraParams
        This parameter can be ignored and is only used to prevent errors when splatting with more parameters than this function supports.

    .EXAMPLE
        $token = Read-Host "DNSimple Token" -AsSecureString
        PS C:\>Remove-DnsTxt '_acme-challenge.example.com' 'txt-value' $token

        Removes a TXT record for the specified site with the specified value on Windows.
    #>
}

function Save-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    <#
    .SYNOPSIS
        Not required.

    .DESCRIPTION
        This provider does not require calling this function to commit changes to DNS records.

    .PARAMETER ExtraParams
        This parameter can be ignored and is only used to prevent errors when splatting with more parameters than this function supports.
    #>
}

############################
# Helper Functions
############################

# API Docs
# https://developer.dnsimple.com/v2/

function Find-DSZone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=1)]
        [string]$AcctID,
        [Parameter(Mandatory,Position=2)]
        [hashtable]$CommonRestParams
    )

    # setup a module variable to cache the record to zone mapping
    # so it's quicker to find later
    if (!$script:DSRecordZones) { $script:DSRecordZones = @{} }

    # check for the record in the cache
    if ($script:DSRecordZones.ContainsKey($RecordName)) {
        return $script:DSRecordZones.$RecordName
    }

    $apiRoot = 'https://api.dnsimple.com/v2'

    # Since the provider could be hosting both apex and sub-zones, we need to find the closest/deepest
    # sub-zone that would hold the record rather than just adding it to the apex. So for something
    # like _acme-challenge.site1.sub1.sub2.example.com, we'd look for zone matches in the following
    # order:
    # - site1.sub1.sub2.example.com
    # - sub1.sub2.example.com
    # - sub2.example.com
    # - example.com

    $pieces = $RecordName.Split('.')
    for ($i=0; $i -lt ($pieces.Count-1); $i++) {
        $zoneTest = $pieces[$i..($pieces.Count-1)] -join '.'
        Write-Debug "Checking $zoneTest"
        try {
            # if the call succeeds, the zone exists, so we don't care about the actualy response
            $uri = "$apiRoot/$AcctID/zones/$zoneTest"
            Write-Debug "GET $uri"
            $null = Invoke-RestMethod $uri @CommonRestParams @script:UseBasic
            $script:DSRecordZones.$RecordName = $zoneTest
            return $zoneTest
        } catch {
            if ($_.Exception.StatusCode -ne 404) {
                Write-Debug ($_.ToString())
            }
        }
    }

    return $null

}
