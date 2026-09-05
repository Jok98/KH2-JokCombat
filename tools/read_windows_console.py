#!/usr/bin/env python3
"""Read the visible Win32 console buffer owned by another process.

The helper only requests console read access.  It is intended for retrieving
LuaBackend diagnostics without sending input to the game or its console.
"""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes


GENERIC_READ = 0x80000000
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
OPEN_EXISTING = 3
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value


class COORD(ctypes.Structure):
    _fields_ = [("X", wintypes.SHORT), ("Y", wintypes.SHORT)]


class SMALL_RECT(ctypes.Structure):
    _fields_ = [
        ("Left", wintypes.SHORT),
        ("Top", wintypes.SHORT),
        ("Right", wintypes.SHORT),
        ("Bottom", wintypes.SHORT),
    ]


class CONSOLE_SCREEN_BUFFER_INFO(ctypes.Structure):
    _fields_ = [
        ("dwSize", COORD),
        ("dwCursorPosition", COORD),
        ("wAttributes", wintypes.WORD),
        ("srWindow", SMALL_RECT),
        ("dwMaximumWindowSize", COORD),
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", required=True, type=int)
    parser.add_argument("--last", default=500, type=int)
    parser.add_argument("--contains")
    args = parser.parse_args()

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.FreeConsole.argtypes = []
    kernel32.FreeConsole.restype = wintypes.BOOL
    kernel32.AttachConsole.argtypes = [wintypes.DWORD]
    kernel32.AttachConsole.restype = wintypes.BOOL
    kernel32.CreateFileW.argtypes = [
        wintypes.LPCWSTR,
        wintypes.DWORD,
        wintypes.DWORD,
        wintypes.LPVOID,
        wintypes.DWORD,
        wintypes.DWORD,
        wintypes.HANDLE,
    ]
    kernel32.CreateFileW.restype = wintypes.HANDLE
    kernel32.GetConsoleScreenBufferInfo.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(CONSOLE_SCREEN_BUFFER_INFO),
    ]
    kernel32.GetConsoleScreenBufferInfo.restype = wintypes.BOOL
    kernel32.ReadConsoleOutputCharacterW.argtypes = [
        wintypes.HANDLE,
        wintypes.LPWSTR,
        wintypes.DWORD,
        COORD,
        ctypes.POINTER(wintypes.DWORD),
    ]
    kernel32.ReadConsoleOutputCharacterW.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    kernel32.FreeConsole()
    if not kernel32.AttachConsole(args.pid):
        raise ctypes.WinError(ctypes.get_last_error())

    handle = kernel32.CreateFileW(
        "CONOUT$",
        GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        None,
        OPEN_EXISTING,
        0,
        None,
    )
    if handle == INVALID_HANDLE_VALUE:
        raise ctypes.WinError(ctypes.get_last_error())

    try:
        info = CONSOLE_SCREEN_BUFFER_INFO()
        if not kernel32.GetConsoleScreenBufferInfo(handle, ctypes.byref(info)):
            raise ctypes.WinError(ctypes.get_last_error())

        width = int(info.dwSize.X)
        last_row = int(info.dwCursorPosition.Y)
        first_row = max(0, last_row - max(1, args.last) + 1)
        physical_lines: list[str] = []

        for row in range(first_row, last_row + 1):
            buffer = ctypes.create_unicode_buffer(width)
            read_count = wintypes.DWORD()
            ok = kernel32.ReadConsoleOutputCharacterW(
                handle,
                buffer,
                width,
                COORD(0, row),
                ctypes.byref(read_count),
            )
            if not ok:
                raise ctypes.WinError(ctypes.get_last_error())
            physical_lines.append(buffer[: read_count.value].rstrip())

        lines: list[str] = []
        pending = ""
        for line in physical_lines:
            pending += line
            if len(line) == width:
                continue
            if pending and (args.contains is None or args.contains in pending):
                lines.append(pending)
            pending = ""

        if pending and (args.contains is None or args.contains in pending):
            lines.append(pending)

        print("\n".join(lines))
    finally:
        kernel32.CloseHandle(handle)
        kernel32.FreeConsole()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
