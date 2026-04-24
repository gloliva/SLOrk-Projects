// constants & setups =========================================================
0.9 => float BLOOM_INTENSITY;
0.02 => float ACC;
0.01 => float ROTATION_ACC;

// camera
GG.scene().camera() @=> GCamera cam;
cam.posZ(4.);
cam.lookAt(@(0, 0, 0));
// GG.scene().camera(cam);

// GWindow.fullscreen();

// remove light
GG.scene().light() @=> GLight light;
0. => light.intensity;

// global blooming effect
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.intensity(BLOOM_INTENSITY);
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

// shader =====================================================================
// create the custom shader description
ShaderDesc shader_desc;
me.dir() + "blackhole.wgsl" => shader_desc.vertexPath;
me.dir() + "blackhole.wgsl" => shader_desc.fragmentPath;
// default vertex layout (each vertex has a float3 position, float3 normal, float2 uv)
[VertexFormat.Float3, VertexFormat.Float3, VertexFormat.Float2] @=> shader_desc.vertexLayout;

// compile the shader
Shader universe_shader(shader_desc);

// assign shader to a material
Material universe_mat;
universe_mat.shader(universe_shader);

PlaneGeometry plane_geo;
// apply our custom material to a mesh
GMesh universe(plane_geo, universe_mat) --> GG.scene();
6.6 => universe.sca;

// Texture.load(me.dir() + "./assets/me.jpg") @=> Texture universe_txt;
Texture.load(me.dir() + "./blackhole-assets/stars-4.jpg") @=> Texture universe_txt;
Texture.load(me.dir() + "./blackhole-assets/noise.jpg") @=> Texture noise_txt;
<<< universe_txt.width(), universe_txt.height() >>>;

@(0.8, 0.2, 10.) => vec3 pos;
@(0., 0.) => vec2 rotation;
@(0., 0.) => vec2 view_turn;
1. => float radius;
2. => float hfov;
true => int show_disk;
0. => float disk_brightness;
@(1., 0.8, 0.6) => vec3 disk_color;
universe_mat.texture(0, universe_txt);
universe_mat.uniformFloat3(1, pos);
universe_mat.uniformFloat2(2, rotation);
universe_mat.uniformFloat2(3, view_turn);
universe_mat.texture(4, noise_txt);
universe_mat.uniformFloat(5, radius);
universe_mat.uniformFloat(6, hfov);
universe_mat.uniformFloat(7, disk_brightness);
universe_mat.uniformFloat3(8, disk_color);
universe_mat.uniformFloat(9, 0.);  // 0 = show shader's own star background
universe_mat.uniformFloat3(10, @(1000., 1000., 1000.));  // satellite BHs parked far away
universe_mat.uniformFloat3(11, @(-1000., -1000., -1000.));

vec3 vel;
@(0.02, 0.) => vec2 rot_vel;

// // audio ======================================================================
// // estimate loudness
// adc => Gain input;
// adc => LPF lpf => NRev adc_rev => Gain adc_gain => dac;
// // adc_gain => Gain feedback => DelayL delay => adc_gain;
// // // set delay parameters
// // .75::second => delay.max => delay.delay;
// // // set feedback
// // .9 => feedback.gain;
// // // set effects mix
// // .2 => delay.gain;

// 0.1 => adc_rev.mix;
// 0. => adc.gain; // muted by default
// 10000 => lpf.freq;

// 0.1 => input.gain;

// // SinOsc sine => Gain input => dac; .15 => sine.gain;
// // estimate loudness
// input => Gain gi => OnePole onepole => blackhole;
// input => gi;
// 3 => gi.op;
// 0.999 => onepole.pole;

// fun void addVoice(dur offset, float midi, dur note_dur, dur loop_dur) {
//     NRev rev => Pan2 pan => dac;
//     .50 => rev.mix;

//     Mandolin mdl => Envelope env => rev;
//     Std.mtof(midi) => mdl.freq;
//     .2 => mdl.gain;
//     1::ms => env.duration;

