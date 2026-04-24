// Instanced star renderer. One Material + one Geometry is shared across all
// 2000 GMesh stars; ChuGL batches them into a single instanced draw call,
// replacing what used to be 2000 draws + 2000 per-frame material uniform
// updates. Per-star color animation is computed in the vertex shader from
// a storage buffer of immutable params + u_frame.time, so the CPU no longer
// touches the materials every frame at all.

#include FRAME_UNIFORMS
#include DRAW_UNIFORMS
#include STANDARD_VERTEX_INPUT

struct VertexOutput {
    @builtin(position) position : vec4f,
    @location(0) color : vec3f,
};

// Per-star parameters, indexed by instance.
//   x = fade_freq, y = init_time (phase), z = intensity multiplier, w = unused.
@group(1) @binding(0) var<storage> u_star_params : array<vec4f>;
// Shared base color * global intensity (MANY_STARDUST_COLOR * STARDUST_INTENSITY).
@group(1) @binding(1) var<uniform> u_base_color : vec3f;
// Global visibility multiplier — 1 in stardust, ramps to 0 during approach crossfade.
@group(1) @binding(2) var<uniform> u_visibility : f32;

@vertex
fn vs_main(in : VertexInput) -> VertexOutput {
    var out : VertexOutput;
    var u_Draw : DrawUniforms = u_draw_instances[in.instance];

    let worldpos = u_Draw.model * vec4f(in.position, 1.0);
    out.position = (u_frame.projection * u_frame.view) * worldpos;

    let p = u_star_params[in.instance];
    let fade = abs(sin(p.x * u_frame.time + p.y));
    out.color = u_base_color * p.z * u_visibility * fade;

    return out;
}

@fragment
fn fs_main(in : VertexOutput) -> @location(0) vec4f {
    return vec4f(in.color, 1.0);
}
