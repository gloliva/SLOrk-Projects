////// SPACE: STARDUST → BLACKHOLE //////
@import {"../blackhole/shephard.ck", "../blackhole/bells.ck"}
@import {"../lib/gametrak.ck", "../lib/keyboard.ck", "../lib/osc.ck"}
@import {"../lib/global.ck", "../lib/state.ck", "../lib/util.ck", "../lib/snd.ck"}

// Soundscape code
Machine.add(me.dir() + "/../soundscape/main.ck");

// Globals
Global.gt @=> GameTrak @ gt;
Global.state @=> StationState @ stationState;
OscSender sender;
OscReceiver receiver(Events.damageStation, Events.stateChange, Events.shepardReverse, Events.stationFadeOut);

false => int thrusterEnabled;

5 => int sound;
int localRun;
if (me.args()) {
    Std.atoi(me.arg(0)) => localRun;
}

@(0.0, 0.0) => vec2 sound1Gain;
@(0.0, 0.0) => vec2 sound2Gain;
@(0.0, 0.0) => vec2 sound3Gain;
sound == 4 ? @(0.01, 0.01) : @(0.0, 0.0) => vec2 sound4Gain;
sound == 5 ? @(0.01, 0.01) : @(0.0, 0.0) => vec2 sound5Gain;

int navigator;
if (sound == 5) true => navigator;

// --------------------- GAINS --------------------- //
[
    sound1Gain,
    sound2Gain,
    sound3Gain,
    sound4Gain,
    sound5Gain,
] @=> vec2 levels[];

Gain gainsLeft[0];
Gain gainsRight[0];
for (int i; i < levels.size(); i++) {
    gainsLeft << new Gain(levels[i].x);
    gainsRight << new Gain(levels[i].y);
}

Envelope masterGain;
masterGain.value(0);

// Connect gains to DAC
dac.channels() => int numChans;
for (int i; i < gainsLeft.size(); i++) {
    for (int c; c + 1 < numChans; 2 +=> c) {
        gainsLeft[i] => masterGain => dac.chan(c);
        gainsRight[i] => masterGain => dac.chan(c + 1);
    }
}

750 => int beepRate;

// -------------------- SOUND 5 -------------------- //
PoleZero blocker;
.95 => blocker.blockZero;

SinOsc pingOsc => LPF pingLpf => ADSR pingEnv => Gain pingDry;
pingDry => NRev pingRev => blocker => gainsLeft[4];
pingDry => NRev pingRevR => blocker =>  gainsRight[4];

pingDry => DelayL pingDelay => LPF pingFbLpf => Gain pingFb => pingDelay;
pingDelay => pingRev;
pingDelay => pingRevR;

3::second => pingDelay.max;
200::ms => pingDelay.delay;
1800. => pingFbLpf.freq;
0.45 => pingFb.gain;

4200. => pingLpf.freq;
0.15 => pingRev.mix;
0.15 => pingRevR.mix;
0.65 => pingEnv.gain;
pingEnv.set(2::ms, 5::ms, 0.6, 12::ms);

4000::ms => dur pingPeriod;
40::ms => dur pingHold;

fun void sound5() {
    while (true) {
        Math.random2f(1250., 1300.) => pingOsc.freq;
        pingEnv.keyOn();
        pingHold => now;
        pingEnv.keyOff();

        now => time start;
        while (start + pingPeriod > now) {
            10::ms => now;
        }
    }
} spork ~ sound5();

fun void sound5Delay() {
    pingDelay.delay() => dur current;
    while (true) {
        Std.scalef(gt.axis[1], -1., 1., 100., 300.)::ms => dur target;
        if (Math.fabs((target - current) / 1::ms) > 15.) {
            target => pingDelay.delay;
            target => current;
        }
        60::ms => now;
    }
} spork ~ sound5Delay();


float origL[levels.size()];
float origR[levels.size()];
for (int i; i < levels.size(); i++) {
    levels[i].x => origL[i];
    levels[i].y => origR[i];
}

fun void applySound(int sel) {
    for (int i; i < levels.size(); i++) {
        if (sel == 0 || sel - 1 == i) {
            origL[i] => gainsLeft[i].gain;
            origR[i] => gainsRight[i].gain;
        } else {
            0. => gainsLeft[i].gain;
            0. => gainsRight[i].gain;
        }
    }
}