//     offset => now;
//     int instr;
//     while (true) {
//         pos.magnitude() => float dist;
//         Std.mtof(midi) / Math.map2(dist, 0., 10., 10., 1.) => mdl.freq;
//         Math.random2f(-0.6, 0.6) => pan.pan;
//         mdl.noteOn(1);
//         env.keyOn();
//         note_dur / 2 => now;
//         env.keyOff();
//         note_dur / 2 => now;
//         mdl.noteOff(1);
//         (loop_dur - note_dur) => now;
//     }
// }

// spork ~ addVoice(7::second + 0.0::second, 58 + 12, 7.7::second, 20.1::second);  // C
// spork ~ addVoice(7::second + 1.9::second, 60 + 12, 7.1::second, 16.2::second);  // Eb
// spork ~ addVoice(7::second + 6.5::second, 65 + 12, 8.5::second, 19.6::second);  // F
// spork ~ addVoice(7::second + 6.7::second, 53 + 12, 9.1::second, 24.7::second);  // low F
// spork ~ addVoice(7::second + 8.2::second, 68 + 12, 9.4::second, 17.8::second);  // Ab
// spork ~ addVoice(7::second + 9.6::second, 56 + 12, 7.9::second, 21.3::second);  // low Ab
// spork ~ addVoice(7::second + 15.0::second, 61 + 12, 9.2::second, 31.8::second); // Db

// fun void bh_sound() {
//     SinOsc m => SinOsc a => JCRev rev => Pan2 pan => dac;
//     2 => a.sync; // FM synth

//     0.1 => rev.mix;
//     0 => a.gain;

//     while (true) {
//         // <<< rot_vel.magnitude() * ROTATION_ACC >>>;
//         // Math.map2(rot_vel.magnitude() * ROTATION_ACC, 0., 0.1, 0.5, 10.) => float gap;
//         // (100./gap)::ms => now;
//         10::ms => now;

//         // rot_vel.magnitude() * ROTATION_ACC => float spin;
//         pos.magnitude() => float dist;
//         1.5 / (dist + 1.) => a.gain;
//         Math.map2(dist, 0., 10., 30., 500.) => a.freq;
//         a.freq() / Math.random2f(1.1, 9.) => m.freq;
//         // Math.pow(radius, 10) => m.gain;
//         Math.random2f(1, Math.pow(1. + radius, 8)) => m.gain;

//         // pan
//         Math.sin(-Math.atan2(pos.x, pos.z) - view_turn.x) => pan.pan;
//     }
// }
// spork ~ bh_sound();

// fun void toggle_mic() {
//     while (true) {
//         GG.nextFrame() => now;
//         if (UI.isKeyPressed(UI_Key.M, false)) {
//             <<< "mic muted" >>>;
//             1. - adc.gain() => adc.gain;
//         }
//     }
// }
// spork ~ toggle_mic();

// mouse ======================================================================

fun void mouse_move() {
    vec2 init_mousePos, mousePos;
    while (true) {
        GG.nextFrame() => now;
        if (GWindow.mouseLeftDown()) {
            GWindow.mousePos() => init_mousePos;
            init_mousePos => mousePos;
        }
        if (GWindow.mouseLeft()) {
            // mouse is down
            GWindow.mousePos() => mousePos;
            0.0001 * (mousePos - init_mousePos) -=> view_turn;
            universe_mat.uniformFloat2(3, view_turn);
        }
    }
}
spork ~ mouse_move();

// graphics ===================================================================

// fun void brightness_change() {
//     float prev;
//     float curr;
//     0.6 => float slewUp;
//     0.05 => float slewDown;
//     while (true) {
//         GG.nextFrame() => now;
//         Math.pow(onepole.last(), 0.5) => curr;

//         // interpolate
//         if (prev < curr)
//             prev + (curr - prev) * slewUp => curr;
//         else
//             prev + (curr - prev) * slewDown => curr;

//         // change brightness
//         if (curr * 200 < 1.) {
//             // 0.5 => adc_rev.gain;
//             1. => disk_brightness;
//         } else {
//             // 1. => adc_rev.gain;
//             curr * 200 => disk_brightness;
//         }
//         // Math.log(1 + curr) * 100 => radius;
//         // universe_mat.uniformFloat(5, radius);
//         // <<< curr >>>;
//         universe_mat.uniformFloat(7, disk_brightness);

//         curr => prev;
//     }
// }
// spork ~ brightness_change();

