//--------------------------------------------------------
// name: paulstretch.ck
// desc: Paul's Extreme Sound Stretch (Paulstretch) wrapped
//       as a reusable class for routing any SndBuf through
//       the processor.
//
// author: Celeste Betancur Gutierrez
//         adapted from Paul Nasca's Python implementation
// class wrapper: Michelle Chen
// date: Fall 2025
//--------------------------------------------------------

public class PaulStretch
{
    // configuration
    .05 => float resolution;
    4096 * 4 => int windowSize;

    // dsp components
    SndBuf internalBuf;   // default buffer if caller does not provide one
    SndBuf @input;        // buffer we are stretching
    FFT fft;
    IFFT ifft1;
    IFFT ifft2;
    Gain output;

    // derived values
    0 => int halfWindowSize;
    0 => int overlapAdd;
    0 => int playbackHop;
    // init to non-null so size() is safe in start()
    complex freqBuffer[1];

    0 => int running;
    0 => int built;

    // set a new stretch resolution (smaller values = more stretch)
    fun void setResolution(float r)
    {
        r => resolution;
    }

    // override the window size before calling start()
    fun void setWindowSize(int ws)
    {
        ws => windowSize;
    }

    // let caller provide an existing SndBuf (already read + looped)
    fun void useInput(SndBuf @buf)
    {
        buf @=> input;
        // 1 => input.loop;
        // 0 => input.pos;
    }

    // record any UGen into a temp wav, load it, and start stretching
    fun void recordAndStart(UGen @src, dur length, string recordPath)
    {
        // stop any existing processing
        stop();

        // tap the source into a recorder
        WvOut recorder => blackhole;
        recorder.wavFilename(recordPath);
        src => recorder;

        length => now;

        // close and detach recorder
        recorder.closeFile();
        src =< recorder;
        recorder =< blackhole;

        // load the freshly recorded file and run
        readSample(recordPath);
        start();
    }

    // convenience: read a sample into the internal buffer
    fun void readSample(string path)
    {
        internalBuf @=> input;
        path => input.read;
        1 => input.loop;
        0 => input.pos;
    }

    // connect the processor output into another patch
    fun Gain out()
    {
        return output;
    }

    // build internal graph and start processing
    fun void start()
    {
        if (running) return;

        // fall back to a default sample if the caller forgot to set one
        if (input == null)
        {
            internalBuf @=> input;
            "special:dope" => input.read;
            1 => input.loop;
        }

        // normalize window sizing
        (windowSize / 2) * 2 => windowSize;
        windowSize / 2 => halfWindowSize;
        freqBuffer.size(halfWindowSize);

        // analysis chain — only patch once; repeated => adds duplicate connections
        if (!built)
        {
            input => fft => blackhole;
            ifft1 => output;
            ifft2 => output;
            1 => built;
        }

        // set sizes + Hann window
        windowSize => fft.size => ifft1.size => ifft2.size;
        (halfWindowSize / 2) => overlapAdd;
        Windowing.hann(windowSize) => fft.window => ifft1.window => ifft2.window;

        // compute playback hop size
        (overlapAdd * (input.sampleRate()) / (second / samp)$float)$int => playbackHop;

        //0 => input.pos;
        1.0 => output.gain;
        1 => running;

        spork ~ randomizePhase();
        spork ~ reconstruct();
    }

    // stop processing (existing shreds exit cleanly)
    fun void stop()
    {
        0 => running;
    }

    // randomize phases and rewind input position to achieve stretching
    fun void randomizePhase()
    {
        while (running)
        {
            fft.upchuck();

            for (0 => int i; i < halfWindowSize; i++)
            {
                (fft.cval(i)$polar).mag => float mag;
                Math.random2f(-Math.PI, Math.PI) => float randomPhase;
                #(mag * Math.cos(randomPhase), mag * Math.sin(randomPhase)) => freqBuffer[i];
            }

            overlapAdd::samp => now;

            // move playhead backward relative to hop size for stretch factor
            (input.pos()) - ((playbackHop - playbackHop * (resolution))$int) => input.pos;
        }
    }

    // overlap-add reconstruction
    fun void reconstruct()
    {
        while (running)
        {
            ifft1.transform(freqBuffer);
            overlapAdd::samp => now;
            ifft2.transform(freqBuffer);
            overlapAdd::samp => now;
        }
    }
}

//--------------------------------------------------------


// the following example is working
PaulStretch ps;
ps.readSample(me.dir() + "../assets/radio.wav");
ps.setResolution(0.5);
ps.start();

ps.out() => dac;

10 :: second => now;
//--------------------------------------------------------
