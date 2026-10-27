Everything that is on `export/` folder will be pasted into `.build/`.
Everything that is on the current folder (`internal/build/`) will be used by the functions on the export folder, it is a pipeline for the `export/` files.
The export has to be the bridge between the project and the engine, and the build has be a fixed pipeline using the engine internal code.
