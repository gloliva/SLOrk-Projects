@import {"../lib/logger.ck", "../lib/utils.ck" }

// See if using subwoofer or not
int useSub;
if (me.args()) {
    me.arg(0) => Std.atoi => useSub;
}

// Connecting the output of Eurorack to a hemi through an audio interface
// only use audio interface L channel
Utils.stereoToDac(adc.chan(0), adc.chan(0), useSub);
if (useSub) {
    Utils.stereoToSub(adc.chan(0), adc.chan(0));
}

// Wait forever
Log.print("Waiting...");
eon => now;
