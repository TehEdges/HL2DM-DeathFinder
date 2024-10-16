using System;

namespace HL2DM_Demo_Parser.PacketClasses;

public class PacketEntities :   PacketBase
{
    public int maxEntries, delta, baseline, updatedentries, length;
    public bool isDelta, updatebaseline;
    public BitStream data;
    public PacketEntities(BitStream stream) : base(stream)
    {}

    public override void Process()
    {
        this.maxEntries = this.MessageData.ReadBits(11, false);
        this.isDelta = this.MessageData.ReadBoolean();
        this.delta = this.isDelta ? this.MessageData.ReadInt32() : 0;
        this.baseline = this.MessageData.ReadBits(1, false);
        this.updatedentries = this.MessageData.ReadBits(11, false);
        this.length = this.MessageData.ReadBits(20, false);
        this.data = this.MessageData.ReadBitStream(length);
        this.updatebaseline = this.MessageData.ReadBoolean();
    }
}
