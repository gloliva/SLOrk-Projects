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
}