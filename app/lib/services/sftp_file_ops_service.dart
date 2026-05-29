import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import '../models/host.dart';
import 'ssh_service.dart';

class SftpFileOpsService {
  final SshService _sshService;

  SftpFileOpsService(this._sshService);

  Future<void> rename(Host host, String oldPath, String newPath) async {
    final sftp = await _sshService.openSftp(host);
    try {
      await sftp.rename(oldPath, newPath);
    } finally {
      sftp.close();
    }
  }

  Future<void> mkdir(Host host, String path) async {
    final sftp = await _sshService.openSftp(host);
    try {
      await sftp.mkdir(path);
    } finally {
      sftp.close();
    }
  }

  Future<void> delete(Host host, String path, {required bool isDirectory}) async {
    final sftp = await _sshService.openSftp(host);
    try {
      if (isDirectory) {
        await _deleteRecursive(sftp, path);
      } else {
        await sftp.remove(path);
      }
    } finally {
      sftp.close();
    }
  }

  Future<void> _deleteRecursive(SftpClient sftp, String path) async {
    final items = await sftp.listdir(path);
    for (final item in items) {
      if (item.filename == '.' || item.filename == '..') continue;
      final child = p.posix.join(path, item.filename);
      if (item.attr.isDirectory) {
        await _deleteRecursive(sftp, child);
      } else {
        await sftp.remove(child);
      }
    }
    await sftp.rmdir(path);
  }
}
