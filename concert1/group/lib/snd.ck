public class Snd {
    fun static void play(string path) {
        play(path, 1.0);
    }
    fun static void play(string path, float gain) {
        play(path, gain, dac);
    }
    fun static void play(string path, float gain, UGen out) {
        SndBuf buf(path) => out;
        buf.gain(gain);
        buf.length() => now;   
    }
    
    fun static void playBC(string path, float gain, UGen out, int bits, int downsample) {
        SndBuf buf(path) => Bitcrusher bc => out;
        bc.bits(bits);
        bc.downsample(downsample);
        buf.gain(gain);
        buf.length() => now;
    }

    fun static void loop(string path) {
        loop(path, 1.0);
    }
    fun static void loop(string path, float gain) {
        SndBuf buf(path) => dac;
        buf.gain(gain);
        buf.loop(true);
        while(true) {
            10::ms => now;
        }
    }
    fun static void loop(string path, float gain, UGen out) {
        SndBuf buf(path) => out;
        buf.gain(gain);
        buf.loop(true);
        while(true) {
            10::ms => now;
        }
    }
}