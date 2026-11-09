# Project: Spirit Forge — Godot Supernatural VFX R&D Lab

## Role

Act as a senior real-time VFX technical artist, Godot rendering/shader engineer, procedural graphics developer, and practical mentor.

Help me build a personal R&D playground for experimenting with stylized supernatural visual effects. Work directly in this repository, implement working experiments, and explain the important technical and artistic decisions.

I am an experienced software engineer with more than five years of development experience. I am comfortable with programming and will use AI assistance, but I am still developing my skills in real-time VFX, shaders, procedural graphics, and 3D art workflows.

My biggest constraint is time. Help me reach visually interesting results efficiently without sacrificing understanding or creating unnecessary infrastructure.

## 1. Artistic direction

My target aesthetic is stylized, atmospheric, low-poly, eerie, and expressive.

Visual inspiration includes the mood and environmental storytelling of Little Nightmares and INSIDE, combined with supernatural effects inspired by Mongolian shamanic fantasy.

Do not imitate any game's specific assets or effects.

Prefer:

- Strong silhouettes and readable shapes.
- Restrained color palettes.
- Unusual, organic, imperfect motion.
- Subtle glow rather than excessive bloom.
- Layered effects with carefully timed anticipation, impact, and decay.
- A mixture of particles, shader effects, procedural geometry, and authored Blender assets.
- Effects that communicate mystery, danger, spiritual energy, and physical presence.

Avoid:

- Generic neon sci-fi effects.
- Excessive particles and bloom.
- Hyperrealistic or overly polished fantasy aesthetics.
- Effects that look good only in a static screenshot.
- Complicated simulations when a simpler technique would achieve the same result.

The goal is not to make the most technically complicated effect. The goal is to make the effect feel intentional and memorable.

## 2. Technology and workflow

Primary engine: Godot 4.x. Detect the installed/project version before implementing anything and use APIs compatible with it.

Primary scripting language: GDScript. Use C# only if there is a clear technical reason.

3D tool: Blender.

Preferred asset workflow:

- Blender for authored meshes, silhouettes, textures, and selected animations.
- Godot for runtime particles, shaders, procedural geometry, effect timing, and composition.
- glTF/GLB or Godot's supported Blender import workflow for asset exchange.
- Procedural generation for reusable shapes and variation.
- AI tools for optional concept images, texture ideas, and prototype meshes.

Do not require paid services, cloud APIs, external AI models, or third-party plugins for the initial experiments.

Prefer built-in Godot features. Before using an unfamiliar API, verify it against the installed Godot version or official documentation.

## 3. Core project goal

Build a VFX laboratory in which I can rapidly create, inspect, compare, modify, and replay supernatural effects.

I want to experiment with:

1. GPUParticles3D and particle behavior.
2. Curves, gradients, and parameter-driven animation.
3. Shader-based effects and animated noise.
4. Emission, dissolve, fresnel, and distortion-like effects.
5. Procedural rings, ribbons, shards, and other geometry.
6. Layered effects with independent timing.
7. Spirit trails, wisps, floating objects, and magical pulses.
8. Effects attached to character bones or other scene nodes.
9. Reusable effect scenes controlled by gameplay parameters.
10. Performance and visual-debugging tools.

Keep the architecture small and extensible. Do not implement all ten areas immediately.

## 4. First hero experiment

The first major artistic target is a supernatural Mongolian shaman drum strike.

Concept:
A shaman strikes a hand drum. The strike releases a restrained but powerful spiritual pulse. Nearby dust and spirit particles react, a stylized energy ring expands outward, and a faint residue lingers before fading away.

The effect should feel ancient, mysterious, and physical rather than like a generic explosion.

Build it incrementally:

Phase A: A basic expanding ring using a mesh or another simple geometric technique.

Phase B: A short, timed burst of particles.

Phase C: A shader-driven pulse or rune-like pattern.

Phase D: Secondary particles or debris that respond to the pulse.

Phase E: A lingering effect that fades away naturally.

Phase F: Adjustable parameters and visual variations.

Do not attempt all phases in the first implementation. Begin with a single working ring and a way to trigger it repeatedly.

The first version must work without a character model, custom textures, external assets, or paid tools.

## 5. Experimental playground requirements

Create a simple test environment containing:

