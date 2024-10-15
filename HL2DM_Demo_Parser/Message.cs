using System;

namespace HL2DM_Demo_Parser;

public class Message
{
    public int TickNumber, Length, SequenceIn, SequenceOut, Flags;
    public BitStream MessageData;
    public List<PacketBase> Packets;

    public List<PacketBase> ParsePackets(GameState State)
    {
        List<PacketBase> Packets = new();
        
        while(this.MessageData.BitsLeft > 6)
        {
            //Determine packet type by reading the first 6 bits
            PacketTypeId PacketType = (PacketTypeId)this.MessageData.ReadBits(6, false);
            switch(PacketType)
            {
                case PacketTypeId.serverInfo:
                    serverInfo serverInfoPacket = new(this.MessageData);
                    serverInfoPacket.Process();
                    Packets.Add(serverInfoPacket);
                    break;

                case PacketTypeId.netTick:
                    netTick netTickPacket = new(this.MessageData);
                    netTickPacket.Process();
                    Packets.Add(netTickPacket);
                    break;

                case PacketTypeId.setConVar:
                    setConVar setConVarPacket = new(this.MessageData);
                    setConVarPacket.Process();
                    Packets.Add(setConVarPacket);
                    break;
                
                case PacketTypeId.createStringTable:
                    stringTablePackets stringTablePacket = new(this.MessageData, State);
                    stringTablePacket.Process();
                    Packets.Add(stringTablePacket);
                    break;
            }
        }

        return Packets;
    }
}
