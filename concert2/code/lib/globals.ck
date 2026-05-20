public class Globals {
    16 => static int NUM_ES8_OUTPUTS;
    4 => static int NUM_ES8_INPUTS;
    2 => static int NUM_ES8_AUDIO_INPUTS;
    6 => static int NUM_HEMI_CHANS;
    2 => static int NUM_SUB_CHANS;

    static HPF hemis[Globals.NUM_HEMI_CHANS];
    static LPF subs[Globals.NUM_SUB_CHANS];

    // Events
    static Event stateChange;
}
