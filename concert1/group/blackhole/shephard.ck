@import "../lib/global.ck"
@import "../lib/util.ck"


public class ShepardGenerator {
    // Parameters to make this work that I don't understand
    float MU;
    float SIGMA;
    float SCALE;
    float INC;

    dur T;

    // Pitch info
    float pitches[];
    int numPitches;

    // UGens
    Gain gains[];
    KrstlChr tones[];
    BeeThree organs[];

    // Effects
    Chorus chs[];
    NRev revs[];
    Envelope envs[];

    // GameTrak
    GameTrak @ gt;

    // state params
    int senderStation;

    fun @construct(int senderStation, GameTrak gt) {
        senderStation => this.senderStation;
        gt @=> this.gt;

        // mean for normal intensity curve
        66 => this.MU;
        // standard deviation for normal intensity curve
        42 => this.SIGMA;
        // normalize to 1.0 at x==MU
        1 / Math.gauss(MU, MU, SIGMA) => this.SCALE;
        // increment per unit time (use negative for descending)
        -.004 => this.INC;
        // unit time (change interval)
        10::ms => this.T;

        // starting pitches (in MIDI note numbers, octaves apart)
        [ 12.0, 24, 36, 48, 60, 72, 84, 96, 108 ] @=> this.pitches;
        // number of tones
        pitches.size() => this.numPitches;
        // bank of tones
        Gain gains[this.numPitches] @=> this.gains;
        Chorus chs[this.numPitches] @=> this.chs;
        NRev revs[this.numPitches] @=> this.revs;
        Envelope envs[this.numPitches] @=> this.envs;

        KrstlChr tones[this.numPitches] @=> this.tones;
        BeeThree organs[this.numPitches] @=> this.organs;

        for( int i; i < this.numPitches; i++ ) {
            1 => this.tones[i].noteOn;
            1 => this.organs[i].noteOn;
            1. => this.envs[i].value;

            1 / this.numPitches => this.gains[i].gain;
            this.tones[i] => this.gains[i] => this.chs[i] => this.revs[i] => this.envs[i] => dac.chan(i % dac.channels());
            this.organs[i] => this.gains[i];
        }

        // Run
        spork ~ this.run();
        // spork ~ this.stopSound();
        // spork ~ this.gtHandler();
    }

    fun void chorus(float freq, float depth, float mix) {
        for (int i; i < this.numPitches; i++) {
            freq => this.chs[i].modFreq;
            depth => this.chs[i].modDepth;
            mix => this.chs[i].mix;
        }
    }

    fun void gain(float g) {
        for (int i; i < this.numPitches; i++) {
            g => this.gains[i].gain;
        }
    }

    // infinite time loop
    fun void run() {
        while( true ) {
            for( int i; i < numPitches; i++ )
            {
                // set frequency from pitch
                pitches[i] => Std.mtof => tones[i].freq;
                pitches[i] => Std.mtof => organs[i].freq;

                // compute loundess for each tone
                Math.gauss( pitches[i], MU, SIGMA ) * SCALE => float intensity;
                // map intensity to amplitude
                intensity*96 => Math.dbtorms => tones[i].gain;
                intensity*96 => Math.dbtorms => organs[i].gain;

                // increment pitch
                INC +=> pitches[i];
                // wrap (for positive INC)
                if( pitches[i] > 120 ) 108 -=> pitches[i];
                // wrap (for negative INC)
                else if( pitches[i] < 12 ) 108 +=> pitches[i];
            }

            // advance time
            now => time start;
            while (start + T > now) {
                1::samp => now;
            }
        }
    }

    fun void gtHandler() {
        while (true) {
            Util.scalef(gt.axis[0], -1., 1., 20, 0.01, 0.25)::ms => this.T;

            if (gt.axis[2] < gt.deadzone) {
                0. => this.gain;
            } else {
                Std.scalef(gt.axis[2], gt.deadzone, 1., 0., 1.) => this.gain;
            }

            Std.scalef(gt.axis[3], -1., 1., 0.01, 10.) => float freq;
            Std.scalef(gt.axis[4], -1., 1., 0.1, 1.) => float depth;
            float mix;

            if (gt.axis[5] < gt.deadzone) {
                0. => mix;
            } else {
                Math.clampf(Std.scalef(gt.axis[5], gt.deadzone, 0.5, 0., 1.), 0., 1.) => mix;
            }

            this.chorus(freq, depth, mix);

            10::ms => now;
        }
    }

    fun void stopSound() {
        for (Envelope env : this.envs) {
            env.ramp(50::ms, 0.);
        }

        100::ms => now;
        // me.exit();
    }
}
