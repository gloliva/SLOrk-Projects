public class Globals {
    6 => static int NUM_HEMI_CHANS;
    2 => static int NUM_SUB_CHANS;

    static HPF hemis[Globals.NUM_HEMI_CHANS];
    static LPF subs[Globals.NUM_SUB_CHANS];

    // Events
    static Event stateChange;
}
