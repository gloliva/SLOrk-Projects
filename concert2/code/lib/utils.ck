@import {"globals.ck", "logger.ck"}


public class Utils {
    fun static void map(UGen left[], UGen right[], vec2 mappings[]) {
        for (vec2 mapping : mappings) {
            (mapping.x)$int => int leftIdx;
            (mapping.y)$int => int rightIdx;
            left[leftIdx] => right[rightIdx];
        }
    }

    fun static void unmap(UGen left[], UGen right[], vec2 mappings[]) {
        for (vec2 mapping : mappings) {
            (mapping.x)$int => int leftIdx;
            (mapping.y)$int => int rightIdx;
            left[leftIdx] =< right[rightIdx];
        }
    }

    fun static dur ramp(Envelope envs[], dur fade, float val) {
        for (Envelope env : envs) {
            env.ramp(fade, val);
        }

        return fade;
    }

    fun static void ramp(Envelope envs[], dur fades[], float vals[]) {
        if (fades.size() != vals.size()) {
            Log.error("Error in Utils.ramp, fades and vals are not the same length");
            return;
        }

        for (int i; i < fades.size(); i++) {
            fades[i] => dur fade;
            vals[i] => float val;

            for (Envelope env : envs) {
                env.ramp(fade, val);
            }

            fade => now;
            Log.print("Done with ramp idx: " + i);
        }
    }

    fun static dur ramp(Envelope envs[], int idxs[], dur fade, float val) {
        for (int idx : idxs) {
            envs[idx].ramp(fade, val);
        }

        return fade;
    }

    fun static void stereoToDac(UGen L, UGen R, int useSub) {
        Utils.stereoToDac(L, R, useSub, 0);
    }

    fun static void stereoToDac(UGen L, UGen R, int useSub, int offset) {
        // If not running on hemi, connect to stereo
        if (dac.channels() <= offset + Globals.NUM_HEMI_CHANS) {
            L => dac.left;
            R => dac.right;
        } else {
            // Connect to Hemi's 6 channels
            for (int i; i < Globals.NUM_HEMI_CHANS / 2; i++) {
                Log.debug("Connecting L chan to index " + (offset + (i * 2)) + " and R chan to index " + (offset + ((i * 2) + 1)));

                // If using a subwoofer, add a high pass filter her for the Hemis
                if (useSub) {
                    L => HPF filterL(100.) => dac.chan(offset + (i * 2));
                    R => HPF filterR(100.) => dac.chan(offset + ((i * 2) + 1));
                } else {
                    L => dac.chan(offset + (i * 2));
                    R => dac.chan(offset + ((i * 2) + 1));
                }
            }
        }
    }

    fun static void stereoToSub(UGen L, UGen R) {
        Utils.stereoToSub(L, R, 0);
    }

    fun static void stereoToSub(UGen L, UGen R, int offset) {
        // If not running with Hemi (6 channels) + Subwoofer (2 channels), just ignore
        // TODO: connect to stereo, and change other function to HPF at the same cutoff frequency
        if (dac.channels() < (Globals.NUM_HEMI_CHANS + Globals.NUM_SUB_CHANS)) {
            Log.error("Not enough channels for subwoofer");
            return;
        }

        L => LPF filterL(100.) => dac.chan(offset + 6);
        R => LPF filterR(100.) => dac.chan(offset + 7);
    }

    fun static int getKeyboardDeviceId() {
        // define some max device threshold to prevent looping forever
        // super unlikely to have more than 10 keyboard devices connected
        10 => int maxDevices;
        for (int deviceId; deviceId < maxDevices; deviceId++) {
            Hid kb;

            // Something went wrong...
            if (!kb.openKeyboard(deviceId)) {
                return -1;
            }

            // Check if currently opened device is the Apple Keyboard
            if (kb.name().find("Apple Internal Keyboard") != -1) {
                return deviceId;
            }
        }

        return -1;
    }
}
