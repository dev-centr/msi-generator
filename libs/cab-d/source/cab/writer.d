module cab.writer;

import std.stdio;
import std.array;
import std.exception : enforce;
import std.algorithm.searching : canFind;

/**
 * Writes a single-folder, uncompressed Microsoft Cabinet (CAB).
 *
 * The output uses CFData blocks of at most 32 KiB and has no optional reserve,
 * previous-cabinet, or next-cabinet records. This keeps v0.2 deterministic
 * while producing normal MSCF cabinets consumable by MSI's cabinet source.
 */
class CabWriter {
    struct FileEntry {
        string name;
        ubyte[] data;
    }
    
    private FileEntry[] files;
    
    void addFile(string name, ubyte[] data) {
        enforce(name.length > 0, "CAB file names cannot be empty");
        enforce(name.canFind('\0') == false, "CAB file names cannot contain NUL");
        files ~= FileEntry(name, data);
    }
    
    void save(string path) {
        auto f = File(path, "wb");
        f.rawWrite(build());
    }

    ubyte[] build() {
        enum uint headerSize = 36;
        enum uint folderSize = 8;
        enum uint cfDataHeaderSize = 8;
        enum uint blockSize = 32 * 1024;

        ubyte[] fileTable;
        uint folderOffset;
        foreach (entry; files) {
            append32(fileTable, cast(uint)entry.data.length);
            append32(fileTable, folderOffset);
            append16(fileTable, 0); // First (and only) folder.
            append16(fileTable, 0); // DOS date is intentionally unspecified.
            append16(fileTable, 0); // DOS time is intentionally unspecified.
            append16(fileTable, 0x20); // Archive attribute.
            fileTable ~= cast(ubyte[])entry.name;
            fileTable ~= 0;
            folderOffset += cast(uint)entry.data.length;
        }

        ubyte[] payload;
        foreach (entry; files) payload ~= entry.data;
        auto blockCount = payload.length ? (payload.length + blockSize - 1) / blockSize : 0;
        auto dataOffset = headerSize + folderSize + fileTable.length;
        auto cabinetSize = dataOffset + payload.length + blockCount * cfDataHeaderSize;
        enforce(cabinetSize <= uint.max, "CAB output exceeds 4 GiB");

        ubyte[] cabinet;
        cabinet ~= cast(ubyte[])"MSCF";
        append32(cabinet, 0); // Reserved.
        append32(cabinet, cast(uint)cabinetSize);
        append32(cabinet, 0); // Reserved.
        append32(cabinet, headerSize + folderSize); // First CFFILE record.
        append32(cabinet, 0); // Reserved.
        cabinet ~= 3; // Minor version.
        cabinet ~= 1; // Major version.
        append16(cabinet, 1); // One folder.
        append16(cabinet, cast(ushort)files.length);
        append16(cabinet, 0); // No optional header data.
        append16(cabinet, 0); // Set ID.
        append16(cabinet, 0); // Cabinet index.

        append32(cabinet, cast(uint)dataOffset);
        append16(cabinet, cast(ushort)blockCount);
        append16(cabinet, 0); // typeCompress = none.
        cabinet ~= fileTable;

        for (size_t offset = 0; offset < payload.length; offset += blockSize) {
            auto end = offset + blockSize < payload.length ? offset + blockSize : payload.length;
            append32(cabinet, 0); // CFDATA checksum is optional.
            append16(cabinet, cast(ushort)(end - offset));
            append16(cabinet, cast(ushort)(end - offset));
            cabinet ~= payload[offset .. end];
        }

        return cabinet;
    }

    private static void append16(ref ubyte[] bytes, ushort value) {
        bytes ~= cast(ubyte)value;
        bytes ~= cast(ubyte)(value >> 8);
    }

    private static void append32(ref ubyte[] bytes, uint value) {
        foreach (i; 0 .. 4) bytes ~= cast(ubyte)(value >> (i * 8));
    }
}