fun void color_change() {
    while (true) {
        GG.nextFrame() => now;
        Math.sin(rotation.x * Math.PI) * 180 + 180 => float hue;
        Math.sin(rotation.y * Math.PI) * 0.3 + 0.2 => float sat;
        Color.hsv2rgb(@(hue, sat, 1.)) => disk_color;
        universe_mat.uniformFloat3(8, disk_color);
    }
}
spork ~ color_change();

fun vec3 rotate(vec3 o, vec2 turn) {
    @(o.x, Math.cos(turn.y) * o.y - Math.sin(turn.y) * o.z,
      Math.sin(turn.y) * o.y + Math.cos(turn.y) * o.z) => vec3 o1;
    @(Math.cos(turn.x) * o1.x + Math.sin(turn.x) * o1.z, o1.y,
      -Math.sin(turn.x) * o1.x + Math.cos(turn.x) * o1.z) => vec3 o2;
    return o2;
}

fun float impulse(float k, float x) {
    k * x => float h;
    return h * Math.exp(1.0 - h);
}

fun void radius_pumping() {
    now => time t0;
    0.2 => float amount;
    while (true) {
        GG.nextFrame() => now;
        if (UI.isKeyReleased(UI_Key.Enter)) {
            Math.max(amount, (now - t0) / second) => amount;
            break;
        }
    }
    now => t0;
    while (now - t0 < 1::second) {
        GG.nextFrame() => now;
        (now - t0) / second => float t;
        1 + amount * impulse(8, t) => radius;
        universe_mat.uniformFloat(5, radius);
    }
}

while (true) {
    GG.nextFrame() => now;

    // hide mouse cursor
    UI.setMouseCursor(UI_MouseCursor.None);

    // navigate in the space
    @(0, 0, 0) => vec3 acc_no_rot;
    if (UI.isKeyPressed(UI_Key.A, true)) {
        GG.dt() -=> acc_no_rot.x;
    } else if (UI.isKeyPressed(UI_Key.D, true)) {
        GG.dt() +=> acc_no_rot.x;
    }
    if (UI.isKeyPressed(UI_Key.LeftShift, true)) {
        GG.dt() +=> acc_no_rot.y;
    } else if (UI.isKeyPressed(UI_Key.LeftCtrl, true)) {
        GG.dt() -=> acc_no_rot.y;
    }
    if (UI.isKeyPressed(UI_Key.W, true)) {
        GG.dt() -=> acc_no_rot.z;
    } else if (UI.isKeyPressed(UI_Key.S, true)) {
        GG.dt() +=> acc_no_rot.z;
    }
    if (UI.isKeyPressed(UI_Key.Space, true)) {
        // match velocity (credit: outer wilds)
        0.9 *=> vel;
    }
    rotate(acc_no_rot, -1. * view_turn) => vec3 acc;
    acc +=> vel;
    vel * ACC +=> pos;
    universe_mat.uniformFloat3(1, pos);

    // black hole rotation
    if (UI.isKeyPressed(UI_Key.LeftArrow, true)) {
        GG.dt() -=> rot_vel.x;
    } else if (UI.isKeyPressed(UI_Key.RightArrow, true)) {
        GG.dt() +=> rot_vel.x;
    }
    if (UI.isKeyPressed(UI_Key.UpArrow, true)) {
        GG.dt() +=> rot_vel.y;
    } else if (UI.isKeyPressed(UI_Key.DownArrow, true)) {
        GG.dt() -=> rot_vel.y;
    }
    rot_vel * ROTATION_ACC +=> rotation;
    Math.fmod(rotation.x, 1.) => rotation.x;
    Math.fmod(rotation.y, 1.) => rotation.y;
    universe_mat.uniformFloat2(2, rotation);

    // pumping the black hole
    if (UI.isKeyPressed(UI_Key.Enter, false)) {
        spork ~ radius_pumping();
    }

    // change hfov with mouse wheels and middle click to reset.
    GWindow.scrollY() * 0.05 -=> hfov;
    if (UI.isKeyPressed(UI_Key.MouseMiddle, false)) {
        2. => hfov;
    }
    universe_mat.uniformFloat(6, hfov);
}
