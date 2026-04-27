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
        // Write `chuck --probe` output to a file
        "chuck --probe 2>&1 | grep -A 5 \"keyboard\" > .kb_devices.txt" => string chuckProbeCmd;
        Std.system(chuckProbeCmd);

        FileIO fio;
        StringTokenizer tokenizer;
        string line;
        string token;

        ".kb_devices.txt" => fio.open;
        // Ensure file opened correctly
        if( !fio.good() ) {
            cherr <= "ERROR: Unable to open file/dir: " <= ".kb_devices.txt" <= " for reading."
                    <= IO.newline();
            me.exit();
        }

        // Get rid of first line
        fio.readLine() => line;

        while (fio.more()) {
            fio.readLine() => line;
            line => tokenizer.set;

            // [chuck]:  line start
            tokenizer.next();

            // Device ID
            tokenizer.next().charAt(1) - "0".charAt(0) => int deviceId;

            // Colon
            tokenizer.next();

            // Rest of the line is device name
            tokenizer.next() => string deviceName;
            while (tokenizer.more()) {
                deviceName + " " + tokenizer.next() => deviceName;
            }

            // Remove " in beginning and end of name
            deviceName.substring(1, deviceName.length() - 2) => deviceName;

            if (deviceName.find("Apple Internal Keyboard") != -1) {
                Std.system("rm .kb_devices.txt");
                return deviceId;
            }
        }

        return -1;
    }
}