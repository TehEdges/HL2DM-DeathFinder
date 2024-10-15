using System;

namespace HL2DM_Demo_Parser.PacketClasses;

public class VoiceData  :   PacketBase
{
    public int client, proximity, length;
    public BitStream data;
    public VoiceData(BitStream stream)  :   base(stream)
    {}
    public override void Process()
    {
        this.client = this.MessageData.ReadUint8();
        this.proximity = this.MessageData.ReadUint8();
        this.length = this.MessageData.ReadUint16();
        this.data = this.MessageData.ReadBitStream(this.length);
    }
}
