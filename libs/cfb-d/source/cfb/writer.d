module cfb.writer;

import std.stdio;
import std.array;
import std.exception : enforce;
import std.utf : toUTF16;

/**
 * Writes a version 3 OLE2 Compound File Binary (CFB).
 *
 * Streams smaller than 4096 bytes use the mini stream/MiniFAT; larger streams
 * use normal 512-byte sectors.  This is deliberately a small writer, but the
 * result has the normal CFB header, FAT, directory stream, and named streams
 * expected by OLE and Windows Installer readers.
 */
class CfbWriter {
    struct Entry {
        string name;
        ubyte[] data;
    }

    private Entry[] entries;

    void addStream(string name, ubyte[] data) {
        enforce(name.length > 0, "CFB stream names cannot be empty");
        enforce(name.toUTF16.length <= 31, "CFB stream names are limited to 31 UTF-16 code units");
        entries ~= Entry(name, data);
    }

    void save(string path) {
        enum uint freeSect = 0xFFFF_FFFF;
        enum uint endOfChain = 0xFFFF_FFFE;
        enum uint fatSect = 0xFFFF_FFFD;
        enum uint noStream = freeSect;
        enum uint miniCutoff = 4096;
        enum uint sectorSize = 512;
        enum uint miniSectorSize = 64;

        bool[] isMini;
        uint[] miniStart;
        uint[] streamStart;
        uint[] streamSectors;
        uint[] miniFat;
        ubyte[] miniStream;

        foreach (entry; entries) {
            auto useMini = entry.data.length < miniCutoff;
            isMini ~= useMini;
            if (useMini) {
                auto first = cast(uint)(miniStream.length / miniSectorSize);
                auto count = sectorCount(entry.data.length, miniSectorSize);
                miniStart ~= first;
                streamStart ~= freeSect;
                streamSectors ~= 0;
                foreach (i; 0 .. count) {
                    miniFat ~= i + 1 < count ? first + cast(uint)i + 1 : endOfChain;
                    auto begin = cast(size_t)i * miniSectorSize;
                    auto end = begin + miniSectorSize;
                    if (begin < entry.data.length)
                        miniStream ~= entry.data[begin .. entry.data.length < end ? entry.data.length : end];
                    miniStream.length = (i + 1) * miniSectorSize;
                }
            } else {
                miniStart ~= freeSect;
                streamStart ~= 0; // Assigned after the mini stream.
                streamSectors ~= sectorCount(entry.data.length, sectorSize);
            }
        }

        auto miniStreamSectors = sectorCount(miniStream.length, sectorSize);
        uint nextSector = 0;
        auto miniStreamStart = miniStreamSectors ? nextSector : freeSect;
        nextSector += miniStreamSectors;
        foreach (i; 0 .. entries.length) {
            if (!isMini[i]) {
                streamStart[i] = streamSectors[i] ? nextSector : endOfChain;
                nextSector += streamSectors[i];
            }
        }
        auto directoryStart = nextSector;
        auto directorySectors = sectorCount((entries.length + 1) * 128, sectorSize);
        nextSector += directorySectors;
        auto miniFatStart = miniFat.length ? nextSector : freeSect;
        auto miniFatSectors = sectorCount(miniFat.length * uint.sizeof, sectorSize);
        nextSector += miniFatSectors;

        // FAT sectors describe themselves, so solve the small fixed point.
        auto fatSectors = cast(uint)0;
        while (true) {
            auto required = sectorCount(nextSector + fatSectors, sectorSize / uint.sizeof);
            if (required == fatSectors) break;
            fatSectors = required;
        }
        auto fatStart = nextSector;
        auto totalSectors = nextSector + fatSectors;
        enforce(fatSectors <= 109, "CFB DIFAT sectors are not implemented");

        uint[] fat;
        fat.length = totalSectors;
        foreach (ref value; fat) value = freeSect;
        chain(fat, miniStreamStart, miniStreamSectors, endOfChain);
        foreach (i; 0 .. entries.length)
            if (!isMini[i]) chain(fat, streamStart[i], streamSectors[i], endOfChain);
        chain(fat, directoryStart, directorySectors, endOfChain);
        chain(fat, miniFatStart, miniFatSectors, endOfChain);
        foreach (i; 0 .. fatSectors) fat[fatStart + i] = fatSect;

        ubyte[] directory;
        directory.length = directorySectors * sectorSize;
        writeDirectoryEntry(directory, 0, "Root Entry", 5, noStream,
            entries.length ? 1 : noStream, noStream, miniStreamStart, miniStream.length);
        foreach (i, entry; entries) {
            // A simple right-sibling tree is sufficient for the small flat
            // directory emitted here; CFB readers traverse these links.
            auto right = i + 1 < entries.length ? cast(uint)i + 2 : noStream;
            auto start = isMini[i] ? miniStart[i] : streamStart[i];
            writeDirectoryEntry(directory, i + 1, entry.name, 2, noStream,
                right, noStream, start, entry.data.length);
        }

        ubyte[512] header;
        header[0..8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]; // Magic
        put16(header[], 24, 0x003E);
        put16(header[], 26, 0x0003);
        put16(header[], 28, 0xFFFE);
        put16(header[], 30, 9);
        put16(header[], 32, 6);
        put32(header[], 44, fatSectors);
        put32(header[], 48, directoryStart);
        put32(header[], 56, miniCutoff);
        put32(header[], 60, miniFatStart);
        put32(header[], 64, miniFatSectors);
        put32(header[], 68, freeSect); // No DIFAT sectors needed for v0.2.
        put32(header[], 72, 0);
        foreach (i; 0 .. 109) put32(header[], 76 + i * 4, i < fatSectors ? fatStart + cast(uint)i : freeSect);

        auto f = File(path, "wb");
        f.rawWrite(header);
        writePadded(f, miniStream, miniStreamSectors * sectorSize);
        foreach (i, entry; entries)
            if (!isMini[i]) writePadded(f, entry.data, streamSectors[i] * sectorSize);
        f.rawWrite(directory);
        if (miniFatSectors) {
            ubyte[] miniFatBytes;
            foreach (value; miniFat) append32(miniFatBytes, value);
            writePadded(f, miniFatBytes, miniFatSectors * sectorSize);
        }
        foreach (sector; 0 .. fatSectors) {
            ubyte[] fatBytes;
            foreach (i; 0 .. sectorSize / uint.sizeof)
                append32(fatBytes, fat[sector * (sectorSize / uint.sizeof) + i]);
            f.rawWrite(fatBytes);
        }
    }

