using System;

namespace HL2DM_Demo_Parser;

public class StringTable
{
    public string TableName;
    public int MaxEntries,UserDataSize, UserDataSizeBits;
    public bool isCompressed, FixedUserDataSize;
    public List<StringTableEntry> Entries;
    public List<StringTableEntry> clientEntries;
    public BitStream RawData;

    public StringTable(string TableName, int MaxEntries, int UserDataSize, int UserDataSizeBits, bool isCompressed, BitStream RawData)
    {
        this.TableName = TableName;
        this.MaxEntries = MaxEntries;
        this.UserDataSize = UserDataSize;
        this.UserDataSizeBits = UserDataSizeBits;
        this.isCompressed = isCompressed;
        this.RawData = RawData;
        this.Entries = new();
    }

    public void ProcessStringTable(int entryCount, List<StringTableEntry> existingEntries = null)
    {
        existingEntries ??= new List<StringTableEntry>();
        int entryBits = (int)Math.Log2(this.MaxEntries);
        List<StringTableEntry> entries = existingEntries.Count > 0 ? existingEntries : new List<StringTableEntry>(new StringTableEntry[entryCount]);
        int lastEntry = -1;
        List<StringTableEntry> history = new List<StringTableEntry>();
        for (int i = 0; i < entryCount; i++)
        {
            int entryIndex = !RawData.ReadBoolean() ? RawData.ReadBits(entryBits, false) : lastEntry + 1;
            lastEntry = entryIndex;

            if (entryIndex < 0 || entryIndex >= this.MaxEntries)
            {
                throw new ArgumentException("Invalid string index for string table");
            }

            string value = null;

            if (RawData.ReadBoolean())
            {
                bool subStringCheck = RawData.ReadBoolean();
                if (subStringCheck)
                {
                    int index = RawData.ReadBits(5, false);
                    int bytesToCopy = RawData.ReadBits(5, false);
                    string restOfString = RawData.ReadASCIIString(0);

                    if (string.IsNullOrEmpty(history[index]?.text))
                    {
                        value = restOfString;
                    }
                    else
                    {
                        value = history[index].text.Substring(0, bytesToCopy) + restOfString;
                    }
                }
                else
                {
                    value = RawData.ReadASCIIString(0);
                }
            }

            BitStream userData = null;

            if (RawData.ReadBoolean())
            {
                if (this.UserDataSize != 0 && this.UserDataSizeBits != 0)
                {
                    userData = RawData.ReadBitStream(this.UserDataSizeBits);
                }
                else
                {
                    int userDataBytes = RawData.ReadBits(14, false);
                    userData = RawData.ReadBitStream(userDataBytes * 8);
                }
            }

            if (entryIndex < existingEntries.Count && existingEntries[entryIndex] != null)
            {
                StringTableEntry existingEntry = new StringTableEntry
                {
                    text = existingEntries[entryIndex].text,
                    extraData = existingEntries[entryIndex].extraData
                };

                if (userData != null)
                {
                    existingEntry.extraData = userData;
                }

                if (value != null)
                {
                    existingEntry.text = value;
                }

                entries[entryIndex] = existingEntry;
                history.Add(existingEntry);
            }
            else
            {
                StringTableEntry newEntry = new StringTableEntry
                {
                    text = value,
                    extraData = userData
                };
                if(entries.Count - 1 < entryIndex)
                {
                    entries.Add(newEntry);
                }
                else
                {
                    entries[entryIndex] = newEntry;
                }
                history.Add(newEntry);
            }

            if (history.Count > 32)
            {
                history.RemoveAt(0);
            }
        }
        this.Entries = entries;
    }
}



public class StringTableEntry
{
    public string text;
    public BitStream extraData;
}