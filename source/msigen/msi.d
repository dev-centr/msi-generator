module msigen.msi;

import msigen.common;
import msidb.spec;
import msidb.writer;
import std.path : baseName;
import std.conv : to;

/**
 * Convenience adapter for plugins that only have PackageInfo. For richer MSI
 * authoring (multiple directories, features, and registry rows), use
 * MsiDatabase with a ProductSpec directly.
 */
class MsiGenerator : PackageGenerator {
    void generate(PackageInfo info, string outputPath) {
        ProductSpec spec;
        spec.name = info.name;
        spec.manufacturer = info.publisher;
        spec.productVersion = info.pkgVersion;
        version (UseStringUUIDs) {
            spec.productCode = "00000000-0000-0000-0000-000000000001";
            spec.upgradeCode = "00000000-0000-0000-0000-000000000002";
        }
        spec.rootFolder = FolderSpec("INSTALLDIR", info.name, "", []);

        ComponentSpec component;
        component.id = "MainComponent";
        component.directoryId = spec.rootFolder.id;
        version (UseStringUUIDs) component.guid = "00000000-0000-0000-0000-000000000003";
        if (info.executablePath.length)
            component.files ~= FileSpec("MainExecutable", info.executablePath, info.executablePath.baseName);
        foreach (i, file; info.extraFiles)
            component.files ~= FileSpec("ExtraFile" ~ i.to!string, file, file.baseName);
        spec.components ~= component;

        FeatureSpec feature;
        feature.id = "Complete";
        feature.title = info.name;
        feature.description = info.description;
        feature.componentIds = [component.id];
        spec.features ~= feature;
        new MsiDatabase(spec).save(outputPath);
    }
}