// Gametrack effects
fun void gtHandler() {
    while (true) {
        Std.scalef(gt.axis[0], -1., 1., 250., 5000.)::ms => pingPeriod;
        Std.scalef(gt.axis[1], -1., 1., 30, 1000) $ int => beepRate;

        if (gt.axis[2] < gt.deadzone) {
            0. => pingEnv.gain;
        } else {
            Std.scalef(gt.axis[2], gt.deadzone, 0.4, 0., 1.) => pingEnv.gain;
        }

        10::ms => now;
    }
} spork ~ gtHandler();

PoleZero blocker2;
.95 => blocker2.blockZero;

SndBuf engineBuf(me.dir() + "../assets/engineThrust.wav") => LPF engineLPF => HPF engineHPF => Gain engineGain => blocker2 => masterGain;
engineBuf.loop(true);
0 => engineGain.gain;
2000. => engineLPF.freq;
0.5 => engineLPF.Q;
50 => engineHPF.freq;
0.5 => engineHPF.Q;

0.03 => float engineDeadzone;
0.03 => float engineZThreshold;

CNoise engineNoise("white") => LPF engineFilter => NRev engineRev => Gain engineNoiseGain => masterGain;
0 => engineNoiseGain.gain;
0.08 => engineRev.mix;
100. => engineFilter.freq;

fun void warpHandler() {
    while (true) {
        gt.buttonPress => now;

        // Each station handles their own STATION --> WARP transition
        if (stationState.currState == stationState.STATION && !stationState.hold) {
            Events.stateChange.broadcast();
            break;
        }
    }
} spork ~ warpHandler();

// Warp + Blackhole objects
ShepardGenerator sg(gt);
BlackholeBells bells(gt);


BPF fadeBackBpf;
NRev fadeBackRev;
Delay fadeBackDelay;

fun void fadeBack(Envelope master) {
    0 => engineGain.gain;
    0 => engineNoiseGain.gain;

    // wait for 10 seconds
    20::second => dur fadeBackDur;

    fadeBackDur => now;

    master.ramp(fadeBackDur, 1.);

    master =< dac;

    master => fadeBackBpf => fadeBackDelay => fadeBackRev => dac;

    // activate effects
    1.0::second => fadeBackDelay.max;
    0.5::second => fadeBackDelay.delay;

    0.5 => fadeBackRev.gain;
    0.5 => fadeBackRev.mix;

    1000 => fadeBackBpf.freq;
    1 => fadeBackBpf.Q;
}


fun void sendStateChange(string addr) {
    while (true) {
        sender.send(addr, 1);
        50::ms => now;
    }
}

// ===== Shared camera + bloom ================================================
GG.scene() @=> GScene @ scene;
scene.camera() @=> GCamera cam;
@(0., 0., 0.) => scene.backgroundColor;

GWindow.fullscreen();
GWindow.mouseMode(GWindow.MOUSE_DISABLED);

0.4 => float BLOOM_INTENSITY;
-10. => float BLOOM_WARP_INTENSITY;
1.0 => float BLOOM_RADIUS_BASE;
4   => int   BLOOM_LEVELS_BASE;

2.5 => float WARP_RADIUS_MAX;
7   => int   WARP_LEVELS_MAX;
-14. => float WARP_INTENSITY_MAX;

// after decel
-10 => float SET_BLOOM_INTENSITY;
2.5 => float SET_BLOOM_RADIUS;
4 => int SET_BLOOM_LEVELS;
18.0 => float WARP_DECEL_DURATION;  // seconds to slow from warp to approach

GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.threshold(0.0);
bloom_pass.intensity(BLOOM_INTENSITY);
bloom_pass.radius(BLOOM_RADIUS_BASE);
bloom_pass.levels(BLOOM_LEVELS_BASE);
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

// ===== Stardust =============================================================
@(220, 230, 240)/255.0 => vec3 MANY_STARDUST_COLOR;
5 => float STARDUST_INTENSITY;
2000 => int STARDUST_NUM;

SphereGeometry sphere_geo_many(0.03, 6, 3, 0., 2 * Math.pi, 0., Math.pi);

ShaderDesc star_shader_desc;
me.dir() + "stardust.wgsl" => star_shader_desc.vertexPath;
me.dir() + "stardust.wgsl" => star_shader_desc.fragmentPath;
[VertexFormat.Float3, VertexFormat.Float3, VertexFormat.Float2] @=> star_shader_desc.vertexLayout;
Shader star_shader(star_shader_desc);
Material star_mat;
star_mat.shader(star_shader);

