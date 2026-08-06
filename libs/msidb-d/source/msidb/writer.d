module msidb.writer;

import msidb.spec;
import cfb.writer : CfbWriter;
import cab.writer : CabWriter;
import std.file : exists, read;
import std.exception : enforce;
import std.conv : to;

/**
 * Maps ProductSpec to the core Windows Installer tables and writes them into
 * an OLE compound file. The table streams use MSI's compact row convention:
 * strings are uint16 indexes in _StringData/_StringPool, and integer fields
 * are signed values biased by 0x8000. This is the v0.2 table subset needed to
 * inspect a real MSI database and carry its files in an embedded cabinet.
 */
class MsiDatabase {
    private ProductSpec productSpec;
    
    this(ProductSpec spec) {
        this.productSpec = spec;
    }
    
    void save(string path) {
        auto strings = new StringPool();
        Table[] tables;

        auto directories = makeTable("Directory", ["Directory", "Directory_Parent", "DefaultDir"],
            [false, false, false]);
        directories.add("TARGETDIR", "", "SourceDir");
        auto installDirectory = productSpec.rootFolder.id.length ? productSpec.rootFolder.id : "INSTALLDIR";
        directories.add(installDirectory, "TARGETDIR",
            productSpec.rootFolder.name.length ? productSpec.rootFolder.name : productSpec.name);
        addFolders(directories, productSpec.rootFolder);
        tables ~= directories;

        auto components = makeTable("Component",
            ["Component", "ComponentId", "Directory_", "Attributes", "Condition", "KeyPath"],
            [false, false, false, true, false, false]);
        auto files = makeTable("File",
            ["File", "Component_", "FileName", "FileSize", "Version", "Language", "Attributes", "Sequence"],
            [false, false, false, true, false, false, true, true]);
        auto cabinet = new CabWriter();
        int sequence = 1;
        foreach (component; productSpec.components) {
            auto directory = component.directoryId.length ? component.directoryId : installDirectory;
            auto keyPath = component.files.length ? component.files[0].id : "";
            components.add(component.id, componentGuid(component), directory, 0, "", keyPath);
            foreach (file; component.files) {
                enforce(file.sourcePath.exists, "MSI source file does not exist: " ~ file.sourcePath);
                auto data = cast(ubyte[])read(file.sourcePath);
                auto target = file.targetName.length ? file.targetName : file.sourcePath;
                files.add(file.id, component.id, target, cast(int)data.length, "", "", 0, sequence++);
                cabinet.addFile(target, data);
            }
        }
        tables ~= components;
        tables ~= files;

        auto features = makeTable("Feature",
            ["Feature", "Feature_Parent", "Title", "Description", "Display", "Level", "Directory_", "Attributes"],
            [false, false, false, false, true, true, false, true]);
        auto featureComponents = makeTable("FeatureComponents", ["Feature_", "Component_"], [false, false]);
        if (productSpec.features.length) {
            foreach (feature; productSpec.features) {
                features.add(feature.id, "", feature.title, feature.description, 1, feature.level,
                    installDirectory, 0);
                foreach (componentId; feature.componentIds) featureComponents.add(feature.id, componentId);
            }
        } else {
            features.add("Complete", "", productSpec.name, productSpec.name, 1, 1, installDirectory, 0);
            foreach (component; productSpec.components) featureComponents.add("Complete", component.id);
        }
        tables ~= features;
        tables ~= featureComponents;

        auto properties = makeTable("Property", ["Property", "Value"], [false, false]);
        properties.add("ProductName", productSpec.name);
        properties.add("Manufacturer", productSpec.manufacturer);
        properties.add("ProductVersion", productSpec.productVersion);
        properties.add("ProductCode", productCode());
        properties.add("UpgradeCode", upgradeCode());
        properties.add("INSTALLLEVEL", "1");
        tables ~= properties;

        auto media = makeTable("Media", ["DiskId", "LastSequence", "DiskPrompt", "Cabinet", "VolumeLabel", "Source"],
            [true, true, false, false, false, false]);
        media.add(1, sequence - 1, "", "#cab1", "", "");
        tables ~= media;

        // MSI tools discover table layouts through these two system tables.
        auto tableNames = makeTable("_Tables", ["Name"], [false]);
        foreach (table; tables) tableNames.add(table.name);
        tableNames.add("_Tables");
        tableNames.add("_Columns");
        auto columnInfo = makeTable("_Columns", ["Table", "Number", "Name", "Type"],
            [false, true, false, true]);
        foreach (table; tables ~ [tableNames]) {
            foreach (i, name; table.columns)
                columnInfo.add(table.name, cast(int)i + 1, name, table.numeric[i] ? 0x0202 : 0x0800 | 255);
        }
        foreach (i, name; ["Table", "Number", "Name", "Type"])
            columnInfo.add("_Columns", cast(int)i + 1, name,
                (i == 1 || i == 3) ? 0x0202 : 0x0800 | 255);
        tables ~= tableNames;
        tables ~= columnInfo;

        auto cfb = new CfbWriter();
        foreach (table; tables) cfb.addStream(table.name, table.encode(strings));
        cfb.addStream("_StringPool", strings.poolBytes());
        cfb.addStream("_StringData", strings.dataBytes());
        cfb.addStream("#cab1", cabinet.build());
        cfb.save(path);
    }

