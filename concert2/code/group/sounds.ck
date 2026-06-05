public class Wind {
    Envelope L;
    Envelope R;

    CNoise nL("white") => LPF filterL => Envelope noiseEnvL => L;
    CNoise nR("pink") => LPF filterR => Envelope noiseEnvR => R;

    SinOsc sL(1000.) => Envelope sinEnvL => L;
    SinOsc sR(1010.) => Envelope sinEnvR => R;

    SinOsc fmL(1.) => Envelope fmEnvL => blackhole;
    SinOsc fmR(1.) => Envelope fmEnvR => blackhole;

    float depthL;
    float depthR;

    int performerId;
    float baseFreq;

    fun @construct(int id) {
        id => this.performerId;
        800 + (100 * id) => this.baseFreq;

        0.2 => sL.gain => sR.gain;
        0.6 => sinEnvL.gain => sinEnvR.gain;
    }

    fun void freq(float xL, float xR) {
        Std.scalef(xL, -1., 1., 400., 1000.) => this.filterL.freq;
        Std.scalef(xR, -1., 1., 3000., 2000.) => this.filterR.freq;

        // FM vals
        Std.scalef(xL, -1., 1., 40., 100.) => this.fmL.freq;
        Std.scalef(xR, -1., 1., 40., 100.) => this.fmR.freq;
        fmEnvL.value() * this.depthL => float fmLVal;
        fmEnvR.value() * this.depthR => float fmRVal;

        Std.scalef(xL, -1., 1., this.baseFreq - 20 + fmLVal, this.baseFreq + 20 + fmLVal) => sL.freq;
        Std.scalef(xR, -1., 1., this.baseFreq - 30 + fmRVal, this.baseFreq + 30 + fmRVal) => sR.freq;
    }

    fun void swell(float yL, float yR) {
        Math.clampf(Std.scalef(yL, -1., 1., 0.3, 1.5), 0., 1.5) => this.nL.gain;
        Math.clampf(Std.scalef(yR, -1., 1., 0.3, 1.5), 0., 1.5) => this.nR.gain;

        Std.scalef(yL, -1., 1., -10., 100.) => this.depthL;
        Std.scalef(yR, -1., 1., -20, 120) => this.depthR;
    }

    fun void gain(float zL, float zR) {
        Math.clampf(zL, 0., 1.) => this.L.gain;
        Math.clampf(zR, 0., 1.) => this.R.gain;
    }

    fun void sinOscGain(float g) {
        g => sinEnvL.gain => sinEnvR.gain;
    }
}


public class Vibe {
    Envelope L;
    Envelope R;

    SawOsc oscL => Chorus chL(10., 0.5, 0.6) => ADSR envL(100::ms, 250::ms, 0.7, 2::second) => L;
    SawOsc oscR => Chorus chR(50., 0.3, 0.5) => ADSR envR(100::ms, 250::ms, 0.7, 2::second) => R;

    envL => NRev revL => L;
    envR => NRev revR => R;

    PulseOsc pulseL => chL;
    PulseOsc pulseR => chR;

    envL => DelayL delL(1::second, 8::second) => L;
    envR => DelayL delR(1::second, 8::second) => R;

    delL => delR;
    delR => delL;

    int triggerL;
    int triggerR;

    int modulateSilence;
    20::ms => dur silenceDur;

    fun @construct() {

        10::ms => chL.baseDelay => chR.baseDelay;
        0.5 => delL.gain;
        0.5 => delR.gain;

        0.5 => revL.mix => revR.mix;
        0.3 => revL.gain => revR.gain;

        // Adjust gains
        0.4 => chL.gain => chR.gain;
        0.4 => envL.gain => envL.gain;

        spork ~ this.run();
    }

    fun void run() {
        while (true) {
            1. => oscL.gain;
            1. => oscR.gain;
            1. => pulseL.gain;
            1. => pulseR.gain;
            20::ms => now;

            0. => oscL.gain;
            0. => oscR.gain;
            0. => pulseL.gain;
            0. => pulseR.gain;

            now => time start;
            while (now < start + this.silenceDur) {
                1::ms => now;
            }
        }
    }

    fun void freq(float xL, float xR) {
        Std.scalef(xL, -1., 1., 100., 5000.) => this.oscL.freq;
        Std.scalef(xR, -1., 1., 150., 2000.) => this.oscR.freq;

        this.oscL.freq() * 0.96 => this.pulseL.freq;
        this.oscR.freq() * 1.03 => this.pulseR.freq;

        Std.scalef(xL, -1., 1., 0.001, 5.) => this.chL.modFreq;
        Std.scalef(xR, -1., 1., 0.1, 2.) => this.chR.modFreq;
    }

    fun void swell(float yL, float yR) {
        Std.scalef(yL, -1., 1., 1., 0.2) => this.chL.modDepth;
        Std.scalef(yR, -1., 1., 0.1, 2.) => this.chR.modDepth;

        if (modulateSilence) {
            Std.scalef(yL, -1., 1., 1000, 4)::ms => this.silenceDur;
        }
    }

    fun void trigger(float zL, float zR) {
        Std.scalef(zL, 0., 1., 0.5, 2.) => this.envL.gain;
        Std.scalef(zR, 0., 1., 0.5, 2.) => this.envR.gain;


        // Left trigger
        if (zL > 0.4 && !triggerL) {
            envL.keyOn(1);
            1 => triggerL;
        } else if (zL <= 0.4 && triggerL) {
            envL.keyOff(1);
            0 => triggerL;
        }

        // right trigger
        if (zR > 0.4 && !triggerR) {
            envR.keyOn(1);
            1 => triggerR;
        } else if (zR <= 0.4 && triggerR) {
            envR.keyOff(1);
            0 => triggerR;
        }
    }
}