vec4 star_params[STARDUST_NUM];
for (int i; i < STARDUST_NUM; i++) {
    @(Math.random2f(0.1, 2.),
      Math.random2f(0., 2.),
      Math.random2f(0.1, 0.5),
      0.) => star_params[i];
}
star_mat.storageBuffer(0, star_params);
star_mat.uniformFloat3(1, MANY_STARDUST_COLOR * STARDUST_INTENSITY);
star_mat.uniformFloat(2, 1.0);
star_mat.uniformFloat(3, 1.0);
star_mat.uniformFloat(4, 0.0);

GMesh stardusts[STARDUST_NUM];
-40 => float minX => float minY;
-100 => float minZ;
40 => float maxX => float maxY;
100 => float maxZ;
(maxX - minX) * 0.5 => float maxXDistance;
(maxZ - minZ) * 0.5 => float maxZDistance;

4.0 => float STARDUST_MIN_R;

for (int i; i < STARDUST_NUM; i++) {
    GMesh sphere(sphere_geo_many, star_mat);
    sphere @=> stardusts[i];
    stardusts[i] --> GG.scene();

    float x, y, z;
    0 => int placed;
    while (placed == 0) {
        Math.random2f(minX, maxX) => x;
        Math.random2f(minY, maxY) => y;
        Math.random2f(minZ, maxZ) => z;
        if (Math.sqrt(x*x + y*y) >= STARDUST_MIN_R) 1 => placed;
    }
    @(x, y, z) => stardusts[i].translate;
}

1. => float stardust_vis;

// ===== Black hole shader ====================================================
ShaderDesc shader_desc;
me.dir() + "blackhole.wgsl" => shader_desc.vertexPath;
me.dir() + "blackhole.wgsl" => shader_desc.fragmentPath;
[VertexFormat.Float3, VertexFormat.Float3, VertexFormat.Float2] @=> shader_desc.vertexLayout;
Shader universe_shader(shader_desc);
Material universe_mat;
universe_mat.shader(universe_shader);
PlaneGeometry plane_geo;
GMesh universe(plane_geo, universe_mat);

universe --> cam;
universe.posZ(-4.);
universe.sca(50.);

Texture.load(me.dir() + "./blackhole-assets/stars-5.jpg") @=> Texture universe_txt;
Texture.load(me.dir() + "./blackhole-assets/noise.jpg") @=> Texture noise_txt;

80. => float BH_Z_FAR;
3.  => float BH_Z_NEAR;
14. => float BH_Z_CROSSFADE_START;
4.  => float BH_Z_CROSSFADE_END;

@(0., 0., 80.) => vec3 bh_pos;
0. => float bh_radius;
1. => float bh_bg_alpha;

TextureSampler universe_sampler;
TextureSampler.Filter_Linear => universe_sampler.filterMin;
TextureSampler.Filter_Linear => universe_sampler.filterMag;
TextureSampler.Filter_Linear => universe_sampler.filterMip;
TextureSampler.Wrap_Repeat   => universe_sampler.wrapU;
TextureSampler.Wrap_Repeat   => universe_sampler.wrapV;

universe_mat.texture(0, universe_txt);
universe_mat.uniformFloat3(1, bh_pos);
universe_mat.texture(4, noise_txt);
universe_mat.uniformFloat(5, bh_radius);
universe_mat.uniformFloat(9, bh_bg_alpha);
universe_mat.sampler(12, universe_sampler);

// ===== Mode =================================================================
0 => int MODE_STARDUST;
1 => int MODE_APPROACH;
2 => int MODE_DONE;
3 => int MODE_WARP_DECEL;
MODE_STARDUST => int mode;

// ===== Stardust navigation ================
0. => float cruise_speed;
0 => int warp_active;
0. => float warp_progress;
0 => int warp_stage;

[0.00, 0.20, 0.40, 0.60, 0.80] @=> float WARP_CHECKPOINTS[];
[
    "entering-warp-speed.wav",
    "initiating-warp-one.wav",
    "approaching-warp-nine.wav",
    "preliminary-warp-warning.wav",
    "approaching_warp_speed_9point99.wav"
] @=> string WARP_AUDIO[];