    private void addFolders(ref Table directories, FolderSpec folder) {
        foreach (child; folder.subfolders) {
            auto parent = child.parentId.length ? child.parentId :
                (folder.id.length ? folder.id : "INSTALLDIR");
            directories.add(child.id, parent, child.name);
            addFolders(directories, child);
        }
    }

    private string componentGuid(ComponentSpec component) {
        version (UseStringUUIDs) return component.guid;
        else return component.guid.to!string;
    }

    private string productCode() {
        version (UseStringUUIDs) return productSpec.productCode;
        else return productSpec.productCode.to!string;
    }

    private string upgradeCode() {
        version (UseStringUUIDs) return productSpec.upgradeCode;
        else return productSpec.upgradeCode.to!string;
    }
}

private struct Cell {
    string text;
    int number;
    bool numeric;

    static Cell fromString(string value) {
        Cell c;
        c.text = value;
        return c;
    }

    static Cell fromInt(int value) {
        Cell c;
        c.number = value;
        c.numeric = true;
        return c;
    }
}

private struct Table {
    string name;
    string[] columns;
    bool[] numeric;
    Cell[][] rows;

    void add(T...)(T values) {
        import std.traits : isIntegral, isSomeString;
        Cell[] cells;
        foreach (value; values) {
            static if (isIntegral!(typeof(value)))
                cells ~= Cell.fromInt(cast(int)value);
            else static if (isSomeString!(typeof(value)))
                cells ~= Cell.fromString(value);
            else
                static assert(0, "Unsupported MSI cell type");
        }
        enforce(cells.length == columns.length, "Wrong number of cells for MSI table " ~ name);
        rows ~= cells;
    }

    ubyte[] encode(StringPool strings) {
        ubyte[] bytes;
        foreach (row; rows) foreach (i, cell; row) {
            auto value = numeric[i] ? cast(ushort)(cell.number + 0x8000) : strings.index(cell.text);
            bytes ~= cast(ubyte)value;
            bytes ~= cast(ubyte)(value >> 8);
        }
        return bytes;
    }
}

private Table makeTable(string name, string[] columns, bool[] numeric) {
    return Table(name, columns, numeric);
}

private class StringPool {
    private string[] strings;

    ushort index(string value) {
        if (!value.length) return 0;
        foreach (i, existing; strings)
            if (existing == value) return cast(ushort)(i + 1);
        enforce(strings.length < ushort.max, "MSI string pool has too many strings");
        strings ~= value;
        return cast(ushort)strings.length;
    }

    ubyte[] poolBytes() {
        ubyte[] bytes;
        append16(bytes, 1252); // Windows ANSI code page.
        append16(bytes, 0);
        foreach (value; strings) {
            append16(bytes, cast(ushort)value.length);
            append16(bytes, 1); // Reference count; streams retain all strings.
        }
        return bytes;
    }

    ubyte[] dataBytes() {
        ubyte[] bytes;
        foreach (value; strings) bytes ~= cast(ubyte[])value;
        return bytes;
    }

    private static void append16(ref ubyte[] bytes, ushort value) {
        bytes ~= cast(ubyte)value;
        bytes ~= cast(ubyte)(value >> 8);
    }
}
