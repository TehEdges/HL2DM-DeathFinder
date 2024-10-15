namespace HL2DM_Demo_Parser;
public class SnappyDecompressor
{
    private static readonly uint[] WORD_MASK = { 0, 0xff, 0xffff, 0xffffff, 0xffffffff };
    private byte[] array;
    private int pos;

    public SnappyDecompressor(byte[] compressed)
    {
        this.array = compressed;
        this.pos = 0;
    }

    private void CopyBytes(byte[] fromArray, int fromPos, byte[] toArray, int toPos, int length)
    {
        for (int i = 0; i < length; i++)
        {
            toArray[toPos + i] = fromArray[fromPos + i];
        }
    }

    private void SelfCopyBytes(byte[] array, int pos, int offset, int length)
    {
        for (int i = 0; i < length; i++)
        {
            array[pos + i] = array[pos - offset + i];
        }
    }

    public int ReadUncompressedLength()
    {
        int result = 0;
        int shift = 0;

        while (shift < 32 && pos < array.Length)
        {
            byte c = array[pos++];
            int val = c & 0x7f;

            if (((val << shift) >> shift) != val)
            {
                return -1;
            }

            result |= val << shift;

            if (c < 128)
            {
                return result;
            }

            shift += 7;
        }
        return -1;
    }

    public bool UncompressToBuffer(byte[] outBuffer)
    {
        int arrayLength = array.Length;
        int outPos = 0;

        while (pos < array.Length)
        {
            byte c = array[pos++];
            if ((c & 0x3) == 0)
            {
                // Literal
                int len = (c >> 2) + 1;
                if (len > 60)
                {
                    if (pos + 3 >= arrayLength)
                    {
                        return false;
                    }
                    int smallLen = len - 60;
                    len = array[pos] + (array[pos + 1] << 8) + (array[pos + 2] << 16) + (array[pos + 3] << 24);
                    len = (len & (int)WORD_MASK[smallLen]) + 1;
                    pos += smallLen;
                }

                if (pos + len > arrayLength)
                {
                    return false;
                }

                CopyBytes(array, pos, outBuffer, outPos, len);
                pos += len;
                outPos += len;
            }
            else
            {
                int len, offset;
                switch (c & 0x3)
                {
                    case 1:
                        len = ((c >> 2) & 0x7) + 4;
                        offset = array[pos] + ((c >> 5) << 8);
                        pos++;
                        break;
                    case 2:
                        if (pos + 1 >= arrayLength)
                        {
                            return false;
                        }
                        len = (c >> 2) + 1;
                        offset = array[pos] + (array[pos + 1] << 8);
                        pos += 2;
                        break;
                    case 3:
                        if (pos + 3 >= arrayLength)
                        {
                            return false;
                        }
                        len = (c >> 2) + 1;
                        offset = array[pos] + (array[pos + 1] << 8) + (array[pos + 2] << 16) + (array[pos + 3] << 24);
                        pos += 4;
                        break;
                    default:
                        continue; // Not possible; added for clarity
                }

                if (offset == 0 || offset > outPos)
                {
                    return false;
                }

                SelfCopyBytes(outBuffer, outPos, offset, len);
                outPos += len;
            }
        }
        return true;
    }

    public byte[] Uncompress(byte[] compressed)
    {
        if (compressed == null || compressed.Length == 0)
        {
            throw new ArgumentException("Input must be a non-empty byte array.");
        }

        var decompressor = new SnappyDecompressor(compressed);
        int length = decompressor.ReadUncompressedLength();
        if (length == -1)
        {
            throw new InvalidOperationException("Invalid Snappy bitstream");
        }

        byte[] uncompressed = new byte[length];
        if (!decompressor.UncompressToBuffer(uncompressed))
        {
            throw new InvalidOperationException("Invalid Snappy bitstream");
        }

        return uncompressed;
    }
}
