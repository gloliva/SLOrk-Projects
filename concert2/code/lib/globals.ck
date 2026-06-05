public class Globals {
    16 => static int NUM_ES8_OUTPUTS;
    4 => static int NUM_ES8_INPUTS;
    2 => static int NUM_ES8_AUDIO_INPUTS;

    6 => static int NUM_HEMI_CHANS;
    2 => static int NUM_SUB_CHANS;
    2 => static int NUM_HEMI_UNUSED_CHANS;
    Globals.NUM_HEMI_CHANS + Globals.NUM_SUB_CHANS + Globals.NUM_HEMI_UNUSED_CHANS => static int NUM_HEMI_TOTAL_CHANS;

    static HPF hemis[2];
    static LPF subs[2];

    // Events
    static Event stateChange;
    static Event connectionConfirmation;
}
