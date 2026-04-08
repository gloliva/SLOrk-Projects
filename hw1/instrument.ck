public class Instrument {
    Gain out;
}


public class PulseWidthOsc extends Instrument {
    PulseOsc osc;

    // PWM
    TriOsc pwMod;

    fun @construct() {
        this.osc => this.out;
        this.pwMod => blackhole;

        // pwm params
        0.5 => pwMod.freq;
        spork ~ this.runPWM();
    }

    fun void runPWM() {
        while (true) {
            Std.scalef(this.pwMod.last(), -1., 1., 0.3, 0.7) => float width;
            width => this.osc.width;
            1::samp => now;
        }
    }

    fun void pwmFreq(float f) {
        f => this.pwMod.freq;
    }

    fun void freq(float f) {
        f => this.osc.freq;
    }

    fun float freq() {
        return this.osc.freq();
    }

    fun void gain(float g) {
        g => this.osc.gain;
    }

    fun float gain() {
        return this.osc.gain();
    }
}


public class PWMUpdates {
    float low;
    float high;

    fun @construct(float l, float h) {
        l => this.low;
        h => this.high;
    }

    fun void set(float l, float h) {
        l => this.low;
        h => this.high;
    }
}
