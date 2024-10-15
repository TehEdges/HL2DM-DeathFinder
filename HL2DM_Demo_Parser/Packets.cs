using System;
using System.Diagnostics;

namespace HL2DM_Demo_Parser;

public enum PacketTypeId {
    unknown = 0,
	file = 2,
	netTick = 3,
	stringCmd = 4,
	setConVar = 5,
	sigOnState = 6,
	print = 7,
	serverInfo = 8,
	classInfo = 10,
	setPause = 11,
	createStringTable = 12,
	updateStringTable = 13,
	voiceInit = 14,
	voiceData = 15,
	parseSounds = 17,
	setView = 18,
	fixAngle = 19,
	bspDecal = 21,
	userMessage = 23,
	entityMessage = 24,
	gameEvent = 25,
	packetEntities = 26,
	tempEntities = 27,
	preFetch = 28,
	menu = 29,
	gameEventList = 30,
	getCvarValue = 31,
	cmdKeyValues = 32
}

public abstract class PacketBase
{
    public BitStream MessageData;
    public abstract void Process();

    public PacketBase(BitStream stream)
    {
        this.MessageData = stream;
    }
}

public class serverInfo : PacketBase
{
    public int Version { get; set; }
    public int ServerCount { get; set; }
    public bool Stv { get; set; }
    public bool Dedicated { get; set; }
    public int MaxCrc { get; set; }
    public int MaxClasses { get; set; }
    public int MapHash { get; set; }
    public int PlayerCount { get; set; }
    public int MaxPlayerCount { get; set; }
    public float IntervalPerTick { get; set; }
    public string Platform { get; set; }
    public string Game { get; set; }
    public string Map { get; set; }
    public string Skybox { get; set; }
    public string ServerName { get; set; }
    public bool Replay { get; set; }

    public serverInfo(BitStream stream) : base(stream) // Pass the BitStream to the base constructor
    {
    }
    public override void Process()
    {
        this.Version = this.MessageData.ReadBits(16, true);
        this.ServerCount = this.MessageData.ReadBits(32, true);
        this.Stv = this.MessageData.ReadBoolean();
        this.Dedicated = this.MessageData.ReadBoolean();
        this.MaxCrc = this.MessageData.ReadBits(32, true);
        this.MaxClasses = this.MessageData.ReadBits(16, true);
        this.MapHash = this.MessageData.ReadBits(128, true);
        this.PlayerCount = this.MessageData.ReadBits(8, true);
        this.MaxPlayerCount = this.MessageData.ReadBits(8, true);
        this.IntervalPerTick = this.MessageData.ReadFloat32();
        this.Platform = this.MessageData.ReadASCIIString(1);
        this.Game = this.MessageData.ReadUTF8String(0);
        this.Map = this.MessageData.ReadUTF8String(0);
        this.Skybox = this.MessageData.ReadUTF8String(0);
        this.ServerName = this.MessageData.ReadUTF8String(0);
        this.Replay = this.MessageData.ReadBoolean();
    }
}

public class netTick : PacketBase
{
    public int tick {get;set;}
    public int frametime{get;set;}
    public int stdDev{get;set;}

    public netTick (BitStream stream) : base(stream)
    {

    }
    public override void Process()
    {
        this.tick = this.MessageData.ReadBits(32, true);
        this.frametime = this.MessageData.ReadBits(16, true);
        this.stdDev = this.MessageData.ReadBits(16, true);
    }
}

public class setConVar : PacketBase
{
    public setConVar(BitStream stream)  : base(stream)
    {}
    public List<Property> convars;
    public int count;

    public override void Process()
    {
        this.convars = new();
        this.count = this.MessageData.ReadUint8();
        for(int i =0; i < count; i++)
        {
            string key = this.MessageData.ReadUTF8String(0);
            string value = this.MessageData.ReadUTF8String(0);
            Property tprop = new();
            tprop.Name = key;
            tprop.Value = value;
            this.convars.Add(tprop);
        }
    }
}

public class stringTablePackets : PacketBase
{
    GameState State;
    public string TableName;
    public int maxEntries, encodedbits, entitycount, bitcount, userdatasize, userdatasizebits;
    bool UserDataFixedSize, isCompressed;
    StringTable Table;

    public stringTablePackets(BitStream stream, GameState State) : base(stream)
    {
        this.State = State;
    }

    public override void Process()
    {
        this.TableName = this.MessageData.ReadASCIIString(0);
        this.maxEntries = this.MessageData.ReadUint16();
        this.encodedbits = (int)Math.Log2(this.maxEntries);
        this.entitycount = this.MessageData.ReadBits(this.encodedbits + 1, false);
        this.bitcount = this.MessageData.ReadVarInt(false);
        this.UserDataFixedSize = this.MessageData.ReadBoolean();

        //If our user data is a fixed size, then read the size.
        if(this.UserDataFixedSize)
        {
            this.userdatasize = this.MessageData.ReadBits(12, false);
            this.userdatasizebits = this.MessageData.ReadBits(4, false);
        }
        this.isCompressed = this.MessageData.ReadBoolean();

        BitStream tabledata = this.MessageData.ReadBitStream(this.bitcount);
        if(this.isCompressed)
        {
            int decompbytesize = (int)tabledata.ReadUint32();
            int compbytesize = (int)tabledata.ReadUint32();
            string magic = tabledata.ReadASCIIString(4);
            byte[] compressedData = tabledata.ReadArrayBuffer(compbytesize - 4);

            if(magic != "SNAP")
            {
                throw new SystemException("Unknown compressed stringtable format");
            }

            SnappyDecompressor decompressor = new(compressedData);
            byte [] decompdata = new byte[decompbytesize];
            decompressor.Uncompress(compressedData);
            BitView bv = new(decompdata, 0, decompdata.Length);
            tabledata = new(bv, 0, bv.view.Length);
        }


        StringTable temptable = new(this.TableName, this.maxEntries, this.userdatasize, this.userdatasizebits, this.isCompressed, tabledata);
        temptable.ProcessStringTable(this.entitycount);
    }
}


public class Property
{
    public string Name { get; set; }
    public string Value { get; set; }
}

public class PacketParser
{
    BitStream messageData;

    public PacketParser(BitStream stream)
    {
        this.messageData = stream;
    }


}