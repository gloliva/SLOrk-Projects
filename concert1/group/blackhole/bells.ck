@import "../lib/global.ck"
@import "../lib/util.ck"


public class BlackholeBells {
    dac.channels() => int NUM_CHANNELS;

    // UGens
    Gain mixer[NUM_CHANNELS];
    NRev rev[NUM_CHANNELS];
    Envelope envs[NUM_CHANNELS];
    Dyno lim[NUM_CHANNELS];
    Delay del;

    // Timing
    5::second => dur T;

    // Bells
    12 => int numBells;
    TubeBell bell[numBells];
    TubeBell bassBell;

    // patterns
    int pat1[0];
    int pat2[0];

    // Scale
    [0, 2, 3, 5, 7, 8, 10] @=> int scale[];

    // Sequencing handling
    int round;
    int sequencing;

    fun @construct(GameTrak gt) {
        // Handle treble bells
        for (int i; i < numBells; i++)  {
            bell[i] => mixer[i % dac.channels()];
            bell[i].opADSR(0,0.01,0.4,0.0,0.04);
            bell[i].opADSR(2,0.01,0.4,0.0,0.04);
        }

        // Handle bass bell
        50 => Math.mtof => bassBell.freq;
        for (int i; i < NUM_CHANNELS; i + 2 => i) {
            bassBell => mixer[i];
        }

        // Handle remaining UGens
        for (int i; i < NUM_CHANNELS; i++) {
            // UGen chaining
            mixer[i] => rev[i] => envs[i] => lim[i] => dac.chan(i);

            // Set envs
            0.6 => mixer[i].gain;
            0.5 => envs[i].gain;
            0. => envs[i].value;

            // Set limiter
            lim[i].limit();
        }

        // Handle delay
        bell => del => rev; // cool echo
        del => del;
        0.4 => del.gain;
        17*0.2::second => del.max => del.delay;


        // Create pattern 1
        for (int i; i < 12; i++) {
            Math.random2(0, scale.size() -1) => int degree;
            62 + scale[degree] + (12 * Math.random2(-1, 1)) => int note;
            pat1 << note;
        }

        // Create pattern 2
        for (int i; i < 8; i++) {
            Math.random2(0, scale.size() -1) => int degree;
            62 + scale[degree] + (12 * Math.random2(0, 3)) => int note;
            pat2 << note;
        }

        // Run
        spork ~ gtHandler(gt);
    }

    fun void gtHandler(GameTrak gt) {
        while (true) {
            Util.scalef(gt.axis[0], -1., 1., 0.05, 5., 0.5)::second => T;

            if (gt.axis[2] < gt.deadzone + 0.05) {
                0 => sequencing;
            } else {
                1 => sequencing;
            }

            if (gt.axis[5] < gt.deadzone) {
                0. => del.gain;
            } else {
                Math.clampf(Std.scalef(gt.axis[5], gt.deadzone, 1., 0.1, 0.5), 0., 1.) => del.gain;
            }

            10::ms => now;
        }

    }

    fun void run() {
        // Length of silence
        4::second => now;

        <<< "Inside Bells, turning sound ON" >>>;
        for (Envelope env : envs) {
            env.ramp(50::ms, 1.);
            1. => bassBell.noteOn;
        }

        while (true) {

            <<< "Beginning sequencing" >>>;
            while (sequencing) {
                if (maybe) {
                    playPattern(pat1);
                }
                else {
                    playPattern(pat2);
                }
            }

            <<< "Stopping sequencing" >>>;
            while (!sequencing) {
                10::ms => now;
            }
        }
    }

    fun void playPattern(int pat[])  {
        1 => int oct;
        if (maybe*maybe) {
            2 => oct; // occasional octave higher
        }
        for (0 => int i; i < pat.cap(); i++)  {
            if (!sequencing) break;

            Std.mtof(pat[i])*oct => bell[round].freq;
            if (i == 1 && maybe*maybe) {
                1 => bassBell.noteOn;
            }
            1 => bell[round].noteOn;
            round++;
            if (round == numBells) 0 => round;

            now => time start;
            while (start + T > now) {
                10::ms => now;
            }
        }
    }
}
