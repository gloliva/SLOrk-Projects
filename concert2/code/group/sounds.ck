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


public class Pulse {
    Envelope L;
    Envelope R;

    SinOsc oscL[3];
    SinOsc oscR[3];

    CNoise n("white");
    CNoise nL("flip") => LPF filterL => Envelope noiseEnvL => L;
    CNoise nR("xor") => HPF filterR => Envelope noiseEnvR => R;

    n => filterL;
    n => filterR;

    noiseEnvL => NRev revL => L;
    noiseEnvR => NRev revR => R;

    dur silenceL;
    dur silenceR;

    fun @construct() {
        25::ms => this.silenceL => this.silenceR;
        0.4 => this.n.gain;
        0.4 => this.nL.gain => this.nR.gain;
        0.7 => this.noiseEnvL.gain => this.noiseEnvR.gain;
        0.3 => this.revL.gain => this.revR.gain;
        0.1 => this.revL.mix => this.revR.mix;

        [140., 220., 340.] @=> float freqs[];
        [0.7, 0.5, 0.5] @=> float gains[];
        for (int i; i < oscL.size(); i++) {
            freqs[i] => oscL[i].freq => oscR[i].freq;
            gains[i] => oscL[i].gain => oscR[i].gain;
            oscL[i] => noiseEnvL;
            oscR[i] => noiseEnvR;
        }


        spork ~ this.runL();
        spork ~ this.runR();
    }

    fun void freq(float xL, float xR) {
        Std.scalef(xL, -1., 1., 500., 2000.) => this.filterL.freq;
        Std.scalef(xR, -1., 1., 500., 7000.) => this.filterR.freq;
    }

    fun void width(float yL, float yR) {
        Std.scalef(yL, -1., 1., 5000, 25)::ms => this.silenceL;
        Std.scalef(yR, -1., 1., 5000, 25)::ms => this.silenceR;
    }

    fun void gain(float zL, float zR) {
        Math.clampf(zL, 0., 1.) => this.L.gain;
        Math.clampf(zR, 0., 1.) => this.R.gain;
    }

    fun void runL() {
        time start;

        while (true) {
            this.noiseEnvL.ramp(5::ms, 1.);

            10::ms => now;

            this.noiseEnvL.ramp(250::ms, 0.);

            now => start;
            while (now < start + this.silenceL) {
                1::ms => now;
            }
        }
    }

    fun void runR() {
        time start;

        while (true) {
            this.noiseEnvR.ramp(5::ms, 1.);

            10::ms => now;

            this.noiseEnvR.ramp(250::ms, 0.);

            now => start;
            while (now < start + this.silenceR) {
                1::ms => now;
            }
        }
    }
}
