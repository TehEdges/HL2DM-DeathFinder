Add-Type -path ".\HL2DM_Demo_Parser\bin\Debug\net8.0\HL2DM_Demo_Parser.dll"
class DemoHeader{
    [String]    $FileStamp
    [UInt32]      $DemoProtocol
    [Uint32]      $NetworkProtocol
    [String]    $ServerName
    [String]    $ClientName
    [String]    $MapName
    [String]    $GameDirectory
    [Float]     $PlaybackTime
    [UInt32]     $TickCount
    [UInt32]     $FrameCount
    [UInt32]      $SignOnLength

    DemoHeader([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.FileStamp = $stream.readASCIIString(8)
        $this.DemoProtocol = $Stream.readInt32()
        $this.NetworkProtocol = $stream.readInt32()
        $this.ServerName = $stream.readASCIIString(260)
        $this.ClientName = $stream.readASCIIString(260)
        $this.MapName = $stream.readASCIIString(260)
        $this.GameDirectory = $stream.readASCIIString(260)
        $this.PlaybackTime = $stream.readFloat32()
        $this.TickCount = $stream.readint32()
        $this.FrameCount = $stream.readint32()
        $this.SignOnLength = $stream.readint32()
    }
}

class SnappyDecompressor {
    [byte[]]$Array
    [int]$currentPos
    [int[]]$WORD_MASK = @(0, 0xff, 0xffff, 0xffffff, 0xffffffff)

    SnappyDecompressor([byte[]]$compressed) {
        $this.Array = $compressed
        $this.currentPos = 0
    }

    [void] CopyBytes([byte[]]$fromArray, [int]$fromPos, [byte[]]$toArray, [int]$toPos, [int]$length) {
        for ($i = 0; $i -lt $length; $i++) {
            $toArray[$toPos + $i] = $fromArray[$fromPos + $i]
        }
    }

    [void] SelfCopyBytes([byte[]]$array, [int]$pos, [int]$offset, [int]$length) {
        for ($i = 0; $i -lt $length; $i++) {
            $array[$pos + $i] = $array[$pos - $offset + $i]
        }
    }

    [int] ReadUncompressedLength() {
        $result = 0
        $shift = 0
        
        while ($shift -lt 32 -and $this.currentpos -lt $this.Array.Length) {
            $c = $this.Array[$this.currentpos]
            $this.currentpos++
            $val = $c -band 0x7f
            
            if ((($val -shl $shift) -shr $shift) -ne $val) {
                return -1
            }
            $result = $result -bor ($val -shl $shift)
            if ($c -lt 128) {
                return $result
            }
            $shift += 7
        }
        return -1
    }

    [bool] UncompressToBuffer([byte[]]$outBuffer) {
        $temparray = $this.Array
        $pos = $this.currentPos
        $arrayLength = $temparray.Length
        $outPos = 0

        $c = 0
        $len = 0
        $smallLen = 0
        $offset = 0

        while ($pos -lt $temparray.Length) {
            $c = $temparray[$pos]
            $pos += 1

            if (($c -band 0x3) -eq 0) {
                # Literal
                $len = (($c -shr 2) + 1)

                if ($len -gt 60) {
                    if ($pos + 3 -ge $arrayLength) {
                        return $false
                    }

                    $smallLen = $len - 60
                    $len = $temparray[$pos] + ($temparray[$pos + 1] -shl 8) + ($temparray[$pos + 2] -shl 16) + ($temparray[$pos + 3] -shl 24)
                    $len = ($len -band $this.WORD_MASK[$smallLen]) + 1
                    $pos += $smallLen
                }

                if ($pos + $len -gt $arrayLength) {
                    return $false
                }

                # Copy bytes from the array to outBuffer
                $this.CopyBytes($temparray,$pos,$outBuffer,$outPos,$len)
                $pos += $len
                $outPos += $len
            } else {
                switch ($c -band 0x3) {
                    1 {
                        $len = (($c -shr 2) -band 0x7) + 4
                        $offset = $temparray[$pos] + (([uint32]$c -shr 5) -shl 8)
                        $pos += 1
                    }
                    2 {
                        if ($pos + 1 -ge $arrayLength) {
                            return $false
                        }
                        $len = (([uint32]$c -shr 2) + 1)
                        $offset = $temparray[$pos] + ([uint32]$temparray[$pos + 1] -shl 8)
                        $pos += 2
                    }
                    3 {
                        if ($pos + 3 -ge $arrayLength) {
                            return $false
                        }
                        $len = (($c -shr 2) + 1)
                        $offset = $temparray[$pos] + ([uint32]$temparray[$pos + 1] -shl 8) + ([uint32]$temparray[$pos + 2] -shl 16) + ([uint32]$temparray[$pos + 3] -shl 24)
                        $pos += 4
                    }
                    default {}
                }

                if ($offset -eq 0 -or $offset -gt $outPos) {
                    return $false
                }

                # Self copy bytes from outBuffer
                $this.SelfCopyBytes($outBuffer,$outPos,$offset,$len)
                $outPos += $len
            }
        }
        return $true
    }

    [byte[]] Uncompress([byte[]]$compressed, [int]$maxLength) {
        # Validate input types
        if ($compressed -isnot [byte[]]) {
            throw [System.TypeLoadException]("Input must be a byte array.")
        }

        $decompressor = [SnappyDecompressor]::new($compressed)
        $length = $decompressor.ReadUncompressedLength()

        if ($length -eq -1) {
            throw [System.Exception]("Invalid Snappy bitstream")
        }
        if ($length -gt $maxLength) {
            throw [System.Exception]("The uncompressed length of $length is too big, expect at most $maxLength")
        }

        $uncompressed = New-Object byte[] $length
        if (-not $decompressor.UncompressToBuffer($uncompressed)) {
            throw [System.Exception]("Invalid Snappy bitstream")
        }

        return $uncompressed
    }
}

enum GameEventTypes
{
    server_cvar = 3
    round_start = 37
    player_death = 23
    mm_lobby_member_join = 72
    player_team = 21
    player_disconnect = 10
}
enum GameEventValueType {
	STRING = 1
	FLOAT = 2
	LONG = 3
	SHORT = 4
	BYTE = 5
	BOOLEAN = 6
	LOCAL = 7
}

enum PVS {
	PRESERVE = 0
	ENTER = 1
	LEAVE = 2
	DELETE = 4
}

enum SendPropType {
	DPT_Int
	DPT_Float
	DPT_Vector
	DPT_VectorXY
	DPT_String
	DPT_Array
	DPT_DataTable
	DPT_NUMSendPropTypes
}

enum SendPropFlag {
	SPROP_UNSIGNED = (1-shl 0) # Unsigned integer data.
	SPROP_COORD = (1-shl 1) # If this is set, the float/vector is treated like a world coordinate.
	# Note that the bit count is ignored in this case.
	SPROP_NOSCALE = (1 -shl 2) # For floating point, don't scale into range, just take value as is.
	SPROP_ROUNDDOWN = (1 -shl 3) # For floating point, limit high value to range minus one bit unit
	SPROP_ROUNDUP = (1 -shl 4) # For floating point, limit low value to range minus one bit unit
	SPROP_NORMAL = (1 -shl 5) # If this is set, the vector is treated like a normal (only valid for vectors)
	SPROP_EXCLUDE = (1 -shl 6) # This is an exclude prop (not excludED, but it points at another prop to be excluded).
	SPROP_XYZE = (1 -shl 7) # Use XYZ/Exponent encoding for vectors.
	SPROP_INSIDEARRAY = (1 -shl 8) # This tells us that the property is inside an array, so it shouldn't be put into the
	# flattened property list. Its array will point at it when it needs to.
	SPROP_PROXY_ALWAYS_YES = (1 -shl 9) # Set for datatable props using one of the default datatable proxies like
	# SendProxy_DataTableToDataTable that always send the data to all clients.
	SPROP_CHANGES_OFTEN = (1 -shl 10) # this is an often changed field, moved to head of sendtable so it gets a small index
	SPROP_IS_A_VECTOR_ELEM = (1 -shl 11) # Set automatically if SPROP_VECTORELEM is used.
	SPROP_COLLAPSIBLE = (1 -shl 12) # Set automatically if it's a datatable with an offset of 0 that doesn't change the pointer
	# (ie: for all automatically-chained base classes).
	# In this case, it can get rid of this SendPropDataTable altogether and spare the
	# trouble of walking the hierarchy more than necessary.
	SPROP_COORD_MP = (1 -shl 13) # Like SPROP_COORD, but special handling for multiplayer games
	SPROP_COORD_MP_LOWPRECISION = (1 -shl 14) # Like SPROP_COORD, but special handling for multiplayer games
	# where the fractional component only gets a 3 bits instead of 5
	SPROP_COORD_MP_INTEGRAL = (1 -shl 15) # SPROP_COORD_MP, but coordinates are rounded to integral boundaries
	SPROP_VARINT = (1 -shl 5)
}

Enum MessageType {
    Sigon = 1
    Packet = 2
    SyncTick = 3
    ConsoleCmd = 4
    UserCmd = 5
    DataTables = 6
    Stop = 7
    StringTables = 8
}

enum PacketTypeId {
    unknown = 0
	file = 2
	netTick = 3
	stringCmd = 4
	setConVar = 5
	sigOnState = 6
	print = 7
	serverInfo = 8
	classInfo = 10
	setPause = 11
	createStringTable = 12
	updateStringTable = 13
	voiceInit = 14
	voiceData = 15
	parseSounds = 17
	setView = 18
	fixAngle = 19
	bspDecal = 21
	userMessage = 23
	entityMessage = 24
	gameEvent = 25
	packetEntities = 26
	tempEntities = 27
	preFetch = 28
	menu = 29
	gameEventList = 30
	getCvarValue = 31
	cmdKeyValues = 32
}

enum UserMessageType {
	Unknown = -1
	Geiger = 0
	Train = 1
	HudText = 2
	SayText = 3
	SayText2 = 4
	TextMsg = 5
	ResetHUD = 6
	GameTitle = 7
	ItemPickup = 8
	ShowMenu = 9
	Shake = 10
	Fade = 11
	VGUIMenu = 12
	Rumble = 13
	CloseCaption = 14
	SendAudio = 15
	VoiceMask = 16
	RequestState = 17
	Damage = 18
	HintText = 19
	KeyHintText = 20
	HudMsg = 21
	AmmoDenied = 22
	AchievementEvent = 23
	UpdateRadar = 24
	VoiceSubtitle = 25
	HudNotify = 26
	HudNotifyCustom = 27
	PlayerStatsUpdate = 28
	PlayerIgnited = 29
	PlayerIgnitedInv = 30
	HudArenaNotify = 31
	UpdateAchievement = 32
	TrainingMsg = 33
	TrainingObjective = 34
	DamageDodged = 35
	PlayerJarated = 36
	PlayerExtinguished = 37
	PlayerJaratedFade = 38
	PlayerShieldBlocked = 39
	BreakModel = 40
	CheapBreakModel = 41
	BreakModel_Pumpkin = 42
	BreakModelRocketDud = 43
	CallVoteFailed = 44
	VoteStart = 45
	VotePass = 46
	VoteFailed = 47
	VoteSetup = 48
	PlayerBonusPoints = 49
	SpawnFlyingBird = 50
	PlayerGodRayEffect = 51
	SPHapWeapEvent = 52
	HapDmg = 53
	HapPunch = 54
	HapSetDrag = 55
	HapSet = 56
	HapMeleeContact = 57
}

class TempEntityPacket
{
    [int]$entitycount
    [int]$length
    [HL2DM_Demo_Parser.BitStream]$data