[28, 28, 20, 16, 16] @=> int bcBits[];
[1., 2., 4., 4., 4.] @=> float bcDownsampleFactor[];
[1., 0.9, 0.7, 0.6, 1.0] @=> float bcGain[];
int bcIdx;
Bitcrusher bc;

fun void playWarpCue(string filename, int warp_stage) {
    bcBits[bcIdx] => int numBits;
    bcDownsampleFactor[bcIdx] => float downsampleFactor;
    bcGain[bcIdx] => float gain;
    bcIdx++;

    if (bcIdx >= WARP_AUDIO.size()) {
        spork ~ modulateBitCrush(me.dir() + "../assets/" + filename, numBits, downsampleFactor);
    }

    Snd.playBC(me.dir() + "../assets/" + filename, gain, dac, bc, numBits, downsampleFactor$int);
}

fun void modulateBitCrush(string path, int numBits, float downsampleFactor) {
    SndBuf buf(path);
    now + buf.length() => time audioLength;
    1. => float bcGain;
    while (now < audioLength) {
        bc.bits(numBits);
        bc.gain(bcGain);
        bc.downsample(downsampleFactor$int);
        1::second => now;
        1 -=> numBits;
        0.5 +=> downsampleFactor;
        // 0.25 -=> bcGain;
    }

}

fun void engineUpdate() {
    0.0 => float curGain;
    1.0 => float curRate;
    0.0 => float zEnv;

    while (true) {
        if (!thrusterEnabled || warp_stage != 0) {
            10::ms => now;
            continue;
        }

        gt.axis[4] => float y;
        Math.fabs(y) => float magnitude;
        if (magnitude < engineDeadzone) 0 => magnitude;
        Math.sqrt(magnitude) => float curved;

        0.0 => float tgtGain;
        curRate => float tgtRate;
        2000. => float tgtLPF;
        if (y > 0 && magnitude > 0) {
            curved => tgtGain;
            0.9 + 0.5 * magnitude => tgtRate;
            Std.scalef(magnitude, 0, 1, 1200, 4000) => tgtLPF;
        } else if (y < 0 && magnitude > 0) {
            curved * 0.9 => tgtGain;
            -(0.5 + 0.35 * magnitude) => tgtRate;
            Std.scalef(magnitude, 0, 1, 500, 1600) => tgtLPF;
        }

        0.0 => float zTarget;
        if (gt.axis[5] > engineZThreshold) 1.0 => zTarget;

        Util.lerp(curGain, tgtGain, 0.2) => curGain;
        Util.lerp(curRate, tgtRate, 0.2) => curRate;
        Util.lerp(zEnv, zTarget, 0.025) => zEnv;

        zEnv * curGain * 0.15 => engineGain.gain;
        curRate => engineBuf.rate;
        tgtLPF => engineLPF.freq;

        Std.scalef(magnitude, 0, 1, 80, 500) => engineFilter.freq;
        zEnv * curved * 0.15 * 0.15 => engineNoiseGain.gain;

        10::ms => now;
    }
}

if (navigator) spork ~ engineUpdate();

