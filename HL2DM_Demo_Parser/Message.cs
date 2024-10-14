using System;

namespace HL2DM_Demo_Parser;

public class Message
{
    public int TickNumber, Length, SequenceIn, SequenceOut, Flags;
    public BitStream MessageData;
    public Array Packets;
}
