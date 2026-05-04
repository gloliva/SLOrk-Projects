// Instanced star renderer. One Material + one Geometry, shared across all
// 2000 stars; ChuGL batches them into a single instanced draw call instead
// of 2000 separate draws. Per-star color animation is computed in the vertex
// shader from a storage buffer of immutable params + u_frame.time — the CPU
// no longer touches materials every frame at all.
//
// The output color exactly matches the original fade_in_out formula:
//   MANY_STARDUST_COLOR * STARDUST_INTENSITY * intensities[i] * stardust_vis
//     * abs(sin(fade_freq[i] * t + init_time[i]))
// so visuals are identical to the un-optimized per-material version.

#include FRAME_UNIFORMS
#include DRAW_UNIFORMS
#include STANDARD_VERTEX_INPUT

struct VertexOutput {
    @builtin(position) position : vec4f,
    @location(0) color : vec3f,
};

// Per-star params, indexed by instance.
//   x = fade_freq, y = init_time (phase), z = intensity multiplier, w = unused.
@group(1) @binding(0) var<storage> u_star_params : array<vec4f>;
// base color * global intensity (MANY_STARDUST_COLOR * STARDUST_INTENSITY).
@group(1) @binding(1) var<uniform> u_base_color : vec3f;
// 1 during stardust, ramps to 0 during BH approach crossfade.
@group(1) @binding(2) var<uniform> u_visibility : f32;
// 1 = unmodified sphere; > 1 stretches each star along its local Z axis,
// turning the sphere into a long capsule that radiates from the screen
// center under perspective — the classic warp-streak look.
@group(1) @binding(3) var<uniform> u_warp_stretch : f32;
// 0 = full per-star fade (cruise). 1 = fade pinned to 1.0 (no flicker) so
// heavy warp bloom doesn't strobe against independent per-star brightness.
@group(1) @binding(4) var<uniform> u_fade_damp : f32;

@vertex
fn vs_main(in : VertexInput) -> VertexOutput {
    var out : VertexOutput;
    var u_Draw : DrawUniforms = u_draw_instances[in.instance];

    var local_pos = in.position;
    local_pos.z = local_pos.z * u_warp_stretch;
    // Shrink the cross-section as the streak grows — bloom enlarges what's
    // there, so the unstretched sphere reads as a fat ball under heavy
    // bloom. Inverse-sqrt keeps the perceived volume roughly constant: the
    // longer the streak, the thinner it gets.
    let size_scale = inverseSqrt(u_warp_stretch);
    local_pos.x = local_pos.x * size_scale;
    local_pos.y = local_pos.y * size_scale;
    let worldpos = u_Draw.model * vec4f(local_pos, 1.0);
    out.position = (u_frame.projection * u_frame.view) * worldpos;

    let p = u_star_params[in.instance];
    let fade = abs(sin(p.x * u_frame.time + p.y));
    let fade_smooth = mix(fade, 1.0, u_fade_damp);
    out.color = u_base_color * p.z * u_visibility * fade_smooth;

    return out;
}

@fragment
fn fs_main(in : VertexOutput) -> @location(0) vec4f {
    return vec4f(in.color, 1.0);
}
