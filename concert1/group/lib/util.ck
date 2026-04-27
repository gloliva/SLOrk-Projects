public class Util {
    fun static float lerp(float cur, float tgt, float k) {
        return cur + (tgt - cur) * k;
    }

    // Scalef that supports an Exponential factor
    // < 1. == logarithmic curce, > 1. == exponential curve
    fun static float scalef(float value, float srcmin, float srcmax, float dstmin, float dstmax, float expfactor) {
        Math.clampf(value, srcmin, srcmax) => value;
        (value - srcmin) / (srcmax - srcmin) => float normalized;
        Math.pow(normalized, expfactor) => float curve;
        return dstmin + curve * (dstmax - dstmin);
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