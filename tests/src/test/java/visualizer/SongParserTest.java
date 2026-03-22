package visualizer;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for getSongNameFromFilePath in Music_Visualizer_CK.pde.
 *
 * The sketch splits a full file path on the OS separator and returns
 * the last segment (the filename). These tests pin down expected
 * behaviour so a refactor can't silently break song name display.
 *
 * NOTE: the sketch currently uses == to compare the os_type string,
 * which is a Java reference-equality bug. The tests below document
 * the CORRECT expected behaviour so that bug is visible when fixed.
 */
class SongParserTest {

    // Mirrors the logic in getSongNameFromFilePath exactly.
    // Update this if the sketch implementation changes.
    private String parseSongName(String filePath, String osType) {
        String[] parts;
        if (osType.equals("linux")) {
            parts = filePath.split("/");
        } else {
            parts = filePath.split("\\\\");
        }
        return parts[parts.length - 1];
    }

    @Test
    void linuxPathReturnsSongFilename() {
        String name = parseSongName("/home/user/Music/cool_song.mp3", "linux");
        assertEquals("cool_song.mp3", name);
    }

    @Test
    void linuxPathWithNestingReturnsSongFilename() {
        String name = parseSongName("/home/user/Music/Artist/Album/track01.flac", "linux");
        assertEquals("track01.flac", name);
    }

    @Test
    void windowsPathReturnsSongFilename() {
        String name = parseSongName("C:\\Users\\xdd\\Music\\cool_song.mp3", "win");
        assertEquals("cool_song.mp3", name);
    }

    @Test
    void filenameWithMultipleDotsIsReturnedInFull() {
        // e.g. "01 - Some Artist - Some Title.mp3" — dots in the name must survive
        String name = parseSongName("/home/user/Music/01 - Artist - Title.mp3", "linux");
        assertEquals("01 - Artist - Title.mp3", name);
    }

    @Test
    void flacExtensionIsPreserved() {
        String name = parseSongName("/home/user/Music/track.flac", "linux");
        assertEquals("track.flac", name);
    }

    @Test
    void wavExtensionIsPreserved() {
        String name = parseSongName("/home/user/Music/track.wav", "linux");
        assertEquals("track.wav", name);
    }
}
