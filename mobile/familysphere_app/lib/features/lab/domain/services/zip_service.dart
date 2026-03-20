import 'dart:io';
import 'lab_file_manager.dart';

// ─── TYPED ERRORS ────────────────────────────────────────────────────────────

abstract class ZipError implements Exception {
  final String userMessage;
  const ZipError(this.userMessage);
  @override
  String toString() => userMessage;
}

class ZipFileError extends ZipError {
  const ZipFileError(super.userMessage);
}

class ZipProcessError extends ZipError {
  const ZipProcessError(super.userMessage);
}

// ─── RESULT ─────────────────────────────────────────────────────────────────

class ZipResult {
  final String outputPath;
  final int outputSizeBytes;
  final int fileCount;
  final Duration duration;

  const ZipResult({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.fileCount,
    required this.duration,
  });
}

class UnzipResult {
  final String outputDirPath;
  final List<String> extractedFiles;
  final int totalSizeBytes;
  final Duration duration;

  const UnzipResult({
    required this.outputDirPath,
    required this.extractedFiles,
    required this.totalSizeBytes,
    required this.duration,
  });
}

// ─── ZIP SERVICE ────────────────────────────────────────────────────────────

class ZipService {
  final LabFileManager _fileManager;

  ZipService({LabFileManager? fileManager})
      : _fileManager = fileManager ?? LabFileManager();

  /// Creates a ZIP file from multiple input files using dart:io's GZip.
  /// Note: For simplicity, we create a tar.gz-like archive.
  /// For real ZIP format, the `archive` package would be needed.
  Future<ZipResult> zipFiles({
    required List<File> inputFiles,
    required String outputFileName,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (inputFiles.isEmpty) {
      throw const ZipFileError('No files selected to compress.');
    }

    onProgress?.call(0.1, 'Preparing files...');

    final outputDir = await _fileManager.getOutputDir('ZipFiles');
    var baseName = outputFileName;
    if (baseName.contains('.')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }

    final outputPath = await _fileManager.generateUniqueOutputPath(
      outputDir, baseName, '.zip',
    );

    // Create a simple ZIP-like archive using GZip compression
    // We'll concatenate files with headers
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();

    try {
      for (int i = 0; i < inputFiles.length; i++) {
        onProgress?.call(
          0.1 + 0.8 * (i / inputFiles.length),
          'Compressing file ${i + 1} of ${inputFiles.length}...',
        );

        final file = inputFiles[i];
        if (!await file.exists()) continue;

        final fileName = file.path.split(Platform.pathSeparator).last;
        final fileBytes = await file.readAsBytes();

        // Write file entry: [name_length(4 bytes)][name][data_length(4 bytes)][data]
        final nameBytes = fileName.codeUnits;
        sink.add(_intToBytes(nameBytes.length));
        sink.add(nameBytes);
        sink.add(_intToBytes(fileBytes.length));

        // Compress data with GZip
        final compressed = GZipCodec().encode(fileBytes);
        sink.add(_intToBytes(compressed.length));
        sink.add(compressed);
      }

      await sink.flush();
      await sink.close();

      final outputSize = await outputFile.length();

      stopwatch.stop();
      onProgress?.call(1.0, 'Done!');

      return ZipResult(
        outputPath: outputPath,
        outputSizeBytes: outputSize,
        fileCount: inputFiles.length,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      await sink.close();
      if (e is ZipError) rethrow;
      throw ZipProcessError('Failed to create archive: ${e.toString()}');
    }
  }

  /// Extracts files from a compressed archive.
  Future<UnzipResult> unzipFile({
    required File inputFile,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!await inputFile.exists()) {
      throw const ZipFileError('Archive file not found.');
    }

    onProgress?.call(0.1, 'Reading archive...');

    final outputDir = await _fileManager.getOutputDir('UnzipFiles');
    final inputName = inputFile.path.split(Platform.pathSeparator).last;
    final extractDir = Directory('${outputDir.path}/${inputName.replaceAll('.', '_')}_extracted');
    await extractDir.create(recursive: true);

    final bytes = await inputFile.readAsBytes();
    final extractedFiles = <String>[];
    int totalSize = 0;
    int offset = 0;

    try {
      while (offset < bytes.length - 8) {
        onProgress?.call(0.1 + 0.8 * (offset / bytes.length), 'Extracting files...');

        // Read name length
        final nameLen = _bytesToInt(bytes, offset);
        offset += 4;
        if (offset + nameLen > bytes.length) break;

        // Read name
        final name = String.fromCharCodes(bytes.sublist(offset, offset + nameLen));
        offset += nameLen;

        // Read original data length
        final dataLen = _bytesToInt(bytes, offset);
        offset += 4;

        // Read compressed data length
        final compressedLen = _bytesToInt(bytes, offset);
        offset += 4;
        if (offset + compressedLen > bytes.length) break;

        // Read and decompress data
        final compressedData = bytes.sublist(offset, offset + compressedLen);
        offset += compressedLen;

        final decompressed = GZipCodec().decode(compressedData);

        final outFile = File('${extractDir.path}/$name');
        await outFile.writeAsBytes(decompressed);
        extractedFiles.add(outFile.path);
        totalSize += decompressed.length;
      }

      stopwatch.stop();
      onProgress?.call(1.0, 'Done!');

      return UnzipResult(
        outputDirPath: extractDir.path,
        extractedFiles: extractedFiles,
        totalSizeBytes: totalSize,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      if (e is ZipError) rethrow;
      throw ZipProcessError('Failed to extract archive: ${e.toString()}');
    }
  }

  List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  int _bytesToInt(List<int> bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
