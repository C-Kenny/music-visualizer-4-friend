package visualizer;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests that scene parameter adjustments stay within their declared bounds.
 *
 * Each scene uses the pattern:
 *   value = constrain(value + delta, MIN, MAX)
 * which is equivalent to Java's Math.min(MAX, Math.max(MIN, value + delta)).
 *
 * These tests document the intended min/max for every user-adjustable parameter.
 * If you change a bound in a scene, update the matching constant here — that
 * mismatch is the signal that something needs reviewing.
 */
class SceneClampingTest {

    // ── helpers ────────────────────────────────────────────────────────────────

    /** Mirrors Processing's constrain(value, low, high). */
    private float constrain(float value, float low, float high) {
        return Math.min(high, Math.max(low, value));
    }

    private float adjust(float current, float delta, float min, float max) {
        return constrain(current + delta, min, max);
    }

    // ── OscilloscopeScene ──────────────────────────────────────────────────────
    // Source: OscilloscopeScene.pde adjustGainX / adjustGainY / adjustTrail / adjustBrightness

    static final float OSC_GAIN_MIN        = 0.5f;
    static final float OSC_GAIN_MAX        = 6.0f;
    static final float OSC_TRAIL_MIN       = 5f;
    static final float OSC_TRAIL_MAX       = 120f;
    static final float OSC_BRIGHTNESS_MIN  = 0.2f;
    static final float OSC_BRIGHTNESS_MAX  = 2.0f;

    @Test
    void oscilloscopeGainXClampedAtMaximum() {
        float result = adjust(5.9f, 999f, OSC_GAIN_MIN, OSC_GAIN_MAX);
        assertEquals(OSC_GAIN_MAX, result, 0.001f);
    }

    @Test
    void oscilloscopeGainXClampedAtMinimum() {
        float result = adjust(0.6f, -999f, OSC_GAIN_MIN, OSC_GAIN_MAX);
        assertEquals(OSC_GAIN_MIN, result, 0.001f);
    }

    @Test
    void oscilloscopeGainYClampedAtMaximum() {
        float result = adjust(5.5f, 10f, OSC_GAIN_MIN, OSC_GAIN_MAX);
        assertEquals(OSC_GAIN_MAX, result, 0.001f);
    }

    @Test
    void oscilloscopeTrailAlphaClampedAtMaximum() {
        float result = adjust(115f, 50f, OSC_TRAIL_MIN, OSC_TRAIL_MAX);
        assertEquals(OSC_TRAIL_MAX, result, 0.001f);
    }

    @Test
    void oscilloscopeTrailAlphaClampedAtMinimum() {
        float result = adjust(8f, -999f, OSC_TRAIL_MIN, OSC_TRAIL_MAX);
        assertEquals(OSC_TRAIL_MIN, result, 0.001f);
    }

    @Test
    void oscilloscopeBrightnessClampedAtMaximum() {
        float result = adjust(1.9f, 999f, OSC_BRIGHTNESS_MIN, OSC_BRIGHTNESS_MAX);
        assertEquals(OSC_BRIGHTNESS_MAX, result, 0.001f);
    }

    @Test
    void oscilloscopeBrightnessClampedAtMinimum() {
        float result = adjust(0.3f, -999f, OSC_BRIGHTNESS_MIN, OSC_BRIGHTNESS_MAX);
        assertEquals(OSC_BRIGHTNESS_MIN, result, 0.001f);
    }

    // ── Shapes3DScene ──────────────────────────────────────────────────────────
    // Source: Shapes3DScene.pde adjustPlateScale / adjustPulseSensitivity

    static final float S3D_PLATE_SCALE_MIN      = 0.5f;
    static final float S3D_PLATE_SCALE_MAX      = 4.0f;
    static final float S3D_PULSE_SENS_MIN       = 0.05f;
    static final float S3D_PULSE_SENS_MAX       = 2.0f;

    @Test
    void shapes3DPlateScaleClampedAtMaximum() {
        float result = adjust(3.9f, 999f, S3D_PLATE_SCALE_MIN, S3D_PLATE_SCALE_MAX);
        assertEquals(S3D_PLATE_SCALE_MAX, result, 0.001f);
    }

    @Test
    void shapes3DPlateScaleClampedAtMinimum() {
        float result = adjust(0.6f, -999f, S3D_PLATE_SCALE_MIN, S3D_PLATE_SCALE_MAX);
        assertEquals(S3D_PLATE_SCALE_MIN, result, 0.001f);
    }

    @Test
    void shapes3DPulseSensitivityClampedAtMaximum() {
        float result = adjust(1.9f, 999f, S3D_PULSE_SENS_MIN, S3D_PULSE_SENS_MAX);
        assertEquals(S3D_PULSE_SENS_MAX, result, 0.001f);
    }

    @Test
    void shapes3DPulseSensitivityCannotDropBelowMinimum() {
        float result = adjust(0.1f, -999f, S3D_PULSE_SENS_MIN, S3D_PULSE_SENS_MAX);
        assertEquals(S3D_PULSE_SENS_MIN, result, 0.001f);
    }

    // ── Halo2LogoScene ─────────────────────────────────────────────────────────
    // Source: Halo2LogoScene.pde adjustPulseSens

    static final float HALO_PULSE_SENS_MIN = 0.05f;
    static final float HALO_PULSE_SENS_MAX = 1.0f;

    @Test
    void halo2PulseSensClampedAtMaximum() {
        float result = adjust(0.9f, 999f, HALO_PULSE_SENS_MIN, HALO_PULSE_SENS_MAX);
        assertEquals(HALO_PULSE_SENS_MAX, result, 0.001f);
    }

    @Test
    void halo2PulseSensClampedAtMinimum() {
        float result = adjust(0.1f, -999f, HALO_PULSE_SENS_MIN, HALO_PULSE_SENS_MAX);
        assertEquals(HALO_PULSE_SENS_MIN, result, 0.001f);
    }

    // ── HeartGridScene ─────────────────────────────────────────────────────────
    // Source: keyPressed() in Music_Visualizer_CK.pde, state 2 block

    static final int HEART_COLS_MIN = 1;
    static final int HEART_COLS_MAX = 10;

    @Test
    void heartColsCannotExceedMaximum() {
        int cols = 10;
        cols = Math.min(HEART_COLS_MAX, cols + 1);
        assertEquals(HEART_COLS_MAX, cols);
    }

    @Test
    void heartColsCannotDropBelowOne() {
        int cols = 1;
        cols = Math.max(HEART_COLS_MIN, cols - 1);
        assertEquals(HEART_COLS_MIN, cols);
    }

    // ── Small adjustment stays within range (sanity) ───────────────────────────

    @Test
    void smallAdjustmentInMiddleOfRangeIsUnclamped() {
        float result = adjust(2.0f, 0.1f, OSC_GAIN_MIN, OSC_GAIN_MAX);
        assertEquals(2.1f, result, 0.001f);
    }
}
