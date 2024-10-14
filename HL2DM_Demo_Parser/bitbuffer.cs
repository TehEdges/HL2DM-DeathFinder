using System.Buffers;
using System.Data;
using Microsoft.VisualBasic;
using System;

namespace HL2DM_Demo_Parser;

public class BitView
{
    public byte[] view;
    public bool bigEndian;
    public int byteLength;

    private static readonly byte[] _scratch = new byte[8];

    public BitView(byte[] Source, int byteoffset, int lbyteLength)
    {
        bool isBuffer = Source is Array || Source.GetType().Name == "Byte[]";
        if (!isBuffer)
        {
            throw new SystemException("Must specify a valid ArrayBuffer or Buffer");
        }

        if(isBuffer)
        {
            byteLength = Source.Length;
        }
        else
        {
            byteLength = lbyteLength;
        }
        view = new byte[byteLength];
        Array.Copy(Source, byteoffset, view, 0, byteLength);
        bigEndian = false;
    }

    public byte[] buffer { 
        get
        {
            if(Type.GetType("System.Buffer") != null)
            {
                return (byte[])view.Clone();
            }
            else
            {
                return view;
            }
        }
     }

     public int GetBits(int offset, int bits, bool signed)
    {
        int available = (this.view.Length * 8) - offset;

        if (bits > available)
        {
            throw new SystemException($"Cannot get {bits} bit(s) from offset {offset}, {available} available");
        }

        int value = 0;

        for (int i = 0; i < bits;)
        {
            int remaining = bits - i;
            int bitOffset = offset & 7;
            int currentByte = this.view[offset >> 3]; // Get the current byte

            // The max number of bits we can read from the current byte
            int read = Math.Min(remaining, 8 - bitOffset);

            int mask, readBits;

            if (this.bigEndian)
            {
                // Create a mask with the correct bit width
                mask = ~(0xFF << read);
                // Shift the bits we want to the start of the byte and mask the rest
                readBits = (currentByte >> (8 - read - bitOffset)) & mask;

                value <<= read;
                value |= readBits;
            }
            else
            {
                // Create a mask with the correct bit width
                mask = ~(0xFF << read);
                // Shift the bits we want to the start of the byte and mask off the rest
                readBits = (currentByte >> bitOffset) & mask;

                value |= (readBits << i);
            }

            offset += read;
            i += read;
        }

        if (signed)
        {
            // If we're not working with a full 32 bits, check the imaginary MSB and convert to a signed 32-bit value
            if (bits != 32 && (value & (1 << (bits - 1))) != 0)
            {
                value |= -1 ^ ((1 << bits) - 1);
            }
        }

        return value;
    }

    public bool GetBoolean(int offset)
    {
        return GetBits(offset, 1, false) != 0;
    }

    public sbyte GetInt8(int offset)
    {
        return (sbyte)GetBits(offset, 8, true);
    }

    public byte GetUint8(int offset)
    {
        return (byte)GetBits(offset, 8, false);
    }

    public short GetInt16(int offset)
    {
        return (short)GetBits(offset, 16, true);
    }

    public ushort GetUint16(int offset)
    {
        return (ushort)GetBits(offset, 16, false);
    }

    public int GetInt32(int offset)
    {
        return GetBits(offset, 32, true);
    }

    public uint GetUint32(int offset)
    {
        return (uint)GetBits(offset, 32, false);
    }

    public float GetFloat32(int offset)
    {
        uint intValue = GetUint32(offset);
        // Convert the uint to byte array
        _scratch[0] = (byte)(intValue & 0xFF);
        _scratch[1] = (byte)((intValue >> 8) & 0xFF);
        _scratch[2] = (byte)((intValue >> 16) & 0xFF);
        _scratch[3] = (byte)((intValue >> 24) & 0xFF);
        return BitConverter.ToSingle(_scratch, 0);
    }

    public double GetFloat64(int offset)
    {
        uint low = GetUint32(offset);
        uint high = GetUint32(offset + 32);
        // Convert the uints to byte array
        _scratch[0] = (byte)(low & 0xFF);
        _scratch[1] = (byte)((low >> 8) & 0xFF);
        _scratch[2] = (byte)((low >> 16) & 0xFF);
        _scratch[3] = (byte)((low >> 24) & 0xFF);
        _scratch[4] = (byte)(high & 0xFF);
        _scratch[5] = (byte)((high >> 8) & 0xFF);
        _scratch[6] = (byte)((high >> 16) & 0xFF);
        _scratch[7] = (byte)((high >> 24) & 0xFF);
        return BitConverter.ToDouble(_scratch, 0);
    }
    public byte[] GetArrayBuffer(int offset, int byteLength)
    {
        byte[] buffer = new byte[byteLength];
        for (int i = 0; i < byteLength; i++)
        {
            buffer[i] = GetUint8(offset + (i * 8));
        }
        return buffer;
    }
}
public class BitStream
{
    private BitView _view;
    public int _index;
    public int _startIndex;
    public int _length;