    TempEntityPacket($entitycount, $length, $data)
    {
        $this.entitycount = $entitycount
        $this.length = $length
        $this.data = $data
    }
}

class TempEntityPacketParser
{
    [HL2DM_Demo_Parser.BitStream]$stream

    TempEntityPacketParser([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.stream = $Stream
    }

    [TempEntityPacket]ParsePacket()
    {
        $entitycount = $this.stream.readuint8()
        $length = $this.stream.readVarInt($false)
        $data = $this.stream.readBitStream($length)

        return [TempEntityPacket]::New($entitycount, $length, $data)
    }
    
}

class ClassInfoPacket
{
    [int]$count
    [bool]$create
    [ClassInfoEntity[]]$entries
}

class ClassInfoEntity
{
    [Int]$ClassID
    [String]$ClassName
    [String]$DataTableName
}

class ClassInfoParser
{
    [HL2DM_Demo_Parser.BitStream]$Stream

    ClassInfoParser([HL2DM_Demo_Parser.BitStream]$stream)
    {
        $this.Stream = $stream
        $this.ParsePacket()
    }

    [ClassInfoPacket]ParsePacket()
    {
        $ClassInfoPacket = [ClassInfoPacket]::New()
        $ClassInfoPacket.count = $this.Stream.readUint16()
        $ClassInfoPacket.create = $this.Stream.readBoolean()

        if(!$classInfoPacket.Create)
        {
            $bits = [Math]::Log($classInfoPacket.count) / [Math]::Log(2) + 1
            for($i = 0; $i -lt $ClassInfoPacket.count; $i++)
            {
                $entry = [ClassInfoEntity]::New()
                $entry.ClassID = $this.Stream.ReadBits($bits, $false)
                $entry.ClassName = $this.stream.readASCIIString($null)
                $entry.DataTableName = $this.Stream.readASCIIString($Null)
                $ClassInfoPacket.entries += $entry
            }
        }
        return $ClassInfoPacket
    }
}

class SoundPacket
{
    [PacketTypeId]$PacketTypeid = [PacketTypeId]::parseSounds
    [bool]$Reliable
    [int]$num
    [int]$length
    [HL2DM_Demo_Parser.BitStream]$data

    SoundPacket([bool]$Reliable, [int]$num, [int]$length, [HL2DM_Demo_Parser.BitStream]$data)
    {
        $this.Reliable = $Reliable
        $this.num = $num
        $this.length = $length
        $this.data = $data
    }
}

class soundPacketPacketReader
{
    [HL2DM_Demo_Parser.BitStream]$stream