- A neutral floor and dark, readable background.
- A camera with a useful viewing angle.
- A central test point or simple test object.
- A way to trigger and replay the current effect.
- A way to reset the experiment.
- A debug mode that helps inspect particle direction, effect origin, scale, and timing where practical.

Keep the environment visually simple so the effects remain the focus.

As the project grows, add an experiment selector and an adjustable parameter panel. Do not build an elaborate editor or complex UI before the first effect works.

When possible, provide A/B comparisons for parameters such as speed, lifetime, scale, color, and intensity.

## 6. Proposed project organization

Use a structure similar to this, adapting it only when there is a practical reason:

- README.md
- project.godot
- docs/
  - ROADMAP.md
  - CONCEPTS.md
  - EXPERIMENT_LOG.md
  - ART_DIRECTION.md
- experiments/
  - 01_particle_basics/
  - 02_shader_basics/
  - 03_spirit_wisps/
  - 04_energy_ring/
  - 05_drum_strike/
- shared/
  - shaders/
  - materials/
  - procedural/
  - effect_components/
- assets/
  - blender/
  - textures/
  - meshes/

Prefer isolated scenes and scripts for experiments. Shared components should be extracted only after their reuse is demonstrated.

Do not create empty folders and placeholder systems without a concrete purpose.

## 7. Implementation principles

- Implement the smallest working experiment first.
- Explain the approach before making substantial architectural changes.
- Keep code modular, readable, and compatible with the detected Godot version.
- Use exported parameters where they help experimentation.
- Use deterministic random seeds when comparing procedural variations.
- Separate effect timing and parameters from individual visual components.
- Avoid unnecessary dependencies and premature optimization.
- Avoid overengineering a generic VFX framework.
- Do not generate large amounts of code that are not yet needed.
- Do not assume that procedural or AI-generated results are automatically artistically good.
- Include a clear way to trigger, replay, and observe each experiment.
- Validate changes by running the project when the environment supports it. If automated validation is unavailable, explain exactly what remains to be checked manually.
- Keep documentation short, practical, and tied to the experiments.

For every experiment, document:

1. What it demonstrates.
2. The visual principle being tested.
3. The important parameters.
4. How to run and modify it.
5. What to observe.
6. What to try next.

## 8. Roadmap

Follow these stages in order, but adjust them based on what the experiments teach us.

Stage 1: Project setup, test environment, trigger/replay controls.

Stage 2: Particle fundamentals, curves, gradients, and motion.

Stage 3: Shader fundamentals, noise, dissolve, emissive patterns, and fresnel.

Stage 4: Procedural shapes, rings, ribbons, and trails.

Stage 5: Layered supernatural effects and effect timing.

Stage 6: Blender-authored assets integrated into Godot.

Stage 7: Reusable effect scenes and parameter-driven variation.

Stage 8: Character attachment points and gameplay-event integration.

Stage 9: Performance profiling and visual polish.

Stage 10: Advanced experiments such as procedural rune drawing, spirit entities, animated distortion, and environment-reactive effects.

Do not jump ahead simply because a later technique sounds more impressive.

## 9. First task — do this now

First inspect the current repository, available Godot version, existing assets, and project structure.

Then:

1. Summarize the current environment and any constraints.
2. Propose a minimal implementation plan for Stage 1.
3. Create or adapt the project structure without damaging existing files.
4. Implement the smallest working sandbox with a camera, simple floor, triggerable expanding energy ring, and reset/replay controls.
5. Make the ring visually readable using a simple material or shader if appropriate.
6. Expose a few useful parameters, such as expansion speed, lifetime, and thickness.
7. Add a short README explaining how to run the project and experiment with those parameters.
8. Test the project where possible and fix obvious errors.

Stop after Stage 1. Report the files created or changed, how to run the experiment, the important parameters, any validation results, and the recommended next experiment.

Do not implement every roadmap stage now. Do not add a character controller, combat system, motion matching, external AI integration, or a large plugin architecture.

The result should be a small, working, visually testable foundation that we can improve together.

## 10. Collaboration style

Treat this as an iterative R&D partnership.

Be proactive about technical implementation, but do not make major artistic decisions without explaining the trade-offs.

When a visual result is weak, identify whether the problem comes from shape, timing, color, motion, composition, or rendering rather than automatically adding more particles.

Help me develop both a reusable technical toolkit and the artistic judgment needed to create distinctive supernatural VFX.

Start by inspecting the project and proposing Stage 1. Then implement it.
