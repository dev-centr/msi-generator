module msigen.common;

struct PackageInfo {
    string name;
    string id;
    string pkgVersion;
    string publisher;
    string description;
    string executablePath;
    /// Additional payload files placed at the package root by their base name.
    string[] extraFiles;
}

interface PackageGenerator {
    void generate(PackageInfo info, string outputPath);
}