    soundPacketPacketReader([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.stream = $Stream
    }

    [SoundPacket]ParsePacket()
    {
        $reliable = $this.stream.readBoolean()
        $num = if($reliable){1}else{$this.stream.readUint8()}
        $length = if($reliable){$this.stream.readuint8()}else{$this.stream.readUint16()}
        $data = $this.stream.readBitStream($length)

        return [SoundPacket]::New($reliable, $num, $length, $data)
    }
}

class PacketReader
{
    $Types = @{
        [PacketTypeId]::serverInfo = '{
            "properties": [
                {
                    "Name": "version",
                    "Type": "16"
                },
                {
                    "Name": "serverCount",
                    "Type": "32"
                },
                {
                    "Name": "stv",
                    "Type": "b"
                },
                {
                    "Name": "dedicated",
                    "Type": "b"
                },
                {
                    "Name": "maxCrc",
                    "Type": "32"
                },
                {
                    "Name": "maxClasses",
                    "Type": "16"
                },
                {
                    "Name": "mapHash",
                    "Type": "128"
                },
                {
                    "Name": "playerCount",
                    "Type": "8"
                },
                {
                    "Name": "maxPlayerCount",
                    "Type": "8"
                },
                {
                    "Name": "intervalPerTick",
                    "Type": "f32"
                },
                {
                    "Name": "platform",
                    "Type": "s1"
                },
                {
                    "Name": "game",
                    "Type": "s"
                },
                {
                    "Name": "map",
                    "Type": "s"
                },
                {
                    "Name": "skybox",
                    "Type": "s"
                },
                {
                    "Name": "servername",
                    "Type": "s"
                },
                {
                    "Name": "replay",
                    "Type": "b"
                }
            ]
        }
        ' | ConvertFrom-Json
        [PacketTypeID]::netTick = '{
            "properties": [
                    {
                        "Name": "tick",
                        "Type": "32"
                    },
                    {
                        "Name": "frameTime",
                        "Type": "16"
                    },
                    {
                        "Name": "stdDev",
                        "Type": "16"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::sigOnState = '{
            "properties": [
                    {
                        "Name": "state",
                        "Type": "8"
                    },
                    {
                        "Name": "count",
                        "Type": "32"
                    },
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::file = '{
            "properties": [
                    {
                        "Name": "transferid",
                        "Type": "32"
                    },
                    {
                        "Name": "fileName",
                        "Type": "s"
                    },
                    {
                        "Name": "requested",
                        "Type": "b"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::stringCmd = '{
            "properties": [
                    {
                        "Name": "command",
                        "Type": "s"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::print = '{
            "properties": [
                    {
                        "Name": "value",
                        "Type": "s"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::setPause = '{
            "properties": [
                    {
                        "Name": "paused",
                        "Type": "b"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::setView = '{
            "properties": [
                    {
                        "Name": "index",
                        "Type": "11"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::fixAngle = '{
            "properties": [
                    {
                        "Name": "relative",
                        "Type": "b"
                    },
                    {
                        "Name": "x",
                        "Type": "16"
                    },
                    {
                        "Name": "y",
                        "Type": "16"
                    },
                    {
                        "Name": "z",
                        "Type": "16"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::entityMessage = '{
            "properties": [
                    {
                        "Name": "index",
                        "Type": "11"
                    },
                    {
                        "Name": "classid",
                        "Type": "9"
                    },
                    {
                        "Name": "length",
                        "Type": "11"
                    },
                    {
                        "Name": "data",
                        "Type": "$length"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::preFetch = '{
            "properties": [
                    {
                        "Name": "index",
                        "Type": "14"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::menu = '{
            "properties": [
                    {
                        "Name": "type",
                        "Type": "u16"
                    },
                    {
                        "Name": "length",
                        "Type": "u16"
                    },
                    {
                        "Name": "data",
                        "Type": "$length*8"
                    }
                ]
            }' | ConvertFrom-Json
        [PacketTypeId]::createStringTable = 'StringTablePacketReader'
        [PacketTypeId]::setConVar = 'setConVarPacketReader'
        [PacketTypeId]::userMessage = 'UserMsgParser'
        [PacketTypeId]::packetEntities = 'PacketEntityParser'
        [PacketTypeId]::gameEvent = 'GameEventParser'
        [PacketTypeId]::classInfo = 'ClassInfoParser'
        [PacketTypeId]::bspDecal = 'bspDecalPacketReader'
        [PacketTypeId]::parseSounds = 'soundPacketPacketReader'
        [PacketTypeId]::voiceInit = 'voiceInitPacketParser'
        [PacketTypeId]::voiceData = 'voiceDataPacketParser'
        [PacketTypeId]::gameEventList = 'GameEventListPacketParser'
        [PacketTypeId]::tempEntities = 'TempEntityPacketParser'
        [PacketTypeId]::updateStringTable = 'UpdateStringTablePacketParser'
    }
    $PacketTypeLogic
    [PacketTypeId]$PacketType

    PacketReader([PacketTypeId]$PacketType)
    {
        $this.PacketType = $PacketType
        $this.PacketTypeLogic = $this.types[$PacketType]
        if(-not $this.PacketTypeLogic)
        {
            throw "Unable to find logic for $PacketType"
        }
    }

    [object]ParsePacket([HL2DM_Demo_Parser.BitStream]$stream, [GameState]$State)
    {
        $result = $null
        $startTime = get-date
       if($this.PacketTypeLogic.GetType().Name -ne "String"){
        $Reader = [CustomPacketReader]::New($stream)
        $result = $Reader.ReadProperties($this.PacketTypeLogic.Properties)
        #return $result
       }
       else {
        switch($this.PacketTypeLogic)
        {
            'StringTablePacketReader'       {$result = [StringTablePacketReader]::New($stream).Table;break}
            'setConVarPacketReader'         {$result = [SetConVarPacketReader]::New($Stream);break}
            'UserMsgParser'                 {$result = [UserMsgParser]::New($Stream).ParsePacket();break}
            'PacketEntityParser'            {$result = [PacketEntitiesParser]::New($Stream).ParsePacket($State, $True);break}
            'GameEventParser'               {$result = [GameEventParser]::New($Stream).ParsePacket($State);break}
            'ClassInfoParser'               {$result = [ClassInfoParser]::New($Stream);break}
            'bspDecalPacketReader'          {$result = [bspDecalPacketReader]::New($stream).ParsePacket();break}
            'soundPacketPacketReader'       {$result = [soundPacketPacketReader]::New($stream).ParsePacket();break}
            'voiceInitPacketParser'         {$result = [VoiceInitPacketParser]::New($stream).ParsePacket();break}
            'voiceDataPacketParser'         {$result = [VoiceDataPacketParser]::New($stream).ParsePacket();break}
            'GameEventListPacketParser'     {$result = [GameEventListPacketParser]::New($stream).ParsePacket();break}
            'TempEntityPacketParser'        {$result = [TempEntityPacketParser]::New($stream).ParsePacket();break}
            'UpdateStringTablePacketParser' {$result = [UpdateStringTablePacketParser]::New($stream, $State).ParsePacket();break}
            default{$result = $null}
        }
        #return $result
       }
       $endtime = get-date
       $delta = $endtime - $starttime
    
       if($state.messagems.ContainsKey($this.PacketType.ToString()))
       {
           $state.messagems[$this.PacketType.ToString()] += $delta.TotalMilliseconds
       }
       else {
           $state.messagems.add($this.PacketType.ToString(), $delta.TotalMilliseconds)
       }
       #Write-Host ($this.PacketType.ToString() + " took " + $delta.TotalMilliseconds)
       return $result
    }




}

class StringTable
{
    $Name
    [Object[]]$entries
    $maxEntires
    $fixedUserDataSize
    $fixedUserDataSizeBits
    [Object[]]$clientEntries
    [bool]$Compressed

}

class StringTableEntry
{
    [string]$text
    [HL2DM_Demo_Parser.BitStream]$extradata
}

class StringTableParser{
    
    [HL2DM_Demo_Parser.BitStream]$Stream
    [StringTable]$Table
    [int]$EntryCount
    [System.Collections.ArrayList]$ExistingEntries

    StringTableParser([HL2DM_Demo_Parser.BitStream]$Stream, [StringTable]$Table, [int]$entryCount)
    {
        $this.Stream = $Stream
        $this.Table = $table
        $this.EntryCount = $entryCount
    }

    StringTableParser([HL2DM_Demo_Parser.BitStream]$Stream, [StringTable]$Table, [int]$entryCount, [StringTableEntry[]]$ExistingEntries)
    {
        $this.Stream = $Stream
        $this.Table = $table
        $this.EntryCount = $entryCount
        $this.ExistingEntries = $ExistingEntries
    }

    [StringTableEntry[]]ParseEntries()
    {
        $entryBits = [Math]::Log($this.table.maxEntires) / [Math]::Log(2)
        $lastentry = -1
        $Entries = [System.Collections.ArrayList]::new()
        $history = [System.Collections.ArrayList]::new()

        if($this.ExistingEntries.count -ne 0)
        {
            $Entries = $this.ExistingEntries
        }
        for($i = 0; $i -lt $this.entryCount; $i++)
        {
            if (-not $this.stream.readBoolean()) {
                $entryIndex = $this.stream.readBits($entryBits, $false)
            } else {
                $entryIndex = $lastEntry + 1
            }
            $lastentry = $entryIndex

            if($entryIndex -lt 0 -or $entryIndex -gt $this.Table.maxEntires)
            {
                throw "Invalid string index for string table"
            }

            $value = ""

            if($this.Stream.readBoolean())
            {
                $subStringCheck = $this.Stream.readBoolean()

                if($subStringCheck)
                {
                    $index = $this.Stream.readbits(5, $False)
                    $bytesToCopy = $this.Stream.readbits(5, $false)

                    $restOfString = $this.Stream.readASCIIString($Null)

                    if(-not $history[$index].text)
                    {
                        $value = $restOfString
                    }
                    else {
                        try{
                            $value = $history[$index].text.substring(0, $bytesToCopy) + $restOfString
                        }
                        catch{

                        }
                    }
                }
                else {
                    $value = $this.Stream.readASCIIString($null)
                }
            }

            [HL2DM_Demo_Parser.BitStream]$userData = $null
            if($this.Stream.readBoolean())
            {
                if($this.Table.fixedUserDataSize -and $this.Table.fixedUserDataSizeBits)
                {
                    $userdata = $this.Stream.readBitStream($this.Table.fixedUserDataSizeBits)
                }
                else {
                    $userDataBytes = $this.stream.readbits(14, $false)
                    $userData = $this.Stream.readBitStream($userDataBytes * 8)
                }
            }

            if($entryIndex -lt $this.ExistingEntries.Count)
            {
                try {
                    [StringTableEntry]$existingEntry = $this.ExistingEntries[$entryIndex]
                    if($userData)
                    {
                        $existingEntry.extradata = $userData
                    }

                    if($value.GetType().Name -eq "undefined")
                    {
                        $existingEntry.text = $value
                    }
                    
                
                    $Entries[$entryIndex] = $existingEntry
                    $history.add($existingEntry)
             }
             catch {
                throw $_
             }
            }
            else {
                try{
                $newEntry = [StringTableEntry]::New()
                $newEntry.text = $value
                $newEntry.extradata = $userData
                $Entries.add($newEntry)
                $history.add($Entries[$entryIndex])
                }
                catch
                {
                    throw $_
                }
            }
        }
        return $Entries
    }
}

class PlayerDeathEvent {
    [string] $attacker
    [string] $victim
    [string] $weapon
    [bool]  $headshot
    [int]$tick
    [int]$gototick

    PlayerDeathEvent($attacker, $victim, $weapon, $headshot, $tick)
    {
        $this.attacker = $attacker
        $this.victim = $victim
        $this.weapon = $weapon
        $this.headshot = $headshot
        $this.tick = $tick
        $this.gototick = $tick - 300
    }
}

class RoundStartEvent {
    [string] $name = 'round_start'
    [hashtable] $values

    RoundStartEvent() {
        $this.values = @{
            timelimit  = 0
            fraglimit  = 0
            objective  = ''
        }
    }
}

class MmLobbyMemberJoinEvent {
    [string] $name = 'mm_lobby_member_join'
    [hashtable] $values

    MmLobbyMemberJoinEvent() {
        $this.values = @{
            steamid = ''
        }
    }
}

class GameEventPacket
{
    [GameEventTypes]$GameEventType
    [HashTable]$Values

    GameEventPacket($GameEventType, $Values)
    {
        $this.GameEventType = $GameEventType
        $this.Values = $Values
    }
}

class GameEventParser {
    [HL2DM_Demo_Parser.BitStream]$Stream

    GameEventParser([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.Stream = $Stream
    }

    [Object]ParsePacket([GameState]$State)
    {
        $length = $this.Stream.readbits(11, $false)
        $eventData = $this.stream.readBitStream($length)
        $eventType = $eventData.ReadBits(9, $false)
        $definition = $state.eventdefinitions[$eventType]
        $packetvalues = $this.ParseGameEvent($definition, $eventData)


        return [GameEventPacket]::New([GameEventTypes]$eventType, $packetValues)
    }

    [Object]ParseGameEvent($definition, $EventStream)
    {
        $values = @{}
        foreach($entry in ($definition | Where-Object {$_.GetType().FullName -eq "GameEventEntry[]"}))
        {
            $value = $this.getGameEventValue($entry, $eventstream)
            if($null -ne $value)
            {
                $values.add($entry.Name, $value)
            }
        }

        return $values
    }

    [Object]getGameEventValue($Entry, $EventStream)
    {
        switch($Entry.Type)
        {
            'STRING'    {return $EventStream.readUTF8String($null)}
            'FLOAT'     {return $EventStream.Readfloat32()}
            'LONG'      {return $EventStream.ReadUInt32()}
            'SHORT'     {return $EventStream.ReaduInt16()}
            'BYTE'      {return $EventStream.ReadUInt8()}
            'Boolean'   {return $EventStream.ReadBoolean()}
            'Local'     {return $null}
            default     {return $null}
        }
        return $null
    }

}

class UserMsgParser
{
    $UserMsgParsers = @{
        [UserMessageType]::SayText2 = "SayText2Parser"
        [UserMessageType]::TextMsg = '{
            "Properties" :[
                {
                    "Name": "destType",
                    "Type": "8"
                },
                {
                    "Name": "text",
                    "Type": "s"
                },
                {
                    "Name": "substitute2",
                    "Type": "s"
                },
                {
                    "Name": "substitute3",
                    "Type": "s"
                },
                {
                    "Name": "substitute4",
                    "Type": "s"
                }
            ]
        }' | ConvertFrom-Json
        [UserMessageType]::ResetHUD = '{
            "Properties" :[
                {
                    "Name": "data",
                    "Type": "8"
                }
            ]
        }' | ConvertFrom-Json
        [UserMessageType]::Train = '{
            "Properties" :[
                {
                    "Name": "data",
                    "Type": "8"
                }
            ]
        }' | ConvertFrom-Json
        [UserMessageType]::VoiceSubtitle = '{
            "Properties" :[
                {
                    "Name": "client",
                    "Type": "8"
                },
                {
                    "Name": "menu",
                    "Type": "8"
                },
                {
                    "Name": "item",
                    "Type": "8"
                }
            ]
        }' | ConvertFrom-Json
    }
    [HL2DM_Demo_Parser.BitStream]$messageData

    [HL2DM_Demo_Parser.BitStream]$Stream
    $PacketTypeLogic
    UserMsgParser($stream)
    {
        $this.Stream = $stream
        $type = $stream.readUint8()
        $this.PacketTypeLogic = $this.UserMsgParsers[[UserMessageType]$type]
        $length = $this.stream.ReadBits(11, $false)
        $this.messageData = $this.stream.readBitStream($length)

    }

    [object]ParsePacket()
    {
        try{
        $result = $null
        if($this.PacketTypeLogic.GetType().Name -ne "String"){
        $Reader = [CustomPacketReader]::New($this.messageData)
        $result = $Reader.ReadProperties($this.PacketTypeLogic.Properties)
        return $result
       }
       else {
        switch($this.PacketTypeLogic)
        {
            'SayText2Parser' {$SayText2 = [SayText2Parser]::New($this.messageData); $result = $Saytext2.parse()}
            default{$result = $null}
        }
        return $result
       }
    }
    catch{
        return $Null
    }
    }
}

class PacketEntityPacket
{
    $maxEntries
    $isDelta
    $delta
    $Baseline
    $updatedEntries
    $length
    $updatedBaseLIne
    $start
    $end

    $receivedEntities
    $removedEntitiyIds
}

# Assuming necessary types like ServerClass, PVS, SendProp, and SendPropDefinition are defined elsewhere
class PacketEntity {
    [ServerClass]$serverClass
    [int]$entityIndex
    [SendProp[]]$props
    [bool]$inPVS
    [PVS]$pvs
    [int]$serialNumber
    [int]$delay

    PacketEntity([ServerClass]$serverClass, [int]$entityIndex, [PVS]$pvs) {
        $this.serverClass = $serverClass
        $this.entityIndex = $entityIndex
        $this.props = @()
        $this.inPVS = $false
        $this.pvs = $pvs
    }

    static [SendProp]getPropByFullName([SendProp[]]$props, [string]$fullName) {
        foreach ($prop in $props) {
            if ($prop.definition.fullName -eq $fullName) {
                return $prop
            }
        }
        return $null
    }

    [SendProp]getPropByDefinition([SendPropDefinition]$definition) {
        return [PacketEntity]::getPropByFullName($this.props, $definition.fullName)
    }

    [SendProp]getProperty([string]$originTable, [string]$name) {
        $fullName = "$originTable.$name"
        $prop = [PacketEntity]::getPropByFullName($this.props, $fullName)
        if ($prop) {
            return $prop
        }
        throw [System.Exception]::new("Property not found in entity ($fullName)")
    }

    [bool]hasProperty([string]$originTable, [string]$name) {
        return [PacketEntity]::getPropByFullName($this.props, "$originTable.$name") -ne $null
    }

    [PacketEntity]clone() {
        $result = [PacketEntity]::new($this.serverClass, $this.entityIndex, $this.pvs)
        foreach ($prop in $this.props) {
            $result.props += $prop.clone()
        }
        if ($this.serialNumber) {
            $result.serialNumber = $this.serialNumber
        }
        if ($this.delay -ne $null) {
            $result.delay = $this.delay
        }
        $result.inPVS = $this.inPVS
        return $result
    }

    [void]applyPropUpdate([SendProp[]]$props) {
        foreach ($prop in $props) {
            $existingProp = $this.getPropByDefinition($prop.definition)
            if ($existingProp) {
                $existingProp.value = $prop.value
            } else {
                $this.props += $prop.clone()
            }
        }
    }

    [SendProp[]]diffFromBaseLine([SendProp[]]$baselineProps) {
        return $this.props | Where-Object {
            $baseProp = [PacketEntity]::getPropByFullName($baselineProps, $_.definition.fullName)
            -not $baseProp -or -not [SendProp]::areEqual($_, $baseProp)
        }
    }

    [SendPropValue]getPropValue([string]$fullName) {
        $prop = [PacketEntity]::getPropByFullName($this.props, $fullName)
        return if ($prop) { $prop.value } else { $null }
    }
}


class SendProp {
    [SendPropDefinition]$definition
    [Object]$value

    SendProp([SendPropDefinition]$definition) {
        $this.definition = $definition
        $this.value = $null
    }

    [SendProp]clone() {
        $prop = [SendProp]::new($this.definition)
        $prop.value = $this.value
        return $prop
    }

    static [bool]areEqual([SendProp]$a, [SendProp]$b) {
        if ($a.definition.fullName -ne $b.definition.fullName) {
            return $false
        }
        return [SendProp]::valuesAreEqual($a.value, $b.value)
    }

    static [bool]valuesAreEqual([Object]$a, [Object]$b) {
        if (($a -is [Array]) -and ($b -is [Array])) {
            if ($a.Length -ne $b.Length) {
                return $false
            }
            for ($i = 0; $i -lt $a.Length; $i++) {
                if (-not [SendProp]::valuesAreEqual($a[$i], $b[$i])) {
                    return $false
                }
            }
            return $true
        } elseif ($a -is [Vector] -and $b -is [Vector]) {
            return [Vector]::areEqual($a, $b)
        } else {
            return $a -eq $b
        }
    }
}

# Placeholder for SendPropArrayValue types
class SendPropArrayValue {
    [Object]$value

    SendPropArrayValue([Object]$value) {
        if (-not ($value -is [Vector] -or $value -is [int] -or $value -is [string])) {
            throw [System.ArgumentException]::new("Invalid type for SendPropArrayValue")
        }
        $this.value = $value
    }
}

# Placeholder for SendPropValue types
class SendPropValue {
    [Object]$value

    SendPropValue([Object]$value) {
        if (-not ($value -is [Vector] -or $value -is [int] -or $value -is [string] -or $value -is [SendPropArrayValue[]])) {
            throw [System.ArgumentException]::new("Invalid type for SendPropValue")
        }
        $this.value = $value
    }
}


class SendPropDefinition
{
    [SendPropType]$type
    [string]$Name
    [int]$flags
    [string]$excludeDTName
    [int]$lowvalue
    [int]$highvalue
    [int]$bitCount
    [int]$originalBitCount
    [int]$numElements
    [SendTable]$table
    [SendPropDefinition]$arrayProperty
    [string]$OwnerTableName


    static [string[]]formatFlags([int]$flags) {
        $names = @()
        # Iterate through the SendPropFlag enum
        foreach ($name in [Enum]::GetNames([SendPropFlag])) {
            $flagValue = [Enum]::Parse([SendPropFlag], $name)

            if ([int]$flagValue -band $flags) {
                $names += $name
            }
        }
        return $names
    }

    SendPropDefinition([SendPropType]$type, [string]$name, [int]$flags,
        [string]$OwnerTableName)
    {
        $this.type = $type
        $this.Name = $name
        $this.Flags = $flags
        $this.excludeDTName = $null
        $this.lowvalue = 0
        $this.highvalue = 0
        $this.table = $null
        $this.numElements = 0
        $this.arrayProperty = $null
        $this.OwnerTableName = $OwnerTableName
    }

    [bool]hasFlag([SendPropFlag]$flag)
    {
        return ($this.flags -band $flag) -ne 0
    }

    [bool]isExcludeProp()
    {
        return $this.hasFlag([SendPropFlag]::SPROP_EXCLUDE)
    }

    [Object]inspect()
    {
        $data = @{
            "OwnerTableName" = $this.OwnerTableName
            "Name" = $this.Name
            "Type" = [SendPropType]$this.type
            "flags" = $this.flags
            "bitcount" = $this.bitCount
        }
        if ($this.type -eq [SendPropType]::DPT_Float)
        {
            $data.Add("lowValue", $this.lowvalue)
            $data.add("highvalue", $this.highvalue)
        }
        if ($this.type -eq [SendPropType]::DPT_DataTable -and $this.table)
        {
            $data.add("excludedDTName", $this.table.name)
        }

        return $data
    }

    [string]fullName()
    {
        return ($this.OwnerTableName + "." + $this.Name)
    }

    [string[]] allFlags()
    {
        return [SendPropDefinition]::formatFlags($this.flags)
    }

}

class SendTable {
    [string]$name
    [System.Collections.Generic.List[SendPropDefinition]]$props
    [bool]$needsDecoder
    [System.Collections.Generic.List[SendPropDefinition]]$cachedFlattenedProps

    SendTable([string]$name) {
        $this.name = $name
        $this.props = [System.Collections.Generic.List[SendPropDefinition]]::new()
        $this.cachedFlattenedProps = [System.Collections.Generic.List[SendPropDefinition]]::new()
    }

    [void]addProp([SendPropDefinition]$prop) {
        $this.props.Add($prop)
    }

    [void]getAllProps([SendPropDefinition[]]$excludes, [ref]$props) {
        $localProps = @()
        $this.getAllPropsIteratorProps($excludes, [ref]$localProps, [ref]$props)
        foreach ($localProp in $localProps) {
            $props.Value.Add($localProp)
        }
    }

    [void]getAllPropsIteratorProps([SendPropDefinition[]]$excludes, [ref]$props, [ref]$childProps) {
        foreach ($prop in $this.props) {
            if ($prop.hasFlag([SendPropFlag]::SROP_EXCLUDE)) {
                continue
            }
            if ($excludes.Where({$_.name -eq $prop.name -and $_.excludeDTName -eq $prop.ownerTableName}).Count -gt 0) {
                continue
            }

            if ($prop.type -eq [SendPropType]::DPT_DataTable -and $prop.table) {
                if ($prop.hasFlag([SendPropFlag]::SPROP_COLLAPSIBLE)) {
                    $prop.table.getAllPropsIteratorProps($excludes, [ref]$props, [ref]$childProps)
                } else {
                    $prop.table.getAllProps($excludes, [ref]$childProps)
                }
            } else {
                $props.Value.Add($prop)
            }
        }
    }

    [SendPropDefinition[]]get_flattenedProps() {
        if ($this.cachedFlattenedProps.Count -eq 0) {
            $this.flatten()
        }
        return $this.cachedFlattenedProps
    }

    [SendPropDefinition[]]get_excludes() {
        $result = @()
        foreach ($prop in $this.props) {
            if ($prop.hasFlag([SendPropFlag]::SROP_EXCLUDE)) {
                $result += $prop
            } elseif ($prop.type -eq [SendPropType]::DPT_DataTable -and $prop.table) {
                $result += $prop.table.excludes
            }
        }
        return $result
    }

    [void]flatten() {
        $excludes = $this.get_excludes()
        $tprops = @()
        $this.getAllProps($excludes, [ref]$tprops)

        # Sort often changed props before others
        $start = 0
        for ($i = 0; $i -lt $tprops.Count; $i++) {
            if ($tprops[$i].hasFlag([SendPropFlag]::SROP_CHANGES_OFTEN)) {
                if ($i -ne $start) {
                    $temp = $tprops[$i]
                    $tprops[$i] = $tprops[$start]
                    $tprops[$start] = $temp
                }
                $start++
            }
        }
        $this.cachedFlattenedProps = $tprops
    }
}

class ServerClass
{
    [int]$id
    [string]$Name
    [string]$dataTable

    ServerClass($id, $name, $dataTable)
    {
        $this.id = $id
        $this.Name = $name
        $this.datatable = $dataTable
    }
}

class PacketEntitiesPacket
{
    [PacketTypeid]$Type = [PacketTypeId]::packetEntities
    $entities
    $removedEntites
    $maxEntries
    $delta
    $baseLine
    $updatedBaseLine

    PacketEntitiesPacket($entities, $removedEntites, $maxEntries, $delta, $baseLine, $updatedBaseLine)
    {
        $this.entities = $entities
        $this.removedEntites = $removedEntites
        $this.maxEntries = $maxEntries
        $this.delta = $delta
        $this.baseLine = $baseLine
        $this.updatedBaseLine = $updatedBaseLine
    }
}

class PacketEntitiesParser {
    $pvsmap = @{
        0 = [pvs]::PRESERVE
        2 = [pvs]::ENTER
        1 = [pvs]::LEAVE
        3 = [pvs]::Leave + [PVS]::DELETE
    }

    $pvsReverseMap =
    @{
        [PVS]::PRESERVE = 0
        [PVS]::ENTER = 2
        [PVS]::LEAVE = 1
        ([PVS]::LEAVE + [PVS]::DELETE) = 3
    }

    [HL2DM_Demo_Parser.BitStream]$stream

    PacketEntitiesParser([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.stream = $stream
    }

        [PVS]readPVSType([HL2DM_Demo_Parser.BitStream]$stream) {
            $pvs = $stream.readBits(2, $false)
            return $this.pvsmap[$pvs] -as [int]
        }

    
        [PacketEntity]readEnterPVS([HL2DM_Demo_Parser.BitStream]$stream, $entityId, [gamestate]$state, [int]$baseLineIndex) {
            $classBits = $state.getClassBits()
            $serverClass = $state.serverClasses[$stream.readBits($classBits, $false)]
            $serial = $stream.readBits(10, $false) # unused serial number
    
            $sendTable = $state.getSendTable($serverClass.dataTable)
            $instanceBaseline = $state.instanceBaselines[$baseLineIndex] | Where-Object {$_ -eq ($entityId)}
            $entity = [PacketEntity]::new($serverClass, $entityId, [PVS]::ENTER)
            $entity.serialNumber = $serial
            
            if ($instanceBaseline) {
                $entity.props = $instanceBaseline | ForEach-Object { $_.clone() }
                return $entity
            } else {
                $staticBaseLine = $state.staticBaseLines | Where-Object {$_ -eq $serverClass.id}
                if ($staticBaseLine) {
                    $parsedBaseLine = $state.staticBaselineCache.get($serverClass.id)
                    if (-not $parsedBaseLine) {
                        $staticBaseLine.index = 0
                        $parsedBaseLine = getEntityUpdate($sendTable, $staticBaseLine)
                        $state.staticBaselineCache.set($serverClass.id, $parsedBaseLine)
                    }
                    $entity.props = $parsedBaseLine | ForEach-Object { $_.clone() }
                    # $entity.applyPropUpdate($parsedBaseLine)
                    # Handle staticBaseLine bitsLeft condition here if necessary
                }
    
                return $entity
            }
        }
    
        [PacketEntitiesPacket]ParsePacket([gamestate]$state, [bool]$skip = $false) {
            #$maxEntries = $this.stream.readBits(11, $false)
            $this.stream.index += 11
            $isDelta = $this.stream.readBoolean()
            if ($isDelta) { 
                #$this.stream.readInt32()
                $this.stream.index += 32    
            } else { 0 }
            $baseline = 0
            $updatedEntries = $null
            #$baseLine = $this.stream.readBits(1, $false)
            #$updatedEntries = $this.stream.readBits(11, $false)
            $this.stream.index += 12
            $length = $this.stream.readBits(20, $false)
            $updatedBaseLIne = 0
            #$updatedBaseLine = $this.stream.readBoolean()
            $this.stream.index += 1
            $start = $this.stream.index
            $end = $this.stream.index + $length
            $entityId = -1
    
            $receivedEntities = @()
            $removedEntityIds = @()
    
            if (-not $skip) {
                <#
                if ($updatedBaseLine) {
                    $state.instanceBaselines[1 - $baseLine] = New-Object 'System.Collections.Generic.Dictionary[int, SendProp[]]'($state.instanceBaselines[$baseLine])
                    # $state.instanceBaselines[$baseLine] = New-Object 'System.Collections.Generic.Dictionary[int, SendProp[]]' 
                }
    
                for ($i = 0; $i -lt $updatedEntries; $i++) {
                    $diff = $this.stream.readbitvar($false)
                    $entityId += 1 + $diff
    
                    $pvs = $this.readPVSType($this.stream)
                    if ($pvs -eq [PVS]::ENTER) {
                        $packetEntity = $this.readEnterPVS($this.stream, $entityId, $state, $baseLine)
                        $sendTable = $state.getSendTable($packetEntity.serverClass.dataTable)
                        $updatedProps = $state.getEntityUpdate($sendTable, $this.stream)
                        $packetEntity.applyPropUpdate($updatedProps)
    
                        if ($updatedBaseLine) {
                            $state.instanceBaselines[1 - $baseLine].set($entityId, $packetEntity.clone().props)
                        }
                        $packetEntity.inPVS = $true
                        $receivedEntities += $packetEntity
                    } elseif ($pvs -eq [PVS]::PRESERVE) {
                        $packetEntity = getPacketEntityForExisting($entityId, $state, $pvs)
                        $sendTable = $state.sendTables.get($packetEntity.serverClass.dataTable)
                        if (-not $sendTable) {
                            throw [System.Exception]::new("Unknown sendTable $($packetEntity.serverClass.dataTable)")
                        }
                        $updatedProps = getEntityUpdate($sendTable, $this.stream)
                        $packetEntity.applyPropUpdate($updatedProps)
                        $receivedEntities += $packetEntity
                    } elseif ($state.entityClasses.has($entityId)) {
                        $packetEntity = getPacketEntityForExisting($entityId, $state, $pvs)
                        $receivedEntities += $packetEntity
                    }
                }
    
                if ($isDelta) {
                    while ($this.stream.readBoolean()) {
                        $removedEntityIds += $this.stream.readBits(11)
                    }
                }
                #>
            }
    
            $this.stream.index = $end
            return [PacketEntitiesPacket]::New(
                $receivedEntities,
                $removedEntityIds,
                0,
                0,
                0,
                0
            )
            
        }
    }
    

class SayText2Parser
{
    [HL2DM_Demo_Parser.BitStream]$Stream
    SayText2Parser([HL2DM_Demo_Parser.BitStream]$stream)
    {
        $this.Stream = $stream
    }

    [Object]Parse()
    {
        $client = $this.Stream.readUint8()
        $raw = $this.Stream.readUint8()
        $pos = $this.Stream.Index

        $from = ""
        $text = ""
        $kind = ""

        if($this.Stream.readUint8() -eq 1)
        {
            $first = $this.Stream.readuint8()
            if($first -eq 7)
            {
                $color = $this.stream.readUTF8String(6)
            }
            else
            {
                $this.stream.index = $pos + 8
            }
            $text = $this.stream.ReadUTF8String($null)
            if($text.substring(0, 6) -eq "*DEAD*")
            {
                $start = $text.indexof('\u0003')
                $end = $text.indexof('\u0001')
                $from = $text.substring($start + 1, $end - $Start - 1)
                $text = $text.substring($end + 5)
                $kind = 'DeadChat'
            }
        }
        else
        {
            $this.stream.index = $pos
            $kind = $this.stream.readUTF8String($null)
            $from = $this.Stream.readUTF8String($Null)
            $text = $this.Stream.ReadUTF8String($null)
            $this.stream.readUInt16()
        }

        $text = $text -replace [char]3, ''
        $text = $text -replace [char]1, ''
        $stringPos = $text.IndexOf('\u0007')


        return [PSCustomObject]$Msg = @{
            "Client" = $client
            "raw" = $raw
            "kind" = $kind
            "from" = $from
            "text" = $text  
        }
    }
}

class CustomPacketReader
{
    [HL2DM_Demo_Parser.BitStream]$Stream

    CustomPacketReader([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.Stream = $Stream
    }

    [Object]ReadProperties($Properties)
    {
        $Result = @{}
        try {
            foreach ($key in $properties) {
                $value = $this.ReadItem($this.stream, $key.Name, $key.Type, $result)
                if ($key -ne '_') {
                    $result.add($key.Name, $value)
                }
            }
        } catch {
            throw "Failed reading pattern"
        }
        return $Result
    }

    [Object] ReadItem([HL2DM_Demo_Parser.BitStream]$stream, [string]$Name, [string]$description, [Object]$data) {
        switch ($description[0]) {
            'b' { return $stream.readBoolean() }
            's' {
                if ($description.Length -eq 1) {
                    return $stream.readUTF8String($null)
                } else {
                    $length = [int]($description.Substring(1))
                    return $stream.readASCIIString($length)
                }
            }
            'f' { return $stream.readFloat32() }
            'u' {
                $length = [int][string]::Parse($description.Substring(1))
                return $stream.readBits($length, $false)
            }
            '$' {
                if ($description.EndsWith('*8')) {
                    $variable = $description.Substring(1, $description.Length - 3)
                    return $stream.readBitStream($data[$variable] * 8)
                } else {
                    $variable = $description.Substring(1)
                    return $stream.readBitStream($data[$variable])
                }
            }
            default {
                return $stream.readBits([int]$description, $true)
            }
        }
        return 0
    }

}

class StringTablePacketReader
{
    [string]$TableName
    [UInt16]$maxEntries
    [int]$EncodedBits
    [int]$entitycount
    [int]$bitcount
    [int]$userDataSize
    [int]$userDataSizeBits
    [bool]$userDataFixedSize
    [bool]$isCompressed
    [StringTable]$Table
    
    StringTablePacketReader([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.TableName = $stream.readASCIIString($null)
        $this.maxEntries = $stream.readUint16()
        $this.EncodedBits = [math]::log($this.maxEntries) / [math]::log(2)
        $this.entitycount = $stream.readbits($this.EncodedBits + 1, $false)
        
        $this.bitcount = $stream.readVarInt($False)

        $this.userDataFixedSize = $stream.readBoolean()
        if($this.userDataFixedSize)
        {
            $this.userDataSize = $stream.readbits(12, $false)
            $this.userDataSizeBits = $stream.readbits(4, $false)
        }

        $this.isCompressed = $stream.readBoolean()

        $data = $stream.ReadBitStream($this.bitcount)
        try{
            if($this.isCompressed)
            {
                $decompressedByteSize = $data.readUInt32()
                $compressedByteSize = $data.readUint32()
                $magic = $data.readASCIIString(4)
                $compressedData = $data.readArrayBuffer($compressedByteSize - 4)

                if($magic -ne "SNAP")
                {
                    throw "Unknown comprssed stringtable format"
                }

                $decomp = [SnappyDecompressor]::New($compressedData)
                [Byte[]]$decompressedData = $null
                $decompressedData = $decomp.Uncompress($compressedData, $decompressedByteSize)
                $bv = [HL2DM_Demo_Parser.BitView]::New($decompressedData, 0, $decompressedData.Length)
                $data = [HL2DM_Demo_Parser.BitStream]::New($bv, $null, $null)
                
            }
        }
        catch
        {
            throw $_
        }

        [StringTable]$temptable = [StringTable]::New()
        $temptable.Name = $this.TableName
        $temptable.fixedUserDataSize = $this.userDataSize
        $temptable.fixedUserDataSizeBits = $this.userDataSizeBits
        $temptable.Compressed = $this.isCompressed
        $temptable.maxEntires = $this.maxEntries

        $temptable.entries = [StringTableParser]::New($data, $temptable, $this.entitycount).ParseEntries()
        $this.Table = $temptable
    }


}

Class SetConVarPacketReader
{
    $Variables = @{}

    SetConVarPacketReader([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $count = $stream.readUint8()
        for($i = 0; $i -lt $count; $i++)
        {
            $key = $stream.readUTF8String($null)
            $value = $stream.readUTF8String($null)
            if($this.Variables[$key])
            {
                $this.Variables[$key] = $value
            }
            else
            {
                $this.Variables.Add($key, $value)
            }
        }
    }
}

class bspDecalPacket
{
    [PacketTypeId]$PacketType
    [vector]$Position
    [int]$textureindex
    [int]$modelindex
    [bool]$lowPriority

    bspDecalPacket( [PacketTypeId]$PacketType, [vector]$Position, [int]$textureindex, 
        [int]$modelindex, [bool]$lowPriority)
    {
        $this.PacketType = $PacketType
        $this.Position = $Position
        $this.textureindex = $textureindex
        $this.modelindex = $modelindex
        $this.lowPriority = $lowPriority
    }
}

Class bspDecalPacketReader
{
    [HL2DM_Demo_Parser.BitStream]$Stream

    bspDecalPacketReader([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.Stream = $Stream
    }

    [bspDecalPacket]ParsePacket()
    {
        $modelIndex = 0
        $entIndex = 0
        $position = $this.GetVecCoord()
        $textureIndex = $this.Stream.readbits(9, $false)
        if($this.Stream.readBoolean())
        {
            $entIndex = $this.Stream.readbits(11, $false)
            $modelIndex = $this.Stream.ReadBits(12, $false)
        }
        $lowerpriority = $this.stream.readBoolean()

        return [bspDecalPacket]::New([PacketTypeId]::bspDecal, $position, $textureIndex,
            $modelIndex, $lowerpriority)
    }

    [vector]GetVecCoord()
    {
        $hasX = $this.stream.readBoolean()
        $hasy = $this.Stream.readBoolean()
        $hasz = $this.Stream.readBoolean()

        $xval = if($hasx){[SendPropParser]::ReadBitCoord($this.stream)}else{0}
        $yval = if($hasy){[SendPropParser]::ReadBitCoord($this.stream)}else{0}
        $zval = if($hasz){[SendPropParser]::ReadBitCoord($this.stream)}else{0}

        $Vector = [Vector]::New($xval, $yval, $zval)
        return $Vector
    }
}

class SendPropParser
{
    [object]static ReadBitCoord([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $hasIntVal = $stream.readBoolean()
        $hasFractVal = $stream.readBoolean()

        if($hasIntVal -or $hasFractVal)
        {
            $isNegative = $stream.readBoolean()
            $intval = if($hasIntVal){$stream.readbits(14, $false) + 1}else{0}
            $fractval = if($hasFractVal){$stream.readbits(5, $false)}else{0}
            $value = $intval + $fractval * (1/32)
            if($isNegative)
            {
                $value = $value * -1
            }
            return $value
        }

        return 0
    }
}

class VoiceInitPacket
{
    [PacketTypeId]$PacketType = [PacketTypeId]::voiceInit
    [string]$codec
    [int]$quality
    [int]$extradata

    VoiceInitPacket($codec, $quality, $extradata)
    {
        $this.codec = $codec
        $this.quality = $quality
        $this.extradata = $extradata
    }
}

Class VoiceInitPacketParser
{
    [HL2DM_Demo_Parser.BitStream]$Stream

    VoiceInitPacketParser([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.Stream = $Stream
    }

    [VoiceInitPacket]ParsePacket()
    {
        $codec = $this.Stream.readASCIIString($null)
        $quality = $this.Stream.readUint8()
        if($quality -eq 255)
        {
            $extradata = $this.Stream.readuint16()
        }
        elseif($codec -eq 'vaudio_celt')
        {
            $extradata = 11025
        }
        else
        {
            $extradata = 0
        }
        
        return [VoiceInitPacket]::New($codec, $quality, $extradata)
    }
}

Class VoiceDataPacket
{
    [PacketTypeId]$PacketType = [PacketTypeId]::voiceData
    [Byte]$client
    [Byte]$proximity
    [Uint16]$length
    [HL2DM_Demo_Parser.BitStream]$Data

    VoiceDataPacket($client, $proximity, $length, $data)
    {
        $this.client = $client
        $this.proximity = $proximity
        $this.length = $length
        $this.data = $data
    }
}

Class VoiceDataPacketParser
{
    [HL2DM_Demo_Parser.BitStream]$Stream

    VoiceDataPacketParser($Stream)
    {
        $this.stream = $stream
    }

    [VoiceDataPacket]ParsePacket()
    {
        $client = $this.Stream.readuint8()
        $proximity = $this.Stream.readUint8()
        $length = $this.stream.readuint16()
        $data = $this.Stream.readBitStream($length)
        return [VoiceDataPacket]::New($client, $proximity, $length, $data)
    }
}

class GameEventEntry
{
    [string]$Name
    [GameEventValueType]$Type
}

class GameEventListPacket
{
    [PacketTypeId]$PacketType = [PacketTypeId]::gameEventList
    [int]$numEvents
    [int]$length
    [HL2DM_Demo_Parser.BitStream]$listdata
    $eventlist = @{}
    
    GameEventListPacket($numEvents, $length, $listdata)
    {
        $this.numEvents = $numEvents
        $this.length = $length
        $this.listdata = $listdata
    }

}

Class GameEventListPacketParser
{
    [HL2DM_Demo_Parser.BitStream]$Stream

    GameEventListPacketParser([HL2DM_Demo_Parser.BitStream]$STream)
    {
        $this.stream = $stream
    }

    [GameEventListPacket]ParsePacket()
    {

        $numEvents = $this.stream.ReadBits(9, $false)
        $length = $this.stream.readbits(20, $false)
        $listData = $this.Stream.readBitStream($length)

        $GameEventListPacket = [GameEventListPacket]::New($numEvents, $length, $listdata)

        for($i = 0; $i -lt $numEvents; $i++)
        {
            $id = $listdata.readbits(9, $false)
            $name = $listdata.readASCIIString($null)
            $type = $listdata.readbits(3, $false)
            [GameEventEntry[]]$entries = @()
            while($type -ne 0)
            {
                $entry = [GameEventEntry]::New()
                $entry.Type = [GameEventValueType]$Type
                $entry.Name = $listdata.readASCIIString($null)
                $entries += $entry
                $type = $listdata.readbits(3, $false)
            }
            $GameEventListPacket.eventList.add($id, @($id, $name, $entries))
        }
        
        return $GameEventListPacket
    }
}

class Message
{
    [int]$TickNumber
    [int]$length
    [Vector[]]$viewOrigin
    [Vector[]]$viewAngles
    [Vector[]]$localViewAngles
    [int]$SequenceIn
    [int]$SequenceOut
    [Object[]]$Packets
    [int]$flags
}

class DataTableMessage {
    [int]$Type
    [int]$Tick
    [HL2DM_Demo_Parser.BitStream]$RawData
    [System.Collections.ArrayList]$Tables
    [System.Collections.ArrayList]$ServerClasses

    DataTableMessage([int]$type, [int]$tick, [HL2DM_Demo_Parser.BitStream]$rawData, [System.Collections.ArrayList]$tables, [System.Collections.ArrayList]$serverClasses) {
        $this.Type = $type
        $this.Tick = $tick
        $this.RawData = $rawData
        $this.Tables = $tables
        $this.ServerClasses = $serverClasses
    }
}


class DataTableMessageHandler {
    ParseMessage([HL2DM_Demo_Parser.BitStream]$stream) {
        $tick = $stream.ReadInt32()
        $length = $stream.ReadInt32()
        $messageStream = $stream.ReadBitStream($length * 8)
        <#
        # Initialize tables and table map
        $tables = [System.Collections.ArrayList]::New()
        $tableMap = @{}

        # Read tables from the message stream
        while ($messageStream.ReadBoolean()) {
            $needsDecoder = $messageStream.ReadBoolean()
            $tableName = $messageStream.ReadASCIIString($null)
            $numProps = $messageStream.ReadBits(10, $false)
            $table = [SendTable]::new($tableName)
            $table.needsDecoder = $needsDecoder

            # Get props metadata
            $arrayElementProp = $null
            for ($i = 0; $i -lt $numProps; $i++) {
                $propType = $messageStream.ReadBits(5, $false)
                $propName = $messageStream.ReadASCIIString($null)
                $nFlagsBits = 16
                $flags = $messageStream.ReadBits($nFlagsBits,$false)
                $prop = [SendPropDefinition]::new($propType, $propName, $flags, $tableName)

                if ($propType -eq [SendPropType]::DPT_DataTable) {
                    $prop.excludeDTName = $messageStream.ReadASCIIString($null)
                } else {
                    if ($prop.IsExcludeProp()) {
                        $prop.excludeDTName = $messageStream.ReadASCIIString($null)
                    } elseif ($prop.type -eq [SendPropType]::DPT_Array) {
                        $prop.numElements = $messageStream.ReadBits(10, $false)
                    } else {
                        try{
                            $prop.lowValue = $messageStream.ReadFloat32()
                            $prop.highValue = $messageStream.ReadFloat32()                    
                        }
                        catch
                        {
                            #throw $_
                        }
                        $prop.bitCount = $messageStream.ReadBits(7, $false)
                    }
                }

                if ($prop.HasFlag([SendPropFlag]::SPROP_NOSCALE)) {
                    if ($prop.type -eq [SendPropType]::DPT_Float) {
                        $prop.originalBitCount = $prop.bitCount
                        $prop.bitCount = 32
                    } elseif ($prop.type -eq [SendPropType]::DPT_Vector) {
                        if (-not $prop.HasFlag([SendPropFlag]::SPROP_NORMAL)) {
                            $prop.originalBitCount = $prop.bitCount
                            $prop.bitCount = 32 * 3
                        }
                    }
                }

                if ($arrayElementProp) {
                    if ($prop.type -ne [SendPropType]::DPT_Array) {
                        throw "expected prop of type array"
                    }
                    $prop.arrayProperty = $arrayElementProp
                    $arrayElementProp = $null
                }

                if ($prop.HasFlag([SendPropFlag]::SPROP_INSIDEARRAY)) {
                    if ($arrayElementProp) {
                        throw "array element already set"
                    }
                    if ($prop.HasFlag([SendPropFlag]::SPROP_CHANGES_OFTEN)) {
                        throw "unexpected CHANGES_OFTEN prop in array"
                    }
                    $arrayElementProp = $prop
                } else {
                    $table.AddProp($prop)
                }
            }
            $tables.add($table)
            $tableMap[$table.name] = $table
        }

        # Link referenced tables
        foreach ($table in $tables) {
            foreach ($prop in $table.props) {
                if ($prop.type -eq [SendPropType]::DPT_DataTable) {
                    if ($prop.excludeDTName) {
                        $referencedTable = $tableMap[$prop.excludeDTName]
                        if (-not $referencedTable) {
                            throw "Unknown referenced table $($prop.excludeDTName)"
                        }
                        $prop.table = $referencedTable
                        $prop.excludeDTName = $null
                    }
                }
            }
        }

        # Read server classes
        $numServerClasses = $messageStream.ReadUint16()
        $serverClasses = [System.Collections.ArrayList]::New()
        if ($numServerClasses -le 0) {
            throw "expected one or more serverclasses"
        }

        for ($i = 0; $i -lt $numServerClasses; $i++) {
            $classId = $messageStream.ReadUint16()
            if ($classId -gt $numServerClasses) {
                throw "invalid class id"
            }
            $className = $messageStream.ReadASCIIString($null)
            $dataTable = $messageStream.ReadASCIIString($null)
            $serverClasses.add([ServerClass]::new($classId, $className, $dataTable))
        }

        if ($messageStream.bitsLeft -gt 7) {
            throw "unexpected remaining data in datatable ($($messageStream.bitsLeft) bits)"
        }

        return [DataTableMessage]::new([MessageType]::DataTables, $tick, $messageStream, $tables, $serverClasses)
    #>
    }
}

class GameState
{
    $version = 0
    $staticBaseLines = @{}
    $staticbaselineCache = @{}
    $eventdefinitions = @{}
    $entityClasses = @{}
    $modelPrecache = @{}
    $sendTables = @{}
    $stringTables = @()
    $serverClasses = @()
    $instanceBaselines = @(@{}, @{})
    $skippedPackets = @()
    $userInfo = @()
    $chat = @()
    $tick = 0
    $game
    $events = @()
    $deaths = @()
    $startTick = 0
    $messagems = @{}
    $messagepostms = @{}
    $packetms = @{}
    $packetPreMS = 0

    HandleTable([StringTable]$Table)
    {
        if(-not $this.GetStringTable($Table.Name)){
            $this.stringTables += $Table
        }

        $this.HandleStringTableEntires($table.name)
    }

    HandleStringTableEntires($TableName)
    {
        $table = $this.stringTables | Where-Object {$_.Name -eq $TableName}
        switch($TableName)
        {
            'userinfo'
            {
                foreach($entry in $table.entries)
                {
                    if($entry -and $entry.extraData)
                    {
                        $this.CalculateUserInfoFromEntry($entry.text, $entry.extraData)
                    }
                }
            }

        }
    }

    HandleGameEvent([GameEventPacket]$GameEventPacket)
    {
        $this.events += $GameEventPacket
        if($GameEventPacket.GameEventType -eq [GameEventTypes]::player_death)
        {
            $attackerid = $GameEventPacket.Values['attacker']
            while($attackerid -gt 256)
            {
                $attackerid -= 256
            }
            $attacker = $this.userInfo | Where-Object {$_.UserId -eq $attackerid}
            $victimid = $GameEventPacket.Values['userid']
            while($victimid -gt 256)
            {
                $victimid -= 256
            }
            $victim = $this.userInfo | Where-Object {$_.UserId -eq $victimid}
            $weapon = $GameEventPacket.Values['Weapon']

            if($GameEventPacket.Values.ContainsKey('headshot'))
            {
                $headshot = $GameEventPacket.values['headshot']
            }
            else
            {
                $headshot = $false
            }


            $this.Deaths += [PlayerDeathEvent]::New($attacker['Name'], $victim['Name'], $weapon, $headshot, ($this.tick - $this.startTick))
        }
    }

    HandleUserMsg($UserMsgPacket)
    {
        if($null -ne $userMsgPacket)
        {
            $this.chat += @{"Text" = $UserMsgPacket.text; "Tick" = $this.tick}
        }
    }

    HandleDataTableMessage($message)
    {
        foreach($table in $message.tables)
        {
            $this.sendTables[$table.name] = $table
        }

        $this.serverClasses = $message.ServerClasses
    }

    [StringTable]GetStringTable($TableName)
    {
        return $this.stringTables | Where-Object {$_.Name -eq $TableName}
    }

    CalculateUserInfoFromEntry($entryName, [HL2DM_Demo_Parser.BitStream]$Extradata)
    {
        if($Extradata.BitsLeft -gt (32 * 8))
        {
            $name = $Extradata.readUTF8String(32)
            $userid = $Extradata.ReadUInt32()
            while($userid -gt 256)
            {
                $userid -= 256
            }
            $steamid = $extradata.readUTF8String($null)
            if($steamid)
            {
                $entityid = [int]::Parse($entryName, 10) + 1
                $user = $this.userInfo | Where-Object {$_.UserId -eq $userid}

                if(-not $User)
                {
                    $user = @{"name" = $name
                             "userId" = $userid
                            "steamdId" = $steamid
                            "entityid" = $entityid}
                    $this.userInfo += $user
                }
                else
                {
                    $user.name = $name
                    $user.steamdId = $steamid
                }
            }
        }
    }

    [int]getClassBits() {
        return [math]::Ceiling([math]::Log($this.serverClasses.Length) * [math]::Log(2))
    }

    [sendtable]getSendTable($DataTable)
    {
        $sendTable = $this.sendTables[$dataTable]
        if (-not $sendTable) {
            throw [System.Exception]::new("Unknown sendTable $dataTable")
        }
        return $sendTable
    }

    HandleGameEventList([GameEventListPacket]$packet)
    {
        $this.eventdefinitions = $packet.eventlist
    }
}

Class UpdateStringTablePacket
{
    [int]$TableID
    [bool]$multipleChanged
    [int]$bitcount
    [HL2DM_Demo_Parser.BitStream]$data
    $updatedEntries

    updateStringTablePacket($tableid, $multipleChanged, $bitcount, $data, $updatedEntries)
    {
        $this.TableID = $tableid
        $this.multipleChanged = $multipleChanged
        $this.bitcount = $bitcount
        $this.data = $data
        $this.updatedEntries = $updatedEntries
    }
}

class UpdateStringTablePacketParser
{
    [HL2DM_Demo_Parser.BitStream]$stream
    [gamestate]$state

    UpdateStringTablePacketParser([HL2DM_Demo_Parser.BitStream]$Stream, [gamestate]$state)
    {
        $this.stream = $Stream
        $this.state = $state
    }

    [UpdateStringTablePacket]ParsePacket()
    {
        $tableid = $this.stream.readbits(5, $false)
        $multipleChanged = $this.stream.readBoolean()
        $changedentries = if($multipleChanged){$this.stream.readUint16()}else{1}
        $bitCount = $this.stream.readbits(20, $false)
        $data = $this.stream.readBitStream($bitcount)
        

        $temptable = $this.state.stringTables[$tableid]
        $updatedEntries = [StringTableParser]::New($data, $temptable, $changedentries, $temptable.entries).ParseEntries()
        return [UpdateStringTablePacket]::New($tableid, $multipleChanged, $bitCount, $data, $updatedEntries)
    }
}

class Parser{

    [HL2DM_Demo_Parser.BitStream]$stream
    [DemoHeader]$Header
    [Object[]]$Messages
    $hanlders = @{}
    [GameState]$State = [GameState]::New()

    Parser([HL2DM_Demo_Parser.BitStream]$Stream)
    {
        $this.stream = $stream
        $this.Header = [DemoHeader]::New($this.stream)
        $this.GetMessages()

    }
    
    GetMessages()
    {
        $process = $true
        while($process -eq $true)
        {
            [MessageType]$PacketType = $this.stream.readUint8()
            $startTime = Get-Date
            #Write-Host "$PacketType"
            switch($PacketType)
            {
                "SigOn" {$this.ProcessPacket();Break}
                "Packet" {$this.ProcessPacket();break}
                "SyncTick"{$this.ProcessSyncTick();break}
                "ConsoleCmd" {$this.ProcessConsoleCmd();break}
                "UserCmd" {$this.ProcessUserCmd();break}
                "DataTables" {$this.State.HandleDataTableMessage($this.ProcessDataTable());break}
                "stop" {$process = $false}
                "StringTables" {$this.ProcessStringTable();break}
                default {}
            }
        $delta = ($(Get-Date) - $starttime)
        if($this.State.packetms.ContainsKey($PacketType.ToString()))
        {
            $this.State.packetms[$PacketType.ToString()] += $delta.TotalMilliseconds
        }
        else {
            $this.State.packetms.Add($PacketType.ToString(), $delta.TotalMilliseconds)
        }
        }
    }

    ProcessSyncTick()
    {
        [Message]$Message = [Message]::New()
        $message.TickNumber = $this.stream.readint32()
        $this.Messages += $Message
    }

    ProcessPacket()
    {
        $startPre = Get-Date
        [Message]$Message = [Message]::New()
        <#
        $Message.TickNumber = $this.stream.ReadInt32()
        $message.flags = $this.stream.readInt32()
        
        $viewOrigin = @([Vector]::New(0,0,0), [Vector]::New(0,0,0))
        $viewAngles = @([Vector]::New(0,0,0), [Vector]::New(0,0,0))
        $localViewAngles = @([Vector]::New(0,0,0), [Vector]::New(0,0,0))

        <#
        for($i = 0; $i -lt 2; $i++)
        {
            $viewOrigin[$i] = [Vector]::New($this.stream.readFloat32(), $this.stream.readFloat32(), $this.stream.readFloat32())
            $viewAngles[$i] = [Vector]::New($this.stream.readFloat32(), $this.stream.readFloat32(), $this.stream.readFloat32())
            $localViewAngles[$i] = [Vector]::New($this.stream.readFloat32(), $this.stream.readFloat32(), $this.stream.readFloat32())
        }
     


        $message.sequencein = $this.stream.readint32()
        $message.SequenceOut = $this.stream.readint32()

        #>
        $this.stream.index += 704
        $message.length = $this.stream.readint32()

        $messageStream = $this.stream.readBitStream($message.length * 8)
        $startEnd = Get-Date
        $startDelta =  $startend - $startPre
        $this.State.packetPreMS += $startDelta.TotalMilliseconds
        while($messageStream.BitsLeft -gt 6)
        {
            try
            {
                [PacketTypeId]$PacketType = $messageStream.ReadBits(6, $false)
                if($packetType -ne 0)
                {
                    #Write-Host "`t$PacketType"
                    $lastType = $PacketTYpe
                    $PacketHandler = [PacketReader]::New($PacketType)
                    if($PacketHandler)
                    {
                        $curPacket = $PacketHandler.ParsePacket($messageStream, $this.State)
                        $startTime = Get-Date
                        switch($PacketType)
                        {
                            'netTick' {if($this.state.starttick -eq 0){$this.state.StartTick = $curPacket.Tick}; $this.State.tick = $curPacket.tick; break}
                            'serverInfo' {$this.State.version = $curPacket.Version; $this.State.game = $curPacket.Game; break}
                            'createStringTable' {$this.State.HandleTable($curPacket); break}
                            'userMessage'   {$this.State.HandleUserMsg($curPacket); break}
                            'gameEventList' {$this.State.HandleGameEventList($curPacket); break}
                            'gameEvent'     {$this.State.HandleGameEvent($curPacket); break}
                        }
                        $endtime = Get-Date
                        $delta = $endtime - $startTime
                    
                        if($this.state.messagepostms.ContainsKey($PacketType.ToString()))
                        {
                            $this.state.messagepostms[$PacketType.ToString()] += $delta.TotalMilliseconds
                        }
                        else {
                            $this.state.messagepostms.add($PacketType.ToString(), $delta.TotalMilliseconds)
                        }
                        #Write-Host ($this.PacketType.ToString() + " took " + $delta.TotalMilliseconds)
                        $Message.Packets += $curPacket
                    }
                }
            }
            catch{
                #throw $_
                break
            }  
        }
        #$this.Messages += $Message
    }

    ProcessConsoleCmd()
    {
        [Message]$Message = [Message]::New()
        $message.TickNumber = $this.stream.readint32()
        $message.length = $this.stream.readInt32()

        $Message.packets = $this.stream.readBitStream($message.length * 8)
        #$this.Messages += $message
    }

    ProcessUserCmd()
    {
        [Message]$Message = [Message]::New()
        $message.TickNumber = $this.stream.readint32()
        $Message.SequenceOut = $this.stream.readInt32()
        $message.length = $this.stream.readInt32()

        $Message.packets = $this.stream.readBitStream($message.length * 8)
        #$this.Messages += $message
    }

    [Datatablemessage]ProcessDataTable()
    {
        return [DataTableMessageHandler]::New().ParseMessage($this.stream)
    }

    ProcessStringTable()
    {
        [Message]$Message = [Message]::New()
        $message.TickNumber = $this.stream.readint32()
        $message.length = $this.stream.readInt32()

        $Message.packets = $this.stream.readBitStream($message.length * 8)
        #$this.Messages += $message
    }
}

class Vector {
    [float]$x
    [float]$y
    [float]$z

    Vector([float]$x, [float]$y, [float]$z) {
        $this.x = $x
        $this.y = $y
        $this.z = $z
    }
}


$demos = gci "C:\Program Files (x86)\steam\steamapps\common\Half-Life 2 Deathmatch\hl2mp\ToParse"
$i = 1
$count = $demos.Count
foreach($demo in $demos)
{
    Write-Progress -Activity 'Processing Demos' -Status "Processing Demos: $I of $count" -PercentComplete ($I / $count * 100)
    $data = [System.IO.File]::ReadAllBytes($demo.FullName)
    $bitView = New-Object HL2DM_Demo_Parser.BitView($data, 0, $data.Length)
    $bitstream = New-Object HL2DM_Demo_Parser.BitStream($bitView)
    $Parser = [parser]::New($bitstream)

    $deaths = $parser.State.deaths
    Write-Output $Demo.Name
    Write-Output "==========================================="
    Write-Output ("RoundStart: " + $parser.State.startTick)
    Write-Output $deaths

    $export = @{RoundStart = $parser.State.startTick; Deaths = $Deaths} 
    $export | Select-Object RoundStart -ExpandProperty Deaths | Export-Csv -Path ("C:\temp\" + $demo.Name + "_deaths.csv")
    [gc]::collect()
    $i++
}

Write-Progress -Activity 'Processing Demos' -Completed