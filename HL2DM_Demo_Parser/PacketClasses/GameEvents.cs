using System;
using System.Collections;
using System.ComponentModel.DataAnnotations;
using Microsoft.VisualBasic;

namespace HL2DM_Demo_Parser.PacketClasses;

public enum GameEventTypes
{
    server_cvar = 3,
    round_start = 37,
    player_death = 23,
    mm_lobby_member_join = 72
}
public enum GameEventValueType
{
    STRING = 1,
    FLOAT = 2,
    LONG = 3,
    SHORT = 4,
    BYTE = 5,
    BOOLEAN = 6,
    LOCAL = 7
}

public class GameEventList  :   PacketBase
{
    public int numEvents, length;
    public BitStream listData;
    public GameEventList(BitStream stream, GameState state)  :   base(stream)
    {
        this.State = state;
    }
    public GameState State;
    public override void Process()
    {
        this.numEvents = this.MessageData.ReadBits(9, false);
        this.length = this.MessageData.ReadBits(20, false);
        this.listData = this.MessageData.ReadBitStream(this.length);

        for(int i = 0; i < this.numEvents; i++)
        {
            int id = this.listData.ReadBits(9, false);
            string name = this.listData.ReadASCIIString(0);
            int type = this.listData.ReadBits(3, false);
            List<GameEventEntry> Entries = new();
            while(type != 0)
            {
                GameEventEntry Entry = new();
                Entry.Type = (GameEventValueType)type;
                Entry.Name = this.listData.ReadASCIIString(0);
                Entries.Add(Entry);
                type = this.listData.ReadBits(3, false);
            }
            object[] evententry = new object[] {id, name, Entries};
            this.State.GameEventList.Add(id, evententry);
        }
    }
}

public class GameEventEntry
{
    public string Name;
    public GameEventValueType Type;
}
public class GameEvent  :   PacketBase
{
    public GameEventTypes GameEventType;
    public Dictionary<string, object> Values;
    public GameState state;
    public int length, eventtype;
    public BitStream eventData;
    public GameEvent(BitStream stream, GameState state) : base(stream)
    {
        this.state = state;
        this.Values = new();
    }

    public override void Process()
    {
        this.length = this.MessageData.ReadBits(11, false);
        this.eventData = this.MessageData.ReadBitStream(this.length);
        this.eventtype = this.eventData.ReadBits(9, false);
        if(this.state.GameEventList.TryGetValue(this.eventtype, out object[] evententry))
        {
            foreach(var entry in evententry)
            {
                if(entry is List<GameEventEntry> gameEventEntries)
                {
                    foreach(var gameEventEntry in gameEventEntries)
                    {
                        var value = this.GetGameEventValue(gameEventEntry);
                        if(value is not null)
                        {
                            Values.Add(gameEventEntry.Name, value);
                        }
                    }
                }
            }
        }
    }

    private object GetGameEventValue(GameEventEntry gameEventEntry)
    {
        switch(gameEventEntry.Type)
        {
            case GameEventValueType.STRING:
                return this.eventData.ReadUTF8String(0);
            case GameEventValueType.FLOAT:
                return this.eventData.ReadFloat32();
            case GameEventValueType.LONG:
                return this.eventData.ReadUint32();
            case GameEventValueType.SHORT:
                return this.eventData.ReadUint16();
            case GameEventValueType.BYTE:
                return this.eventData.ReadUint8();
            case GameEventValueType.BOOLEAN:
                return this.eventData.ReadBoolean();
            case GameEventValueType.LOCAL:
                return null;
            default:
                return null;
        }
    }

}
