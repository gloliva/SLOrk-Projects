public class Wind {
        Envelope L;
        Envelope R;

        CNoise nL("white") => LPF filterL => Envelope noiseEnvL => L;
        CNoise nR("pink") => LPF filterR => Envelope noiseEnvR => R;

        SinOsc sL(1000.) => Envelope sinEnvL => L;
        SinOsc sR(1010.) => Envelope sinEnvR => R;

        SinOsc bass(40.) => Envelope bassEnv => L;
        bassEnv => R;

    fun @construct() {
        0.3 => sL.gain => sR.gain;
    }

    fun void freq(float xL, float xR) {
        Std.scalef(xL, -1., 1., 400., 1000.) => this.filterL.freq;
        Std.scalef(xR, -1., 1., 3000., 2000.) => this.filterR.freq;

        Std.scalef(xL, -1., 1., 980, 1020) => sL.freq;
        Std.scalef(xR, -1., 1., 970, 1030) => sR.freq;
    }

    fun void swell(float yL, float yR) {
        Math.clampf(Std.scalef(yL, -1., 1., 0.3, 1.5), 0., 1.5) => this.nL.gain;
        Math.clampf(Std.scalef(yR, -1., 1., 0.3, 1.5), 0., 1.5) => this.nR.gain;
    }

    fun void gain(float zL, float zR) {
        Math.clampf(zL, 0., 1.) => this.L.gain;
        Math.clampf(zR, 0., 1.) => this.R.gain;
    }
}


public class Harpie {
    TriOsc oscL => ABSaturator satL => Bitcrusher bcL => Envelope oscEnvL;
    TriOsc oscR => ABSaturator satR => Bitcrusher bcR => Envelope oscEnvR;

    NRev revL => Envelope L;
    NRev revR => Envelope R;

    oscEnvL => revL;
    oscEnvR => revR;

    dur sustain;
    dur silence;

    fun @construct() {
        0.2 => revL.mix => revR.mix;
        0.3 => oscL.gain => oscR.gain;

        20 => satL.drive => satR.drive;
        4 => satL.dcOffset => satR.dcOffset;
        6 => bcL.bits => bcR.bits;

        Math.random2(20, 100)::ms => sustain;
        Math.random2(20, 100)::ms => silence;

        spork ~ this.run();
    }

    fun void freq(float xL, float xR) {
        Std.scalef(xL, -1., 1., 1996, 2026) => oscL.freq;
        Std.scalef(xR, -1., 1., 1998, 2025) => oscR.freq;
    }

    fun void drive(float yL, float yR) {
        Std.scalef(yL, -1., 1., 20, 100) => satL.drive;
        Std.scalef(yR, -1., 1., 20, 100) => satR.drive;

        Std.scalef(yL, -1., 1., 100, 20)::ms => sustain;
        Std.scalef(yR, -1., 1., 100, 20)::ms => silence;
    }

    fun void gain(float zL, float zR) {
        Math.clampf(zL, 0., 1.) => this.L.gain;
        Math.clampf(zR, 0., 1.) => this.R.gain;
    }

    fun void run() {
        time start;

        while (true) {
            oscEnvL.ramp(5::ms, 1.);
            oscEnvR.ramp(5::ms, 1.);

            // 50::ms => now;
            now => start;
            while (now < start + sustain) {
                1::ms => now;
            }

            oscEnvL.ramp(5::ms, 0.);
            oscEnvR.ramp(5::ms, 0.);

            // 50::ms => now;
            now => start;
            while (now < start + silence) {
                1::ms => now;
            }
        }
    }
}
