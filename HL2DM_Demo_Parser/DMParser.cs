using System;

namespace HL2DM_Demo_Parser;

public enum MessageTypeID
{
    Sigon = 1,
    Packet = 2,
    SyncTick = 3,
    ConsoleCmd = 4,
    UserCmd = 5,
    DataTables = 6,
    Stop = 7,
    StringTables = 8
}
public class DMParser
{
    public DemoHeader Header;
    public BitStream Stream;
    public GameState State;
    public System.Collections.Generic.List<Message> Messages;
    public DMParser(string filePath)
    {
        byte[] Data = System.IO.File.ReadAllBytes(filePath);
        BitView bv = new BitView(Data, 0, Data.Length);
        this.Stream = new BitStream(bv);

        this.Header = new DemoHeader(this.Stream);
        this.Messages = new List<Message>();
        this.State = new();
        this.State.GameEventList = new();
        this.State.UserMessages = new();
        this.State.stringTables = new();
        this.State.Events = new();

        this.GetMessages();
        this.ProcessMessages();
        
    }
    private void GetMessages()
    {
        while(this.Stream.BitsLeft > 8)
        {
            MessageTypeID MessageType = (MessageTypeID)this.Stream.ReadUint8();
            switch(MessageType)
            {
                case MessageTypeID.Sigon:
                    this.Messages.Add(this.ProcessPacket(MessageType));
                    break;
                    
                case MessageTypeID.Packet:
                     this.Messages.Add(this.ProcessPacket(MessageType));
                    break;

                case MessageTypeID.SyncTick:
                    this.Messages.Add(this.ProcessSyncTick());
                    break;

                case MessageTypeID.ConsoleCmd:
                    this.Messages.Add(this.ProcessConsoleCmd());
                    break; 

                case MessageTypeID.UserCmd:
                    this.Messages.Add(this.ProcessUserCmd());
                    break;    

                case MessageTypeID.DataTables:
                    this.Messages.Add(this.ProcessDataTable());
                    break;

                case MessageTypeID.Stop:
                    break; 
                
                case MessageTypeID.StringTables:
                    this.Messages.Add(this.ProcessStringTable());
                    break;
            }
        }

    }

    private Message ProcessPacket(MessageTypeID messageType)
    {
        Message message = new();
        
        message.TickNumber = this.Stream.ReadInt32();
        this.Stream._index += 672; // Skip Preamble stuff
        message.Length = this.Stream.ReadInt32();
        message.MessageData = this.Stream.ReadBitStream(message.Length * 8);
        message.MessageType = messageType;

        return message;
    }

    private Message ProcessSyncTick()
    {
        Message message = new();
        message.TickNumber = this.Stream.ReadInt32();
        message.MessageType = MessageTypeID.SyncTick;
        return message;
    }

    private Message ProcessConsoleCmd()
    {
        Message message = new();
        message.TickNumber = this.Stream.ReadInt32();
        message.Length = this.Stream.ReadInt32();
        message.MessageData = this.Stream.ReadBitStream(message.Length * 8);
        message.MessageType = MessageTypeID.ConsoleCmd;
        return message;
    }

    private Message ProcessUserCmd()
    {
        Message message = new();
        message.TickNumber = this.Stream.ReadInt32();
        message.Length = this.Stream.ReadInt32();
        message.MessageData = this.Stream.ReadBitStream(message.Length * 8);
        message.MessageType = MessageTypeID.UserCmd;
        return message;
    }

    private Message ProcessStringTable()
    {
        Message message = new();
        message.TickNumber = this.Stream.ReadInt32();
        message.Length = this.Stream.ReadInt32();
        message.MessageData = this.Stream.ReadBitStream(message.Length * 8);
        message.MessageType = MessageTypeID.StringTables;
        return message;
    }

    private Message ProcessDataTable()
    {
        Message message = new();
        message.TickNumber = this.Stream.ReadInt32();
        message.Length = this.Stream.ReadInt32();
        message.MessageData = this.Stream.ReadBitStream(message.Length * 8);
        message.MessageType = MessageTypeID.DataTables;

        return message;
    }

    public void ProcessMessages()
    {
        foreach(Message message in this.Messages)
        {
            if(message.MessageType == MessageTypeID.Packet || message.MessageType == MessageTypeID.Sigon)
            {
                try
                {
                    message.ParsePackets(this.State);
                }
                catch
                {
                    
                }
            }
        }
    }
}
