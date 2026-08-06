module msigen.msix;

import msigen.common;
import std.zip;
import std.file;
import std.path;
import std.format;
import std.exception : enforce;

/**
 * Emits a structurally complete ZIP-based MSIX payload. It intentionally does
 * not sign the package; callers can sign the resulting archive separately.
 */
class MsixGenerator : PackageGenerator {
    void generate(PackageInfo info, string outputPath) {
        auto zip = new ZipArchive();
        
        // Add AppxManifest.xml
        auto manifest = createManifest(info);
        auto manifestEntry = new ArchiveMember();
        manifestEntry.name = "AppxManifest.xml";
        manifestEntry.expandedData = cast(ubyte[])manifest;
        zip.addMember(manifestEntry);
        
        // Put the primary executable and each additional file at the package
        // root. PackageInfo uses source paths so plugins can assemble a payload
        // without copying files to a staging directory first.
        if (info.executablePath.exists) {
            addFile(zip, info.executablePath);
        }
        foreach (file; info.extraFiles) {
            enforce(file.exists, "MSIX extra file does not exist: " ~ file);
            addFile(zip, file);
        }
        addAsset(zip, "Assets/StoreLogo.png");
        addAsset(zip, "Assets/Square150x150Logo.png");
        addAsset(zip, "Assets/Square44x44Logo.png");
        addAsset(zip, "Assets/Wide310x150Logo.png");
        
        // Write the zip file
        std.file.write(outputPath, zip.build());
    }

    private void addFile(ZipArchive zip, string path) {
        auto entry = new ArchiveMember();
        entry.name = path.baseName;
        entry.expandedData = cast(ubyte[])read(path);
        zip.addMember(entry);
    }

    private void addAsset(ZipArchive zip, string path) {
        // Valid transparent 1×1 PNG. Distinct scale-specific artwork can
        // replace these placeholders after package generation.
        immutable ubyte[] transparentPng = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
            0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99,
            0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
            0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ];
        auto entry = new ArchiveMember();
        entry.name = path;
        entry.expandedData = transparentPng.dup;
        zip.addMember(entry);
    }

    private string createManifest(PackageInfo info) {
        return format!`<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10" 
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10" 
         IgnorableNamespaces="uap">
  <Identity Name="%s" Version="%s" Publisher="%s" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>%s</DisplayName>
    <PublisherDisplayName>%s</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Resources>
    <Resource Language="en-us" />
  </Resources>
  <Applications>
    <Application Id="App" Executable="%s" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="%s" Description="%s" 
                          BackgroundColor="#464646" Square150x150Logo="Assets\Square150x150Logo.png" 
                          Square44x44Logo="Assets\Square44x44Logo.png">
        <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png" />
      </uap:VisualElements>
    </Application>
  </Applications>
</Package>`(info.id, info.pkgVersion, info.publisher, info.name, info.publisher, info.executablePath.baseName, info.name, info.description);
    }
}