    private static uint sectorCount(size_t bytes, uint unit) {
        return bytes ? cast(uint)((bytes + unit - 1) / unit) : 0;
    }

    private static void chain(ref uint[] fat, uint start, uint count, uint terminator) {
        if (!count) return;
        foreach (i; 0 .. count)
            fat[start + i] = i + 1 < count ? start + i + 1 : terminator;
    }

    private static void writePadded(File file, ubyte[] data, uint bytes) {
        file.rawWrite(data);
        if (data.length < bytes) {
            ubyte[] padding;
            padding.length = bytes - data.length;
            file.rawWrite(padding);
        }
    }

    private static void writeDirectoryEntry(ubyte[] directory, size_t index,
            string name, ubyte objectType, uint left, uint right, uint child,
            uint startSector, size_t streamSize) {
        auto offset = index * 128;
        auto utf16 = name.toUTF16;
        foreach (i, codeUnit; utf16) put16(directory, offset + i * 2, codeUnit);
        put16(directory, offset + utf16.length * 2, 0);
        put16(directory, offset + 64, cast(ushort)((utf16.length + 1) * 2));
        directory[offset + 66] = objectType;
        directory[offset + 67] = 1; // Black node.
        put32(directory, offset + 68, left);
        put32(directory, offset + 72, right);
        put32(directory, offset + 76, child);
        put32(directory, offset + 116, startSector);
        put32(directory, offset + 120, cast(uint)streamSize);
        put32(directory, offset + 124, 0);
    }

    private static void put16(ubyte[] bytes, size_t offset, ushort value) {
        bytes[offset] = cast(ubyte)value;
        bytes[offset + 1] = cast(ubyte)(value >> 8);
    }

    private static void put32(ubyte[] bytes, size_t offset, uint value) {
        foreach (i; 0 .. 4) bytes[offset + i] = cast(ubyte)(value >> (i * 8));
    }

    private static void append32(ref ubyte[] bytes, uint value) {
        foreach (i; 0 .. 4) bytes ~= cast(ubyte)(value >> (i * 8));
    }
}
