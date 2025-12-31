(*
    This AppleScript is designed to be attached as a Folder Action to the user's Desktop (or any folder).
    It automatically triggers whenever new items are added to that folder.

    **Purpose**
    - The script detects when macOS creates a new screenshot file on the Desktop.
    - It specifically matches files whose names begin with "Screenshot" and end with ".png".
      (This corresponds to the default macOS screenshot naming convention, e.g.,
       "Screenshot 2025-12-31 at 09.00.00.png".)
    - When a matching file is detected, the script runs an external shell script located at:
        ~/bin/wrapper-claude-image-renamer.sh
      passing the newly added file's full path as an argument.

    **How It Works**
    1. The system invokes the Folder Action when new items appear in the watched folder.
    2. For each added item:
        - The script gets its POSIX path and extracts just the filename (`basename`).
        - It checks that the file name starts with "Screenshot" and ends with ".png".
        - Using `test -f`, it verifies the item is a regular file (not a directory).
        - If the checks succeed, it executes the external shell script (`do shell script`),
          allowing the shell to expand `~` to the user’s home directory.
    3. Non-screenshot items (other files, folders, or differently named images) are ignored.

    **Key Notes**
    - The matching is *case‑sensitive*: only exact “Screenshot*.png” filenames trigger it.
    - The external script path uses `~`, which is expanded by the shell to $HOME.
    - Errors (such as race conditions or temporary filesystem states) are caught silently
      by the `try` block to prevent AppleScript alerts.

    Attach this script to your Desktop folder using:
      *Folder Actions Setup.app* → Enable Folder Actions → Add Desktop → Attach this script.
*)

on adding folder items to this_folder after receiving added_items
    repeat with anItem in added_items
        set itemPath to (POSIX path of anItem)
        try
            -- Get the file name from the full path
            set baseName to do shell script "basename " & quoted form of itemPath

            -- Only run if name matches Screenshot*.png exactly (case-sensitive)
            if baseName starts with "Screenshot" and baseName ends with ".png" then
                -- Confirm it's a regular file (not a folder)
                set isFile to (do shell script "test -f " & quoted form of itemPath & "; echo $?")
                if isFile is "0" then
					do shell script "~/bin/wrapper-claude-image-renamer.sh " & quoted form of itemPath
                end if
            end if
        end try
    end repeat
end adding folder items to