fun void stardustGtHandler() {
    0.15 => float CRUISE_THRESHOLD;
    0.6  => float ACCEL_THRESHOLD;
    0.25 => float X_STEER_THRESHOLD;
    0.03 => float Z_ENGAGE_THRESHOLD;
    8.0  => float BASELINE_SPEED;
    10.  => float CRUISE_RAMP;
    200. => float FORWARD_ACCEL;
    700. => float CRUISE_MAX_SPEED;
    180.  => float WARP_DURATION;
    2500. => float WARP_MAX_SPEED;
    0.3  => float COLOR_SHIFT_START;
    20.  => float STRETCH_DIVISOR;
    6.0  => float LATERAL_SPEED;
    0. => float curLatSpeed;

    while (true) {
        GG.nextFrame() => now;
        if (mode != MODE_STARDUST) continue;
        if (!thrusterEnabled) continue;
        GG.dt() => float dt;

        gt.axis[4] => float y;
        gt.axis[3] => float x;
        gt.axis[5] => float z;
        Math.fabs(y) => float magY;
        Math.fabs(x) => float magX;
        z > Z_ENGAGE_THRESHOLD => int engaged;
        if (!engaged) {
            0. => magY;
            0. => magX;
        }

        if (warp_active == 0) {
            if (y > 0 && magY >= ACCEL_THRESHOLD) {
                (magY - ACCEL_THRESHOLD) / (1. - ACCEL_THRESHOLD) => float over;
                over * FORWARD_ACCEL * dt +=> cruise_speed;
            } else if (y > 0 && magY >= CRUISE_THRESHOLD) {
                if (cruise_speed < BASELINE_SPEED) {
                    Math.min(BASELINE_SPEED, cruise_speed + CRUISE_RAMP * dt) => cruise_speed;
                } else if (cruise_speed > BASELINE_SPEED) {
                    Math.max(BASELINE_SPEED, cruise_speed - CRUISE_RAMP * dt) => cruise_speed;
                }
            } else {
                Math.max(0., cruise_speed - CRUISE_RAMP * dt) => cruise_speed;
            }
            if (cruise_speed >= CRUISE_MAX_SPEED) 1 => warp_active;
        } else {
            Math.min(1., warp_progress + dt / WARP_DURATION) => warp_progress;

            warp_progress * warp_progress => float speed_t;
            CRUISE_MAX_SPEED + speed_t * (WARP_MAX_SPEED - CRUISE_MAX_SPEED) => cruise_speed;

            while (warp_stage < WARP_CHECKPOINTS.size() && warp_progress >= WARP_CHECKPOINTS[warp_stage]) {
                spork ~ playWarpCue(WARP_AUDIO[warp_stage], warp_stage);
                warp_stage++;
            }
        }

        cam.posZ(cam.posZ() - cruise_speed * dt);

        0. => float tgtLat;
        if (magX > X_STEER_THRESHOLD) {
            (magX - X_STEER_THRESHOLD) / (1. - X_STEER_THRESHOLD) => float xOver;
            Math.sgn(x) * xOver * LATERAL_SPEED => tgtLat;
        }
        Util.lerp(curLatSpeed, tgtLat, 0.2) => curLatSpeed;
        cam.posX(cam.posX() + curLatSpeed * dt);

        Math.max(1., cruise_speed / STRETCH_DIVISOR) => float stretch;
        star_mat.uniformFloat(3, stretch);

        if (warp_active == 0) {
            bloom_pass.intensity(BLOOM_INTENSITY);
            bloom_pass.radius(BLOOM_RADIUS_BASE);
            bloom_pass.levels(BLOOM_LEVELS_BASE);
            star_mat.uniformFloat3(1, MANY_STARDUST_COLOR * STARDUST_INTENSITY);
            star_mat.uniformFloat(4, 0.0);
            @(0., 0., 0.) => scene.backgroundColor;
        } else {
            warp_progress => float wt;

            BLOOM_INTENSITY + wt * (WARP_INTENSITY_MAX - BLOOM_INTENSITY) => float intensity;
            BLOOM_RADIUS_BASE + wt * (WARP_RADIUS_MAX - BLOOM_RADIUS_BASE) => float radius;
            BLOOM_LEVELS_BASE + wt * (WARP_LEVELS_MAX - BLOOM_LEVELS_BASE) => float lvl_f;

            radius + Math.sin(wt * 14. + 0.7) * 0.3 * wt => radius;
            lvl_f + Math.sin(wt * 22. + 1.3) * 0.8 * wt => lvl_f;
            Math.max(1.0, radius) => radius;
            Math.max(2., lvl_f) => lvl_f;
            bloom_pass.intensity(intensity);
            bloom_pass.radius(radius);
            bloom_pass.levels(lvl_f $ int);

            star_mat.uniformFloat(4, wt);

            if (wt < COLOR_SHIFT_START) {
                star_mat.uniformFloat3(1, MANY_STARDUST_COLOR * STARDUST_INTENSITY);
            } else {
                (wt - COLOR_SHIFT_START) / (1. - COLOR_SHIFT_START) => float ct;
                220. + Math.sin(ct * 12.) * 50. => float hue;  // 170..270
                Math.min(0.9, ct * 1.3) => float sat;
                Color.hsv2rgb(@(hue, sat, 1.0)) @=> vec3 tinted;
                star_mat.uniformFloat3(1, tinted * STARDUST_INTENSITY);
            }
        }
    }
} spork ~ stardustGtHandler();

