@import "../lib/keyboard.ck"
@import "../lib/global.ck"
@import "../lib/util.ck"

Global.gt @=> GameTrak @ gt;

GG.scene().camera() @=> GCamera cam;
GG.scene().light() @=> GLight light;
0. => light.intensity;

0.9 => float BLOOM_INTENSITY;
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.intensity(BLOOM_INTENSITY);
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());

@(220, 230, 240)/255.0 => vec3 MANY_STARDUST_COLOR;
5 => float STARDUST_INTENSITY;
2.0 => float SPECTRUM_RADIUS;
2000 => int STARDUST_NUM;
SphereGeometry sphere_geo_many(0.017, 6, 3, 0., 2 * Math.pi, 0., Math.pi);

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

GMesh stardusts[STARDUST_NUM];
-40 => float minX => float minY;
-100 => float minZ;
40 => float maxX => float maxY;
100 => float maxZ;
(maxX - minX) * 0.5 => float maxXDistance;
(maxZ - minZ) * 0.5 => float maxZDistance;

SPECTRUM_RADIUS * 2 => float STARDUST_MIN_R;

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

160. => float BH_Z_FAR;
10.  => float BH_Z_NEAR;
22.  => float BH_Z_CROSSFADE_START;
11.  => float BH_Z_CROSSFADE_END;

@(0., 0., 160.) => vec3 bh_pos;
@(0., 0.) => vec2 bh_rotation;
@(0., 0.) => vec2 bh_view_turn;
0. => float bh_radius;
2. => float bh_hfov;
3. => float bh_disk_brightness;
@(1., 0.8, 0.6) => vec3 bh_disk_color;
1. => float bh_bg_alpha;
1. => float bh_warp_boost;

TextureSampler universe_sampler;
TextureSampler.Filter_Linear => universe_sampler.filterMin;
TextureSampler.Filter_Linear => universe_sampler.filterMag;
TextureSampler.Filter_Linear => universe_sampler.filterMip;
TextureSampler.Wrap_Repeat   => universe_sampler.wrapU;
TextureSampler.Wrap_Repeat   => universe_sampler.wrapV;

universe_mat.texture(0, universe_txt);
universe_mat.uniformFloat3(1, bh_pos);
universe_mat.uniformFloat2(2, bh_rotation);
universe_mat.uniformFloat2(3, bh_view_turn);
universe_mat.texture(4, noise_txt);
universe_mat.uniformFloat(5, bh_radius);
universe_mat.uniformFloat(6, bh_hfov);
universe_mat.uniformFloat(7, bh_disk_brightness);
universe_mat.uniformFloat3(8, bh_disk_color);
universe_mat.uniformFloat(9, bh_bg_alpha);
universe_mat.sampler(12, universe_sampler);
universe_mat.uniformFloat(13, bh_warp_boost);

// ===== Mode =================================================================
0 => int MODE_STARDUST;
1 => int MODE_APPROACH;
2 => int MODE_BLACKHOLE;
MODE_STARDUST => int mode;

// ===== Stardust navigation ================
fun float easeInOutCubic(float x) {
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
}

Shred @ stopShred;
float deltaX, deltaZ;

fun void stop() {
    while ((Math.fabs(deltaX) > 0.001 || Math.fabs(deltaZ) > 0.001) && mode == MODE_STARDUST) {
        GG.nextFrame() => now;
        Util.lerp(deltaX, 0, 0.05) => deltaX;
        Util.lerp(deltaZ, 0, 0.05) => deltaZ;
        cam.posZ(cam.posZ() + deltaZ);
        cam.posX(cam.posX() + deltaX);
    }
    if (mode == MODE_STARDUST) 0.0 => deltaX => deltaZ;
    null @=> stopShred;
}

