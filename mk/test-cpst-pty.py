"""Capture OSC 52 in a private PTY; never send it to a user's terminal."""
import errno
import os
from pathlib import Path
import pty
import subprocess
import sys

command, root = sys.argv[1:]
backend = Path(root) / "osc-bin"
backend.mkdir()
(backend / "tr").symlink_to("/usr/bin/tr")
encoder = backend / "base64"
env = {"HOME": root, "PATH": str(backend), "SSH_CONNECTION": "fixture"}


def capture(input_file):
    pid, terminal = pty.fork()
    if pid == 0:
        with open(input_file, "rb") as source:
            os.dup2(source.fileno(), 0)
        os.execve(command, [command], env)
    output = bytearray()
    try:
        while True:
            try:
                chunk = os.read(terminal, 4096)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not chunk:
                break
            output.extend(chunk)
    finally:
        os.close(terminal)
    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status), bytes(output)


encoder.write_text("#!/bin/sh\nexit 7\n")
encoder.chmod(0o755)
rc, output = capture(Path(root) / "text")
assert rc == 7 and b"\x1b]52;" not in output, (rc, output)
encoder.unlink()
encoder.symlink_to("/usr/bin/base64")
rc, output = capture(Path(root) / "text")
assert rc == 0 and output == b"\x1b]52;c;dGV4dAoK\x07", (rc, output)
result = subprocess.run([command], input=b"text", env=env, start_new_session=True,
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
assert result.returncode != 0 and not result.stdout, result
assert b"no controlling terminal" in result.stderr, result.stderr
print("check-cpst: OSC 52 bytes, encoding failure, and missing terminal ok")