fun void translateStars() {
    while (true) {
        GG.nextFrame() => now;
        if (mode == MODE_DONE) continue;
        for (auto stardust : stardusts) {
            stardust.posZ() - cam.posZ() => float dz;
            if (dz > maxZDistance)       stardust.translateZ(-maxZDistance * 2);
            else if (dz < -maxZDistance) stardust.translateZ( maxZDistance * 2);

            stardust.posX() - cam.posX() => float dx;
            if (dx > maxXDistance)       stardust.translateX(-maxXDistance * 2);
            else if (dx < -maxXDistance) stardust.translateX( maxXDistance * 2);
        }
    }
} spork ~ translateStars();

fun void approachDriver() {
    <<< "APPROACH DRIVER" >>>;

    BH_Z_FAR => bh_pos.z;
    universe_mat.uniformFloat3(1, bh_pos);

    0. => bh_radius;
    universe_mat.uniformFloat(5, bh_radius);

    15.0 => float maxSpeed;
    3 => float BH_RADIUS_FADEIN;
    2. => float TAPER_EXP;
    0.08 => float FLOOR_SCALE;

    while (mode == MODE_APPROACH) {
        GG.nextFrame() => now;
        GG.dt() => float dt;

        Math.min(1., bh_radius + dt / BH_RADIUS_FADEIN) => bh_radius;
        universe_mat.uniformFloat(5, bh_radius);

        (bh_pos.z - BH_Z_NEAR) / (BH_Z_FAR - BH_Z_NEAR) => float progress;
        Math.max(0., Math.min(1., progress)) => progress;
        Math.pow(progress, TAPER_EXP) => float rate_scale;
        Math.max(FLOOR_SCALE, rate_scale) => rate_scale;

        -maxSpeed * rate_scale * dt => float dz;
        cam.posZ(cam.posZ() + dz);

        bh_pos.z + dz => bh_pos.z;
        if (bh_pos.z < BH_Z_NEAR) BH_Z_NEAR => bh_pos.z;
        universe_mat.uniformFloat3(1, bh_pos);

        (BH_Z_CROSSFADE_START - bh_pos.z) / (BH_Z_CROSSFADE_START - BH_Z_CROSSFADE_END) => float t;
        Math.max(0., Math.min(1., t)) => t;
        1. - t => stardust_vis;
        1. - t => bh_bg_alpha;
        star_mat.uniformFloat(2, stardust_vis);
        universe_mat.uniformFloat(9, bh_bg_alpha);

        if (bh_pos.z <= BH_Z_NEAR + 0.001) {
            for (auto s : stardusts) s --< GG.scene();
            universe --< cam;
            MODE_DONE => mode;
            break;
        }
    }
}

fun void warpDecelDriver() {
    cruise_speed => float start_speed;
    warp_progress => float start_wt;

    15.0 => float APPROACH_SPEED;
    20.  => float STRETCH_DIVISOR;
    WARP_DECEL_DURATION => float BLOOM_DECEL_TIME;
    0.3  => float COLOR_SHIFT_START;
    0.   => float decel_progress;

    BLOOM_INTENSITY + start_wt * (WARP_INTENSITY_MAX - BLOOM_INTENSITY) => float start_intensity;
    BLOOM_RADIUS_BASE + start_wt * (WARP_RADIUS_MAX - BLOOM_RADIUS_BASE) => float start_radius;
    BLOOM_LEVELS_BASE + start_wt * (WARP_LEVELS_MAX - BLOOM_LEVELS_BASE) => float start_lvl;

    while (mode == MODE_WARP_DECEL) {
        GG.nextFrame() => now;
        GG.dt() => float dt;
        Math.min(1., decel_progress + dt / WARP_DECEL_DURATION) => decel_progress;
        decel_progress => float dp;

        start_speed + dp * (APPROACH_SPEED - start_speed) => cruise_speed;
        cam.posZ(cam.posZ() - cruise_speed * dt);

        Math.min(1., decel_progress * (WARP_DECEL_DURATION / BLOOM_DECEL_TIME)) => float bloom_dp;
        start_intensity + bloom_dp * (SET_BLOOM_INTENSITY - start_intensity) => float intensity;
        start_radius + bloom_dp * (SET_BLOOM_RADIUS - start_radius) => float radius;
        start_lvl + bloom_dp * (SET_BLOOM_LEVELS - start_lvl) => float lvl_f;
        bloom_pass.intensity(intensity);
        bloom_pass.radius(radius);
        bloom_pass.levels(lvl_f $ int);

        Math.max(1., cruise_speed / STRETCH_DIVISOR) => float stretch;
        star_mat.uniformFloat(3, stretch);

        start_wt * (1. - bloom_dp) => float fade_d;
        star_mat.uniformFloat(4, fade_d);

        if (start_wt >= COLOR_SHIFT_START) {
            (start_wt - COLOR_SHIFT_START) / (1. - COLOR_SHIFT_START) => float ct;
            220. + Math.sin(ct * 12.) * 50. => float hue;
            Math.min(0.9, ct * 1.3) * (1. - bloom_dp) => float sat;
            Color.hsv2rgb(@(hue, sat, 1.0)) @=> vec3 tinted;
            star_mat.uniformFloat3(1, tinted * STARDUST_INTENSITY);
        }

        if (decel_progress >= 1.0) {
            star_mat.uniformFloat3(1, MANY_STARDUST_COLOR * STARDUST_INTENSITY);
            star_mat.uniformFloat(3, 1.0);
            star_mat.uniformFloat(4, 0.0);
            @(0., 0., 0.) => scene.backgroundColor;
            bloom_pass.intensity(SET_BLOOM_INTENSITY);
            bloom_pass.radius(SET_BLOOM_RADIUS);
            bloom_pass.levels(SET_BLOOM_LEVELS);
            MODE_APPROACH => mode;
            break;
        }
    }
    approachDriver();
}

