@import "keyboard.ck"


public class Station {
    // Station audio
    SawOsc oscs[3];

    // Keyboard handling
    int keyIdx;
    Keyboard @ kb;
    TriOsc keySounds[16];
    ADSR envs[16];

    // scale
    [0, 3, 7, 10, 13] @=> int scale[];

    // State
    int damaged;

    // Alarm sound
    SndBuf alarm;
    SndBuf damageSounds[2];

    // Fixing buffers
    int repairIdx;
    SndBuf repairSounds[6];
    SndBuf fixedSound;

    fun @construct() {
        // Init station sound
        261.63 => this.oscs[0].freq;
        329.63 => this.oscs[1].freq;
        392.00 => this.oscs[2].freq;

        for (SawOsc osc : this.oscs) {
            0.1 => osc.gain;
            // osc => dac;
        }

        // Setup keyboard clicking sound
        for (int i; i < this.keySounds.size(); i++) {
            this.keySounds[i] @=> TriOsc osc;
            this.envs[i] @=> ADSR env;

            osc => env => dac.chan(i % dac.channels());
            0.3 => osc.gain;
            env.set(25::ms, 80::ms, 0.7, 100::ms);

            // set freq
            Math.random2(0, this.scale.size()) => int note;
            Math.mtof(60 + (Math.random2(-2, 2) * 12) + note) => osc.freq;
        }

        // Set sound buffers
        "/Users/gloliva/Downloads/among-us/assets/SpaceStationAlarm_HV.773.wav" => alarm.read;

        "/Users/gloliva/Downloads/among-us/assets/SpaceshipAirlockClose_HV._2.wav" => damageSounds[0].read;
        "/Users/gloliva/Downloads/among-us/assets/SciFiWeapon_S08SF.1677.wav" => damageSounds[1].read;

        "/Users/gloliva/Downloads/among-us/assets/SteampunkDevice_S011SF.739.wav" => repairSounds[0].read;
        "/Users/gloliva/Downloads/among-us/assets/SteampunkDevice_S011SF.744.wav" => repairSounds[1].read;
        "/Users/gloliva/Downloads/among-us/assets/SteampunkDevice_S011SF.752.wav" => repairSounds[2].read;
        "/Users/gloliva/Downloads/among-us/assets/SteampunkDevice_S011SF.758.wav" => repairSounds[3].read;
        "/Users/gloliva/Downloads/among-us/assets/SteampunkDevice_S011SF.759.wav" => repairSounds[4].read;
        "/Users/gloliva/Downloads/among-us/assets/SuperheroGadgetOff_HV.814.wav" => repairSounds[5].read;

        "/Users/gloliva/Downloads/among-us/assets/SciFiWeapon_S08SF.1677.wav" => fixedSound.read;

        alarm => dac;
        0.8 => alarm.gain;
        0 => alarm.play;

        for (int i; i < damageSounds.size(); i++) {
            0 => damageSounds[i].play;
            0.6 => damageSounds[i].gain;
            damageSounds[i] => dac;
        }
        1. => damageSounds[1].gain;

        for (int i; i < this.repairSounds.size(); i++) {
            0 => repairSounds[i].play;
            0.6 => repairSounds[i].gain;
            repairSounds[i] => dac.chan(i % dac.channels());
        }

        fixedSound => dac;
        0.7 => fixedSound.gain;
        fixedSound.samples() => fixedSound.pos;
        0 => fixedSound.play;

        // Setup keyboard
        new Keyboard(0) @=> this.kb;
        spork ~ this.kb.update();
    }

    fun void damage() {
        390 => this.oscs[1].freq;
        406. => this.oscs[2].freq;
        1 => this.damaged;

        // Play damage sounds
        0 => damageSounds[0].pos;
        2. => damageSounds[0].play;
        0 => damageSounds[1].pos;
        1. => damageSounds[1].play;
        5::second => now;

        // Play alarm sounds
        0 => alarm.pos;
        1 => alarm.loop;
        1 => alarm.play;
    }

    fun void playKeyboardSound() {
        this.envs[this.keyIdx].keyOn(1);
        100::ms => now;
        this.envs[this.keyIdx].keyOff(1);
        (this.keyIdx + 1) % this.envs.size() => this.keyIdx;
    }

    fun void playKeyboardSound2() {
        0 => this.repairSounds[repairIdx].pos;
        this.repairSounds[repairIdx].play(1);
        (repairIdx + 1) % this.repairSounds.size() => repairIdx;
    }

    fun void interact() {
        while (true) {
            this.kb.event => now;
            // Play keyboard clicking sounds
            spork ~ this.playKeyboardSound();
            spork ~ this.playKeyboardSound2();

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

        0 => alarm.loop;
        0 => alarm.play;

        -1 => fixedSound.play;
    }
}


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


Envelope machineRate => blackhole;
1. => machineRate.value;


fun void updateMachinery() {
    while (true) {
        <<< machineRate.value() >>>;
        machineRate.value() => buf2.play;
        10::ms => now;
    }
} spork ~ updateMachinery();


Station station;
spork ~ station.interact();

while (true) {
    <<< "Station healthy" >>>;
    10::second => now;
    if (!station.damaged) {
        <<< "Damaging station" >>>;
        spork ~ station.damage();
        me.yield();
        machineRate.ramp(3::second, 0.);
    }

    while (station.damaged) {
        10::ms => now;
    }
    machineRate.ramp(5::second, 1.) => now;
}

