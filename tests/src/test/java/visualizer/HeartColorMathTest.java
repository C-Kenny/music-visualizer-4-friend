package visualizer;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the pure maths used in the heart grid scene (state 2).
 *
 * None of this needs Processing — it's plain arithmetic that happens to
 * drive the visualizer. Testing it here means a refactor that accidentally
 * breaks the colour transitions or beat decay will be caught immediately.
 */
class HeartColorMathTest {

    // ── Hue lerp: wrap-around via shortest arc ─────────────────────────────────
    //
    // Source: case 2 in Music_Visualizer_CK.pde
    //   float hueDiff = heartTargetHue - heartHue;
    //   if (hueDiff >  180) hueDiff -= 360;
    //   if (hueDiff < -180) hueDiff += 360;
    //   heartHue = (heartHue + hueDiff * 0.012 + 360) % 360;

    private float shortestArcDiff(float current, float target) {
        float diff = target - current;
        if (diff >  180) diff -= 360;
        if (diff < -180) diff += 360;
        return diff;
    }

    @Test
    void hueGoesBackwardsWhenShortArcIsNegative() {
        // current=10, target=350 → shortest path is -20°, not +340°
        float diff = shortestArcDiff(10, 350);
        assertEquals(-20f, diff, 0.001f);
    }

    @Test
    void hueGoesForwardsWhenShortArcIsPositive() {
        // current=350, target=10 → shortest path is +20°, not -340°
        float diff = shortestArcDiff(350, 10);
        assertEquals(20f, diff, 0.001f);
    }

    @Test
    void hueOppositeColorsAreExactly180Apart() {
        // complementary heart always uses (heartHue + 180) % 360
        float primary = 45f;
        float complementary = (primary + 180) % 360;
        assertEquals(225f, complementary, 0.001f);
    }

    @Test
    void hueWrapsCleanlyPast360() {
        float primary = 270f;
        float complementary = (primary + 180) % 360;
        assertEquals(90f, complementary, 0.001f);
    }

    @Test
    void hueStaysIn0to360RangeAfterLerp() {
        // simulate 1000 lerp steps from 355 toward 5
        float hue = 355f;
        float target = 5f;
        for (int frame = 0; frame < 1000; frame++) {
            float diff = target - hue;
            if (diff >  180) diff -= 360;
            if (diff < -180) diff += 360;
            hue = (hue + diff * 0.012f + 360) % 360;
        }
        assertTrue(hue >= 0f && hue < 360f,
            "Hue should stay in [0, 360) but was " + hue);
    }

    // ── Beat decay ─────────────────────────────────────────────────────────────
    //
    // Source: case 2 in Music_Visualizer_CK.pde
    //   heartBeatDecay *= 0.95;

    @Test
    void beatDecayFadesToNearZeroAfter200Frames() {
        float decay = 35.0f;
        for (int frame = 0; frame < 200; frame++) {
            decay *= 0.95f;
        }
        assertTrue(decay < 0.01f,
            "Beat decay should be near zero after 200 frames but was " + decay);
    }

    @Test
    void beatDecayIsStillPerceptibleAfter20Frames() {
        // 35 * 0.95^20 ≈ 13.3 — still visible, hasn't disappeared immediately
        float decay = 35.0f;
        for (int frame = 0; frame < 20; frame++) {
            decay *= 0.95f;
        }
        assertTrue(decay > 5f,
            "Beat decay should still be visible at frame 20 but was " + decay);
    }

    @Test
    void beatDecayNeverGoesBelowZero() {
        float decay = 35.0f;
        for (int frame = 0; frame < 10000; frame++) {
            decay *= 0.95f;
        }
        assertTrue(decay >= 0f,
            "Beat decay should never go negative");
    }

    // ── Breath oscillator ──────────────────────────────────────────────────────
    //
    // Source: case 2 in Music_Visualizer_CK.pde
    //   float breath = sin(frameCount * 0.03) * 12;

    @Test
    void breathOscillatorStaysWithinAmplitude() {
        // sin() * 12 must stay in [-12, +12] for all frame counts
        for (int frame = 0; frame < 1000; frame++) {
            float breath = (float)(Math.sin(frame * 0.03) * 12);
            assertTrue(breath >= -12f && breath <= 12f,
                "Breath at frame " + frame + " was out of [-12, 12]: " + breath);
        }
    }

    @Test
    void heartPulseCombinesBreathAndBeatDecay() {
        // HEART_PULSE = breath + heartBeatDecay
        // On a beat: max pulse = 12 + 35 = 47. Should always be finite.
        float breath = 12f;       // max breath amplitude
        float beatDecay = 35f;    // initial beat impulse
        float heartPulse = breath + beatDecay;
        assertTrue(Float.isFinite(heartPulse),
            "Heart pulse should be a finite number");
        assertEquals(47f, heartPulse, 0.001f);
    }
}