fun void camRotation() {
    0.0005 => float rotAmt;

    while (mode == MODE_STARDUST && !thrusterEnabled) {
        rotAmt => cam.rotateZ;
        GG.nextFrame() => now;
    }

    while (rotAmt >= 0.) {
        0.000001 -=> rotAmt;
        rotAmt => cam.rotateZ;
        GG.nextFrame() => now;
    }
} spork ~ camRotation();

fun void emergencyStateChange() {
    while (true) {

        if (GWindow.key(GWindow.KEY_LEFTSHIFT) && GWindow.keyDown(GWindow.KEY_E)) {
            Events.stateChange.broadcast();
        }

        GG.nextFrame() => now;
    }
} spork ~ emergencyStateChange();

fun void buttonWatch() {
    while (true) {
        if (localRun) {
            gt.buttonPress => now;
        }

        gt.buttonPress => now;
        if (mode == MODE_STARDUST) {
            if (warp_active == 1) {
                MODE_WARP_DECEL => mode;
                spork ~ warpDecelDriver();
            } else {
                bloom_pass.intensity(BLOOM_INTENSITY);
                bloom_pass.radius(BLOOM_RADIUS_BASE);
                bloom_pass.levels(BLOOM_LEVELS_BASE);
                star_mat.uniformFloat3(1, MANY_STARDUST_COLOR * STARDUST_INTENSITY);
                star_mat.uniformFloat(3, 1.0);
                star_mat.uniformFloat(4, 0.0);
                @(0., 0., 0.) => scene.backgroundColor;
                MODE_APPROACH => mode;
                spork ~ approachDriver();
            }
        }
    }
} spork ~ buttonWatch();

fun void stationRunner() {
    while (true) {
        // Wait for state transition
        if (!localRun) {
            Events.stateChange => now;
        } else {
            gt.buttonPress => now;
        }
        stationState.transition();

        if (stationState.currState == stationState.STATION && !stationState.hold) {
            // Turn off soundscape sounds
            MasterGain.soundscape.ramp(5::second, 0.);

            // Turn on station sounds
            MasterGain.spaceship.ramp(5::second, 1.);
            masterGain.ramp(5::second, 1.0);

            // enable gametrak thrusters
            true => thrusterEnabled;
        } else if (stationState.currState == stationState.WARP && !stationState.hold) {
            // Turn off station sounds
            MasterGain.spaceship.ramp(10::second, 0.);
            masterGain.ramp(10::second, 0.0);

            // Send Shepard reversal OSC message
            spork ~ sendStateChange("/shepard/reverse");

            // Turn on Shepard tone
            spork ~ sg.gtHandler();
        } else if (stationState.currState == stationState.BLACKHOLE && !stationState.hold) {
            // Cut Shepard Tone and turn on Bells
            spork ~ sg.stopSound();
            spork ~ bells.run();

            // Lock shred to prevent any more state
            stationState.lock();

            fadeBack(masterGain);
        }
    }
} spork ~ stationRunner();

while (true) GG.nextFrame() => now;
