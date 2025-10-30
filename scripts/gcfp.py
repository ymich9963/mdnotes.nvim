import platform

def get_clipboard_file_paths():
    system = platform.system()

    if system == "Windows":
        import win32clipboard
        import win32con

        win32clipboard.OpenClipboard()
        try:
            if win32clipboard.IsClipboardFormatAvailable(win32con.CF_HDROP):
                files = win32clipboard.GetClipboardData(win32con.CF_HDROP)
                return list(files)
            else:
                return None
        finally:
            win32clipboard.CloseClipboard()

    elif system == "Darwin":  # macOS
        import subprocess
        try:
            result = subprocess.run(
                ["osascript", "-e", "the clipboard as «class furl»"],
                capture_output=True, text=True
            )
            output = result.stdout.strip()
            if output.startswith("file:"):
                # Decode AppleScript's file URL format
                path = output.replace("file://", "")
                return [path]
        except Exception:
            return None

    elif system == "Linux":
        # For Linux, we'll use 'gtk' or 'xclip'/'xsel' depending on what's installed
        try:
            import gi
            gi.require_version("Gtk", "3.0")
            from gi.repository import Gtk

            clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
            text = clipboard.wait_for_text()
            if text:
                return [text.strip()]
        except Exception:
            try:
                import subprocess
                result = subprocess.run(["xclip", "-o"], capture_output=True, text=True)
                if result.returncode == 0:
                    text = result.stdout.strip()
                    return [text]
            except Exception:
                return None
    else:
        raise NotImplementedError(f"Unsupported OS: {system}")

    return None


if __name__ == "__main__":
    paths = get_clipboard_file_paths()
    if paths:
        for p in paths:
            print(p)
    else:
        print("None")

