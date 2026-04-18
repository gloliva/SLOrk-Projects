@import "keyboard.ck"


public class Station {
    // Station audio
    SawOsc oscs[3];

    // Keyboard handling
    int keyIdx;
    Keyboard @ kb;
    TriOsc keySounds[8];
    ADSR envs[8];

    // State
    int damaged;

    fun @construct() {
        // Init station sound
        261.63 => this.oscs[0].freq;
        329.63 => this.oscs[1].freq;
        392.00 => this.oscs[2].freq;

        for (SawOsc osc : this.oscs) {
            0.1 => osc.gain;
            osc => dac;
        }

        // Setup keyboard clicking sound
        for (int i; i < this.keySounds.size(); i++) {
            this.keySounds[i] @=> TriOsc osc;
            this.envs[i] @=> ADSR env;

            osc => env => dac;
            0.3 => osc.gain;
            env.set(25::ms, 80::ms, 0.7, 100::ms);
            Math.random2f(1000., 3000.) => osc.freq;
        }

        // Setup keyboard
        new Keyboard(0) @=> this.kb;
        spork ~ this.kb.update();
    }

    fun void damage() {
        390 => this.oscs[1].freq;
        406. => this.oscs[2].freq;
        1 => this.damaged;
    }

    fun void playKeyboardSound() {
        this.envs[this.keyIdx].keyOn(1);
        100::ms => now;
        this.envs[this.keyIdx].keyOff(1);
        (this.keyIdx + 1) % this.envs.size() => this.keyIdx;
    }

    fun void interact() {
        while (true) {
            this.kb.event => now;
            // Play keyboard clicking sounds
            spork ~ this.playKeyboardSound();

            // Check if repairing station
            if (this.damaged && this.kb.event.state == KeyboardEvent.DOWN && this.kb.event.key == "H".charAt(0)) {
                this.repair();
            }
        }
    }

    fun void repair() {
        329.63 => this.oscs[1].freq;
        392.00 => this.oscs[2].freq;
        0 => this.damaged;
    }
}

/*
SndBuf2 buf1("/Users/gloliva/Downloads/among-us/assets/ElectricHum_BW.44833.wav");
SndBuf2 buf2("/Users/gloliva/Downloads/among-us/assets/SciFiWorkshop_S08SF.1719.wav");

1 => buf1.loop;
1 => buf2.loop;

buf1 => Gain gains[2];
buf2 => gains;

0.3 => gains[0].gain;
0.3 => gains[1].gain;

gains[0] => NRev revL => dac.chan(0);
gains[1] => NRev revR => dac.chan(1);


buf1.play(1.);
buf2.play(1.);
*/


Station station;
spork ~ station.interact();

while (true) {
    <<< "Station healthy" >>>;
    3::second => now;
    if (!station.damaged) {
        <<< "Damaging station" >>>;
        station.damage();
    }

    while (station.damaged) {
        10::ms => now;
    }
}