    public BitStream(BitView source, int byteOffset = 0, int byteLength = 0)
    {
        if (!(source is BitView))
        {
            throw new ArgumentException("Must specify a valid BitView");
        }

        _view = source;
        _index = 0;
        _startIndex = 0;
        _length = byteLength == 0 ? _view.byteLength * 8 : byteLength * 8;
    }

    public int Index
    {
        get { return _index - _startIndex; }
        set { _index = value + _startIndex; }
    }

    public int Length
    {
        get { return _length - _startIndex; }
        set { _length = value + _startIndex; }
    }

    public int BitsLeft
    {
        get { return _length - _index; }
    }

    public int ByteIndex
    {
        get { return (int)Math.Ceiling(_index / 8.0); }
        set { _index = value * 8; }
    }

    public Array Buffer
    {
        get { return _view.buffer; }
    }

    public BitView View
    {
        get { return _view; }
    }

    public bool BigEndian
    {
        get { return _view.bigEndian; }
        set { _view.bigEndian = value; }
    }

    public int ReadBits(int bits, bool signed)
    {
        int val = _view.GetBits(_index, bits, signed);
        _index += bits;
        return val;
    }

    public bool ReadBoolean()
    {
        return ReadBits(1, false) != 0;
    }

    public int ReadInt8()
    {
        return ReadBits(8, true);
    }

    public int ReadUint8()
    {
        return ReadBits(8, false);
    }

    public int ReadInt16()
    {
        return ReadBits(16, true);
    }

    public int ReadUint16()
    {
        return ReadBits(16, false);
    }

    public int ReadInt32()
    {
        return ReadBits(32, true);
    }

    public uint ReadUint32()
    {
        return (uint)ReadBits(32, false);
    }

    public float ReadFloat32()
    {
        uint value = ReadUint32();
        return BitConverter.ToSingle(BitConverter.GetBytes(value), 0);
    }

    public double ReadFloat64()
    {
        ulong value = ReadUint32();
        value |= (ulong)ReadUint32() << 32;
        return BitConverter.ToDouble(BitConverter.GetBytes(value), 0);
    }

    public string ReadASCIIString(int bytes)
    {
        return ReadString(bytes, false);
    }

    public string ReadUTF8String(int bytes)
    {
        return ReadString(bytes, true);
    }

    private string ReadString(int bytes, bool utf8)
    {
        var fixedLength = bytes != 0;
        if (bytes == 0)
        {
            bytes = (int)Math.Floor((double)(_length - _index) / 8);
        }

        byte[] byteArray = new byte[bytes]; // Create an array to hold the byte values

        

        int i = 0;
        while (i < bytes)
        {
            byte c = (byte)ReadUint8(); // Read a byte directly

            if (c == 0x00) // Null terminator check
            {
                if(!fixedLength)
                {
                    break; // Stop if null character is found
                }
            }

            byteArray[i] = c; // Store the byte in the array
            i++;
        }

        // Return the string using the correct encoding
        return utf8 ? System.Text.Encoding.UTF8.GetString(byteArray, 0, i) : System.Text.Encoding.Default.GetString(byteArray, 0, i);
    }
    
    public byte[] ReadArrayBuffer(int byteLength)
    {
        byte[] buffer = new byte[byteLength];
        for (int i = 0; i < byteLength; i++)
        {
            buffer[i] = (byte)ReadUint8();
        }
        _index += byteLength * 8;
        return buffer;
    }
    
    public BitStream ReadBitStream(int bitLength)
    {
        var slice = new BitStream(_view);
        slice._startIndex = _index;
        slice._index = _index;
        slice.Length = bitLength;
        _index += bitLength;
        return slice;
    }

    public int GetBitsLeft
    {
        get{ return this.BitsLeft;}
    }
    public int ReadBitVar(bool signed)
    {
        int type = ReadBits(2, false);
        switch (type)
        {
            case 0:
                return ReadBits(4, signed);
            case 1:
                return ReadBits(8, signed);
            case 2:
                return ReadBits(12, signed);
            case 3:
                return ReadBits(32, signed);
            default:
                throw new InvalidOperationException("Invalid var bit");
        }
    }

    public int ReadVarInt(bool signed = false)
    {
        int result = 0;
        for (int i = 0; i < 35; i += 7)
        {
            byte b = (byte)ReadUint8();
            result |= ((b & 0x7F) << i);
            if ((b >> 7) == 0)
            {
                break;
            }
        }

        if (signed)
        {
            return ((result >> 1) ^ -(result & 1));
        }
        else
        {
            return result;
        }
    }

}