fun void stardustGtHandler() {
    2 => float maxSpeed;
    0.03 => float zThreshold;
    while (true) {
        GG.nextFrame() => now;
        if (mode != MODE_STARDUST) continue;

        if (gt.axis[5] < zThreshold) {
            if ((deltaX != 0 || deltaZ != 0) && stopShred == null) spork ~ stop() @=> stopShred;
            continue;
        }

        Math.sgn(gt.axis[3]) * easeInOutCubic(Math.fabs(gt.axis[3])) => float easedX;
        Math.sgn(gt.axis[4]) * easeInOutCubic(Math.fabs(gt.axis[4])) => float easedY;
        Math.map2(easedX, -1, 1, -maxSpeed, maxSpeed) / 2 => deltaX;
        Math.map2(easedY, -1, 1, maxSpeed / 4, -maxSpeed) => deltaZ;
        cam.posZ(cam.posZ() + deltaZ);
        cam.posX(cam.posX() + deltaX);
    }
} spork ~ stardustGtHandler();

fun void translateStars() {
    while (true) {
        GG.nextFrame() => now;
        if (mode == MODE_BLACKHOLE) continue;
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

vec3 bh_vel;

fun void approachDriver() {
    BH_Z_FAR => bh_pos.z;
    universe_mat.uniformFloat3(1, bh_pos);

    0. => bh_radius;
    universe_mat.uniformFloat(5, bh_radius);

    1.   => float maxSpeed;
    8.   => float BH_RADIUS_FADEIN;
    2.   => float TAPER_EXP;
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

        0. => float dz;
        0. => float dx;
        if (gt.axis[5] > 0.05) {
            Math.sgn(gt.axis[3]) * easeInOutCubic(Math.fabs(gt.axis[3])) => float easedX;
            Math.sgn(gt.axis[4]) * easeInOutCubic(Math.fabs(gt.axis[4])) => float easedY;
            Math.map2(easedX, -1, 1, -maxSpeed, maxSpeed) / 2 * rate_scale => dx;
            Math.map2(easedY, -1, 1, maxSpeed / 4, -maxSpeed) * rate_scale => dz;
        }
        cam.posZ(cam.posZ() + dz);
        cam.posX(cam.posX() + dx);

        if (dz < 0) {
            bh_pos.z + dz => bh_pos.z;
            if (bh_pos.z < BH_Z_NEAR) BH_Z_NEAR => bh_pos.z;
        }
        universe_mat.uniformFloat3(1, bh_pos);

        (BH_Z_CROSSFADE_START - bh_pos.z) / (BH_Z_CROSSFADE_START - BH_Z_CROSSFADE_END) => float t;
        Math.max(0., Math.min(1., t)) => t;
        1. - t => stardust_vis;
        1. - t => bh_bg_alpha;
        star_mat.uniformFloat(2, stardust_vis);
        universe_mat.uniformFloat(9, bh_bg_alpha);

        if (bh_pos.z <= BH_Z_NEAR + 0.001) {
            for (auto s : stardusts) s --< GG.scene();
            MODE_BLACKHOLE => mode;
            break;
        }
    }
}

fun void buttonWatch() {
    while (true) {
        gt.buttonPress => now;
        if (mode == MODE_STARDUST) {
            MODE_APPROACH => mode;
            spork ~ approachDriver();
        }
    }
} spork ~ buttonWatch();

0.01  => float BH_VEL_ACC;
0.93  => float BH_VEL_DAMP;
0.10  => float BH_POS_SCALE;
0.7   => float BH_YAW_RATE;
0.2   => float BH_WRAP_THRESHOLD;
5.    => float BH_WRAP_EMERGE_R;
15.  => float BH_MAX_R;
0.1  => float BH_PULL;
5.0  => float BH_TARGET_R;

fun void bhGtHandler() {
    0.05 => float dead;
    while (true) {
        GG.nextFrame() => now;
        if (mode != MODE_BLACKHOLE) continue;
        GG.dt() => float dt;

        if (gt.axis[5] >= dead && Math.fabs(gt.axis[3]) > dead) {
            -gt.axis[3] * BH_YAW_RATE * dt +=> bh_view_turn.x;
            universe_mat.uniformFloat2(3, bh_view_turn);
        }

        -Math.sin(bh_view_turn.x) => float fx;
        -Math.cos(bh_view_turn.x) => float fz;

        if (gt.axis[5] < dead) {
            @(0., 0., 0.) => bh_vel;
        } else if (Math.fabs(gt.axis[4]) > dead) {
            Std.scalef(gt.axis[5], dead, 1., 0., 1.) => float throttle;
            gt.axis[4] * throttle * BH_VEL_ACC => float accel;
            fx * accel +=> bh_vel.x;
            fz * accel +=> bh_vel.z;
        }
        
        Math.map2(gt.axis[5], 0, 0.35, 50, 5) => universe.sca;

        bh_pos.magnitude() => float pull_mag;
        if (pull_mag > 0.0001) {
            (pull_mag - BH_TARGET_R) * BH_PULL / Math.max(3., pull_mag) => float pull_scalar;
            -bh_pos.x / pull_mag * pull_scalar +=> bh_vel.x;
            -bh_pos.z / pull_mag * pull_scalar +=> bh_vel.z;
        }

        BH_VEL_DAMP *=> bh_vel;
        bh_vel * BH_POS_SCALE +=> bh_pos;

        bh_pos.magnitude() => float mag;
        if (mag < bh_radius * BH_WRAP_THRESHOLD && mag > 0.0001) {
            -BH_WRAP_EMERGE_R / mag => float k;
            k *=> bh_pos;
            Math.fmod(bh_view_turn.x + Math.PI, 2. * Math.PI) => bh_view_turn.x;
            universe_mat.uniformFloat2(3, bh_view_turn);
            -1 *=> bh_vel;
        }

        bh_pos.magnitude() => mag;
        if (mag > BH_MAX_R) {
            BH_MAX_R / mag *=> bh_pos;
            0.3 *=> bh_vel;
        }

        universe_mat.uniformFloat3(1, bh_pos);
    }
} spork ~ bhGtHandler();

fun void bhAutoAnimate() {
    now => time t0;
    while (true) {
        GG.nextFrame() => now;
        if (mode != MODE_BLACKHOLE) continue;
        GG.dt() => float dt;
        (now - t0) / 1::second => float t;

        bh_pos.magnitude() => float dist;
        1. / Math.max(0.6, dist) => float closeness;
        bh_vel.magnitude() => float speed;

        bh_rotation.x + dt * (0.04 + 0.14 * closeness + 0.03 * speed) => bh_rotation.x;
        bh_rotation.y + dt * (0.025 + 0.07 * closeness) => bh_rotation.y;
        Math.fmod(bh_rotation.x, 1.) => bh_rotation.x;
        Math.fmod(bh_rotation.y, 1.) => bh_rotation.y;
        universe_mat.uniformFloat2(2, bh_rotation);

        2. + 0.14 * Math.sin(t * 0.17) + 0.08 * Math.sin(t * 0.41 + 1.3) => bh_hfov;
        universe_mat.uniformFloat(6, bh_hfov);

        0.05 * closeness * Math.sin(t * 0.12) + 0.02 * Math.sin(t * 0.37) => bh_view_turn.y;
        universe_mat.uniformFloat2(3, bh_view_turn);

        1. + (0.05 + 0.09 * closeness) * Math.sin(t * 0.45)
           + 0.03 * Math.sin(t * 0.93 + 0.9) => bh_radius;
        universe_mat.uniformFloat(5, bh_radius);

    }
} spork ~ bhAutoAnimate();

fun void color_change() {
    while (true) {
        GG.nextFrame() => now;
        if (mode != MODE_BLACKHOLE) continue;
        Math.sin(bh_rotation.x * Math.PI) * 180 + 180 => float hue;
        Math.sin(bh_rotation.y * Math.PI) * 0.3 + 0.2 => float sat;
        Color.hsv2rgb(@(hue, sat, 1.)) => bh_disk_color;
        universe_mat.uniformFloat3(8, bh_disk_color);
    }
} spork ~ color_change();

while (true) GG.nextFrame() => now;
